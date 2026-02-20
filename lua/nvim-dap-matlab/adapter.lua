local M = {}
local config = require("nvim-dap-matlab.config").get_opts()

local uv = vim.uv or vim.loop

---@class dap_matlab.state
---@field server uv.uv_tcp_t?
---@field socket uv.uv_tcp_t?
---@field lsp_client vim.lsp.Client?
---@field tag number
---@field msg string
---@field started boolean
local state = {
	server = nil,
	socket = nil,
	lsp_client = nil,
	tag = 1, -- if we use only one debugging session, use fixed integer
	msg = '',
	started = false,
}

--------------------------------------------------------------------------------
-- lsp client management
--------------------------------------------------------------------------------

--- get lsp client which is matched with lsp_name
---@param lsp_name string matlab lsp name
---@return vim.lsp.Client? object of lsp client
M.get_lsp_client = function(lsp_name)
	local buf_clients = vim.lsp.get_clients({bufnr = 0}) -- get all clients which is attached to current buffer

	-- check matlab lsp is existed
	for _, client in ipairs(buf_clients) do
		local name = client.name or ""
		if name == lsp_name then
			return client
		end
	end

	return nil
end

--------------------------------------------------------------------------------
-- parse and send messages
--------------------------------------------------------------------------------

--- parse dap message and separate these using table depends on frame.
---@return dap.Request[]
local function parse_dap_messages()
	local messages = {}

	-- sometimes, multiple dap messages can be received,
	while true do

		-- find Content-Length header string
		local idx_s, idx_e = state.msg:find("\r\n\r\n", 1, true) -- find start idx and end idx / start from 1 idex / consider the pattern as text
		if not idx_s then break end -- if there is no header, break.

		-- check data length from header
		local header = state.msg:sub(1, idx_s) -- get header string
		local len_est = tonumber(header:match("Content%-Length:%s*(%d+)"))
		if not len_est then break end

		-- check all message contents are received as data length
		-- if not, get more messages
		local len_act = #state.msg - idx_e + 1
		if len_act < len_act then break end

		-- if all messages are received,
		local idx_e_msg = idx_e + len_est
		local body = state.msg:sub(idx_e + 1, idx_e_msg) -- message body without header
		state.msg = state.msg:sub(idx_e_msg + 1) -- flush state.msg

		-- add messages array to send
		local ok, msg = pcall(vim.json.decode, body)
		if ok and msg then
			table.insert(messages, msg)
		end
	end

	return messages
end


--- send dap messages to lsp
---@param dap_message dap.Request
local function send_to_lsp(dap_message)

	-- Packaged in the same format as the VSCode Extension
	-- MatlabDebugAdaptorServer._handleServerRequest expects this format
	local packagedRequest = {
		debugRequest = dap_message,
		tag = state.tag,
	}

	-- use notify() instead of request() if you don't need to receive callback message
	-- lsp doesn't reply immediately, it will send to dap using "DebugAdaptorEvent" event
	state.lsp_client:notify("DebugAdaptorRequest", packagedRequest)
end

--------------------------------------------------------------------------------
-- tcp server handlers from dap to lsp
--------------------------------------------------------------------------------

--- handler when some nvim-dap message is transferred to socket of listener
---@param read_err uv.callback.err
---@param data? string
local function read_handler(read_err, data)
	if read_err then
		vim.schedule(function ()
			vim.notify("[matlab-dap] read error: " .. tostring(read_err), vim.log.levels.ERROR)
		end)
		return
	end

	-- If no data, stop server
	if not data then
		vim.schedule(function() M.stop() end)
		return
	end

	-- If data, add received buffer and send to lsp
	state.msg = state.msg .. data
	vim.schedule(function()
		local messages = parse_dap_messages()
		for _, msg in ipairs(messages) do
			send_to_lsp(msg)
		end
	end)
end

--- handler when some nvim-dap message is received
---@param listen_err uv.callback.err
local function listen_handler(listen_err)
	if listen_err then
		vim.schedule(function ()
			vim.notify("[matlab-dap] tcp server listen error: " .. tostring(listen_err), vim.log.levels.ERROR)
		end)
		return
	end

	-- create socket to manage received message
	local socket = uv.new_tcp()
	if not socket then
		vim.schedule(function ()
			vim.notify("[matlab-dap] tcp socket creation error", vim.log.levels.ERROR)
		end)
		return
	end

	state.server:accept(socket) -- transfer msg to socket
	state.socket = socket
	socket:read_start(read_handler)
