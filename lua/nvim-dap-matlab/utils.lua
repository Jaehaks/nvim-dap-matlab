local M = {}

local config = require("nvim-dap-matlab.config").get_opts()
local fidget_ok, fidget_progress = pcall(require, 'fidget.progress')
local fidget_handle = nil
local fidget_dap_progress = nil

--------------------------------------------------------------------------------
-- lsp client management
--------------------------------------------------------------------------------

--- get lsp client which is matched with lsp_name
---@param lsp_name string matlab lsp name
---@param bufnr number buffer number to get lsp client
---@return vim.lsp.Client? object of lsp client
M.get_lsp_client = function(lsp_name, bufnr)
	local buf_clients = vim.lsp.get_clients({bufnr = bufnr or 0}) -- get all clients which is attached to current buffer

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
-- lsp client handler
--------------------------------------------------------------------------------

-- lsp connection progress check handler : use FileType if you want to lazy load
M.lsp_connection_check_handler = function (err, result, ctx)
	if not result then return end

	local lsp_status = string.lower(result.connectionStatus)
	local adapter = require('nvim-dap-matlab.adapter')
	local adapter_state = adapter.get_state()
	adapter_state.lsp_client = vim.lsp.get_client_by_id(ctx.client_id) -- get client from handler event
	adapter.set_state('lsp_client', adapter_state.lsp_client)
	local lsp_name = adapter_state.lsp_client.name

	if lsp_status == "connecting" then
		if not fidget_ok then
			vim.notify("[matlab-dap] " .. lsp_name .. " is connecting...", vim.log.levels.WARN)
		else
			if not fidget_handle then
				fidget_handle = fidget_progress.handle.create({
					title = "[matlab-dap]",
					message = "loading...",
					lsp_client = { name = lsp_name },
				})
			else
				fidget_handle:report({ message = "connecting..." })
			end
		end

		adapter.set_state('lsp_ready', false)

	elseif lsp_status == "connected" then
		vim.defer_fn(function ()
			if not fidget_ok then
				vim.notify("[matlab-dap] " .. lsp_name .. " is connected!", vim.log.levels.INFO)
			else
				if fidget_handle then
					fidget_handle:report({ message = "connected!" })
					fidget_handle:finish()
					fidget_handle = nil
				end
			end

			adapter.set_state('lsp_ready', true)
		end, 2000)

	elseif lsp_status == "disconnected" then
		if not fidget_ok then
			vim.notify("[matlab-dap] " .. lsp_name .. " is disconnected!", vim.log.levels.ERROR)
		else
			if fidget_handle then
				fidget_handle:report({ message = "disconnected" })
				fidget_handle:cancel()
				fidget_handle = nil
			end
		end

		adapter.set_state('lsp_ready', false)
	end
end

--------------------------------------------------------------------------------
-- other progress bar
--------------------------------------------------------------------------------

local fidget_stopped = false

--- start fidget progress
---@param msg string message to show while fidget spinning
M.start_fidget = function(msg)
	fidget_stopped = false
	local adapter_state = require('nvim-dap-matlab.adapter').get_state()
    if fidget_ok then
		if fidget_dap_progress then return end
        fidget_dap_progress = fidget_progress.handle.create({
            title = "[matlab-dap]",
            message = msg,
            lsp_client = { name = adapter_state.lsp_client.name},
        })
	else
		vim.notify('[matlab-dap] ' .. msg)
    end
end

--- stop fidget progress
M.stop_fidget = function()
	if fidget_stopped then return end
    if fidget_dap_progress then
        fidget_dap_progress.message = '🛑 Stopped'
        fidget_dap_progress:finish()
        fidget_dap_progress = nil
	else
		vim.notify('[matlab-dap] stopped!')
    end
	fidget_stopped = true
end

--- stop fidget progress
M.finish_fidget = function()
    if fidget_dap_progress then
        fidget_dap_progress:finish()
        fidget_dap_progress = nil
    end
end

--- stop fidget progress
M.error_fidget = function()
    if fidget_dap_progress then
        fidget_dap_progress.message = '❌ Error'
        fidget_dap_progress:finish()
        fidget_dap_progress = nil
	else
		vim.notify('[matlab-dap] Script Error!, see REPL', vim.log.levels.WARN)
    end
end

--------------------------------------------------------------------------------
-- sign definition
--------------------------------------------------------------------------------
local sign_names = {
    "DapBreakpoint",
    "DapBreakpointCondition",
    "DapBreakpointRejected",
    "DapLogPoint",
    "DapStopped"
}

-- default sign backup
local default_signs = {}
for _, name in ipairs(sign_names) do
	local defined = vim.fn.sign_getdefined(name)[1]

	if defined then
		default_signs[name] = defined
	else
		default_signs[name] = { text = "", texthl = "", linehl = "", numhl = "" }
	end
end

-- define nvim-dap-matlab sign
vim.api.nvim_set_hl(0, 'DapStoppedLine', {bg = '#4a3f00'})
local matlab_signs = {
	DapBreakpoint          = { text = '●', texthl = 'DiagnosticError',   linehl = '', numhl = '' },
	DapBreakpointCondition = { text = '●', texthl = 'DiagnosticWarn',    linehl = '', numhl = '' },
	DapBreakpointRejected  = { text = '', texthl = 'DiagnosticHint',    linehl = '', numhl = '' },
	DapLogPoint            = { text = '', texthl = 'DiagnosticInfo',    linehl = '', numhl = '' },
	DapStopped             = { text = '▶', texthl = 'DiagnosticOk',      linehl = 'DapStoppedLine', numhl = '' },
}

local function set_debug_signs(signs)
    for name, opts in pairs(signs) do
        vim.fn.sign_define(name, opts)
    end
end

-- 3. 버퍼 이동 시 FileType을 감지하여 덮어씌우거나 복구합니다.
vim.api.nvim_create_augroup('matlab-dap-sign', { clear = true })
vim.api.nvim_create_autocmd('BufEnter', {
    group = 'matlab-dap-sign',
    callback = function(args)
        if not vim.api.nvim_buf_is_valid(args.buf) then return end

        if vim.bo[args.buf].filetype == 'matlab' then
            set_debug_signs(matlab_signs)
        else
            set_debug_signs(default_signs)
        end
    end
})

return M
