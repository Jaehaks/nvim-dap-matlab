local M = {}

local config = require("nvim-dap-matlab.config").get_opts()
local fidget_ok, fidget_progress = pcall(require, 'fidget.progress')
local fidget_handle = nil

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
-- lsp client handler
--------------------------------------------------------------------------------

-- lsp connection progress check handler : use FileType if you want to lazy load
M.lsp_connection_check_handler = function (err, result, ctx)
	if not result then return end

	local lsp_status = string.lower(result.connectionStatus)
	local adapter = require('nvim-dap-matlab.adapter')
	local adapter_state = adapter.get_state()
	if not adapter_state.lsp_client then
		adapter_state.lsp_client = M.get_lsp_client(config.lsp_name)
		adapter.set_state('lsp_client', adapter_state.lsp_client)
	end
	local lsp_name = adapter_state.lsp_client.name

	if lsp_status == "connecting" then
		if not fidget_ok then
			vim.notify("[matlab-dap] " .. lsp_name .. " is connecting...", vim.log.levels.WARN)
			return
		end

		if not fidget_handle then
			fidget_handle = fidget_progress.handle.create({
				title = "[matlab-dap]",
				message = "loading...",
				lsp_client = { name = adapter_state.lsp_client.name },
			})
		else
			fidget_handle:report({ message = "connecting..." })
		end
		adapter.set_state('lsp_ready', false)

	elseif lsp_status == "connected" then
		if not fidget_ok then
			vim.notify("[matlab-dap] " .. lsp_name .. " is connected!", vim.log.levels.INFO)
			return
		end

		if fidget_handle then
			fidget_handle:report({ message = "connected!" })
			fidget_handle:finish()
			fidget_handle = nil
		end
		adapter.set_state('lsp_ready', true)

	elseif lsp_status == "disconnected" then
		if not fidget_ok then
			vim.notify("[matlab-dap] " .. lsp_name .. " is disconnected!", vim.log.levels.ERROR)
			return
		end

		if fidget_handle then
			fidget_handle:report({ message = "disconnected" })
			fidget_handle:cancel()
			fidget_handle = nil
		end
		adapter.set_state('lsp_ready', false)
	end
end


return M
