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
			return
		end

		if not fidget_handle then
			fidget_handle = fidget_progress.handle.create({
				title = "[matlab-dap]",
				message = "loading...",
				lsp_client = { name = lsp_name },
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

		-- autocmd for repl
		vim.api.nvim_create_autocmd('FileType', {
			pattern = config.repl.filetype,
			callback = function (args)
				-- attach matlab lsp to repl to use completion
				vim.lsp.buf_attach_client(args.buf, adapter_state.lsp_client.id)
				vim.bo[args.buf].syntax = 'matlab'
				vim.diagnostic.enable(false, {bufnr = args.buf}) -- disable diagnostics

				-- keymaps for repl
				if config.repl.keymaps.previous_command_in_repl then
					vim.keymap.set('i', config.repl.keymaps.previous_command_in_repl, '<Up>', { buffer = args.buf, remap = true})
				end
				if config.repl.keymaps.next_command_in_repl then
					vim.keymap.set('i', config.repl.keymaps.next_command_in_repl, '<Down>', { buffer = args.buf, remap = true})
				end
			end
		})

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

--------------------------------------------------------------------------------
-- other progress bar
--------------------------------------------------------------------------------

--- start fidget progress
---@param msg string message to show while fidget spinning
M.start_fidget = function(msg)
    if fidget_dap_progress then return end

	local adapter_state = require('nvim-dap-matlab.adapter').get_state()
    if fidget_ok then
        fidget_dap_progress = fidget_progress.handle.create({
            title = "[matlab-dap]",
            message = msg,
            lsp_client = { name = adapter_state.lsp_client.name},
        })
    end
end

--- stop fidget progress
M.stop_fidget = function()
    if fidget_dap_progress then
        fidget_dap_progress:finish()
        fidget_dap_progress = nil
    end
end

return M
