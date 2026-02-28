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

return M