end

--- Start adapter tcp server
---@return string? ip of tcp server
---@return integer? port of tcp server
M.start = function ()
	-- stop existing tcp server
	-- how? 1) close and restart 2) use current server
	if state.started then
		M.stop()
	end

	-- check matlab lsp is executed already.
	local lsp_client = M.get_lsp_client(config.lsp_name)
	if not lsp_client then
		vim.notify('[matlab-dap] matlab lsp cannot be detected', vim.log.levels.ERROR)
		return
	end
	state.lsp_client = lsp_client
	M.register_lsp_handlers(lsp_client) -- register lsp handler to get lsp response from dap request

	state.msg = '' -- initialize received message buffer contents

	state.server = uv.new_tcp() 		-- create empty tsp server object
	state.server:bind('127.0.0.1', 0) 	-- allocate address/port.  0 means arbitrary port to avoid conflict

	-- wait listening to receive nvim-dap access
	-- it executes at once after dap access, the authority is transferred to internal socket handler.
	state.server:listen(1, listen_handler) -- backlog = 1 (wait list to connect)

	-- get tcp server's port information
	local serverinfo = state.server:getsockname() -- we use '0' when bind, so we need to check server info explicitly
	if not serverinfo then
		vim.schedule(function ()
			vim.notify("[matlab-dap] Getting tcp serverinfo is failed", vim.log.levels.ERROR)
		end)
		return
	end

	state.started = true
	return serverinfo.ip, serverinfo.port
end

M.stop = function ()
	if state.socket and not state.socket:is_closing() then
		state.socket:read_stop()
		state.socket:close()
	end
	state.server = nil
	state.socket = nil
	state.lsp_client = nil
	state.msg = ""
	state.started = false
end


--------------------------------------------------------------------------------
-- lsp -> dap response receive
--------------------------------------------------------------------------------

--- encode lsp message to dap form. (Adding header)
---@param dap_response dap.Response
local function encode_to_DAPform(dap_response)
	local body = vim.json.encode(dap_response)
	return string.format("Content-Length: %d\r\n\r\n%s", #body, body)
end

--- send lsp response messages to dap
---@param dap_response dap.Response
local function send_to_dap(dap_response)
	if state.socket and not state.socket:is_closing() then
		local encoded = encode_to_DAPform(dap_response)
		state.socket:write(encoded)
	end
end

-- interface PackagedResponse {
--     debugResponse: DebugProtocol.Response
--     tag: unknown
-- }
--- Right after nvim-dap send message to lsp, lsp reply.
--- initialize, launch, next, stepin, scopes etc ...
local function debug_response_handler(err, result, ctx)
	-- check result is valid
	if not result or not result.debugResponse then
		return
	end
	-- check the tag is valid
	if result.tag ~= state.tag then return end

	-- lsp response has not body like 'commandwindow', 'workspace' command in matlab,
	-- add dummy body to avoid 'resp' error of nvim-dap
	if result.debugResponse.command == 'evaluate' and result.debugResponse.success and not result.debugResponse.body then
		result.debugResponse.body = {
			result = ' ',
			variablesReference = 0 -- it is regarded the result as single value
		}
	end

	vim.schedule(function()
		send_to_dap(result.debugResponse)
	end)
end

--- Some event notification from lsp without dap request
--- stopped at breakpoint, continued
local function debug_event_handler(err, result, ctx)
	if not result or not result.debugEvent then
		return
	end

	vim.schedule(function()
		send_to_dap(result.debugEvent)
	end)
end

--- DebuggingStateChange 핸들러: 디버깅 상태 변경 알림
local function debug_statechange_handler(err, result, ctx)
	vim.schedule(function()
		if result then
			vim.api.nvim_exec_autocmds("User", { pattern = "MatlabDebugStart" })
		else
			vim.api.nvim_exec_autocmds("User", { pattern = "MatlabDebugStop" })
		end
	end)
end

--- register LSP notification handler
---@param lsp_client vim.lsp.Client
M.register_lsp_handlers = function(lsp_client)
	lsp_client.handlers["DebugAdaptorResponse"] = debug_response_handler
	lsp_client.handlers["DebugAdaptorEvent"]    = debug_event_handler
	lsp_client.handlers["DebuggingStateChange"] = debug_statechange_handler
end

return M
