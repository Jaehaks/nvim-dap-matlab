local M = {}

--- toggle workspace window
---@param dap table
local function toggle_workspace(dap)
	local session = dap.session()
	if session then
		local cmd = [[
		d = com.mathworks.mde.desk.MLDesktop.getInstance();
		if d.isClientShowing('Workspace')
			d.hideClient('Workspace');
		else
			workspace;
		end
		]]
		session:evaluate(cmd)
	end
end

--- toggle workspace window
---@param dap table
local function toggle_filebrowser(dap)
	local session = dap.session()
	if session then
		local cmd = [[
		d = com.mathworks.mde.desk.MLDesktop.getInstance();
		if d.isClientShowing('Current Directory')
			d.hideClient('Current Directory');
		else
			filebrowser;
		end
		]]
		session:evaluate(cmd)
	end
end

---@class dap_matlab.repl_state To restore original properties of repl window
---@field bufnr number? repl buffer's id
---@field lsp_client vim.lsp.Client? lsp client which is attached to repl
---@field augroup string? autocmd group related with repl
---@field syntax string original syntax of repl to restore
local repl_state = {
	bufnr = nil,
	lsp_client = nil,
	augroup = nil,
	syntax = '',
}

--- setup keymaps for matlab debugging
---@param dap table
---@param opts dap_matlab.config
M.set_keymaps = function(dap, opts)

	-- set keymaps as low level function
	---@param bufnr number
	local function _set_keymaps(bufnr)
		if opts.gui_windows.keymaps.toggle_workspace then
			vim.keymap.set('n', opts.gui_windows.keymaps.toggle_workspace, function () toggle_workspace(dap) end,
			{desc = '[matlab-dap] Toggle workspace window', buffer = bufnr, silent = true})
		end
		if opts.gui_windows.keymaps.toggle_filebrowser then
			vim.keymap.set('n', opts.gui_windows.keymaps.toggle_filebrowser, function () toggle_filebrowser(dap) end,
			{desc = '[matlab-dap] Toggle file browser window', buffer = bufnr, silent = true})
		end
	end

	-- set keymaps for all opened matlab buffer
	for _, bufnr in ipairs(vim.api.nvim_list_bufs()) do
		if vim.api.nvim_buf_is_valid(bufnr) and vim.bo[bufnr].filetype == 'matlab' then
			_set_keymaps(bufnr)
		end
	end

	-- set keymaps for new opening matlab buffer
	vim.api.nvim_create_augroup('matlab-dap-gui-windows', {clear = true})
	vim.api.nvim_create_autocmd('FileType', {
		group = 'matlab-dap-gui-windows',
		pattern = 'matlab',
		callback = function (args)
			_set_keymaps(args.buf)
		end
	})

	-- autocmd for repl
	vim.api.nvim_create_augroup('matlab-dap-repl', {clear = true})
	vim.api.nvim_create_autocmd('FileType', {
		group = 'matlab-dap-repl',
		pattern = opts.repl.filetype,
		callback = function (args)
			local session = dap.session()
			local adapter_state = require('nvim-dap-matlab.adapter').get_state()

			-- only during matlab debug session
			if session and session.config.type == 'matlab' then
				repl_state.syntax = vim.bo[args.buf].syntax -- save default syntax

				-- attach matlab lsp to repl to use completion
				vim.lsp.buf_attach_client(args.buf, adapter_state.lsp_client.id)
				vim.bo[args.buf].syntax = 'matlab'
				vim.diagnostic.enable(false, {bufnr = args.buf}) -- disable diagnostics

				repl_state.bufnr = args.buf
				repl_state.lsp_client = adapter_state.lsp_client
				repl_state.augroup = 'matlab-dap-repl'

				-- keymaps for repl
				if opts.repl.keymaps.previous_command_history then
					vim.keymap.set('i', opts.repl.keymaps.previous_command_history, '<Up>',
					{ desc = '[matlab-dap] previous commnad history in repl', buffer = args.buf, remap = true})
				end
				if opts.repl.keymaps.next_command_history then
					vim.keymap.set('i', opts.repl.keymaps.next_command_history, '<Down>',
					{ desc = '[matlab-dap] next commnad history in repl', buffer = args.buf, remap = true})
				end
			end
		end
	})
end

--- delete keymaps for matlab debugging
---@param opts dap_matlab.config
M.del_keymaps = function(opts)

	-- delete keymaps as low level function
	---@param bufnr number
	local function _del_keymaps(bufnr)
		local gm = opts.gui_windows.keymaps
		if gm.toggle_workspace then
			pcall(vim.keymap.del, 'n', gm.toggle_workspace, {buffer = bufnr})
		end
		if gm.toggle_filebrowser then
			pcall(vim.keymap.del, 'n', gm.toggle_filebrowser, {buffer = bufnr})
		end
	end

	-- delete keymaps for all opened matlab buffer
	for _, bufnr in ipairs(vim.api.nvim_list_bufs()) do
		if vim.api.nvim_buf_is_valid(bufnr) and vim.bo[bufnr].filetype == 'matlab' then
			_del_keymaps(bufnr)
		end
	end
	pcall(vim.api.nvim_clear_autocmds, {group = 'matlab-dap-gui-windows'})

	-- restore properties of repl
	if repl_state.bufnr then
		-- 1) restore syntax
		vim.bo[repl_state.bufnr].syntax = repl_state.syntax
		if repl_state.lsp_client then
			pcall(vim.lsp.buf_detach_client, repl_state.bufnr, repl_state.lsp_client.id)
			repl_state.lsp_client = nil
		end

		-- 2) restore diagnostic
		vim.diagnostic.enable(true, {bufnr = repl_state.bufnr})

		-- 3) restore keymaps
		local rm = opts.repl.keymaps
		if rm.previous_command_history then
			pcall(vim.keymap.del, 'n', rm.previous_command_history, {buffer = repl_state.bufnr})
		end
		if rm.next_command_history then
			pcall(vim.keymap.del, 'n', rm.next_command_history, {buffer = repl_state.bufnr})
		end

		-- 4) restore autocmds
		pcall(vim.api.nvim_clear_autocmds, {group = repl_state.augroup})
		repl_state.bufnr = nil
		repl_state.augroup = nil
	end
end

return M
