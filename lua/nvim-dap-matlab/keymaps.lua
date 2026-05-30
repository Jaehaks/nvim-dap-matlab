local M = {}

--- toggle workspace window
local function toggle_workspace()
	local cmd = [[
	if com.mathworks.mde.desk.MLDesktop.getInstance().isClientShowing('Workspace')
		com.mathworks.mde.desk.MLDesktop.getInstance().hideClient('Workspace');
	else
		workspace;
	end
	]]
	require('nvim-dap-matlab.adapter').send_to_lsp_direct(cmd)
end

--- toggle filebrowser window
local function toggle_filebrowser()
	local cmd = [[
	if com.mathworks.mde.desk.MLDesktop.getInstance().isClientShowing('Current Directory')
		com.mathworks.mde.desk.MLDesktop.getInstance().hideClient('Current Directory');
	else
		filebrowser;
	end
	]]
	require('nvim-dap-matlab.adapter').send_to_lsp_direct(cmd)
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

--- setup keymaps for normal state (regardless of debug state)
M.set_keymaps_normal = function (opts)

	local function _set_keymaps_normal(bufnr)
		if opts.gui_windows.keymaps.toggle_workspace then
			vim.keymap.set('n', opts.gui_windows.keymaps.toggle_workspace, toggle_workspace,
			{desc = '[matlab-dap] Toggle workspace window', buf = bufnr})
		end
		if opts.gui_windows.keymaps.toggle_filebrowser then
			vim.keymap.set('n', opts.gui_windows.keymaps.toggle_filebrowser, toggle_filebrowser,
			{desc = '[matlab-dap] Toggle file browser window', buf = bufnr})
		end
	end

	-- set keymaps for new opening matlab buffer
	vim.api.nvim_create_augroup('matlab-dap-gui-windows', {clear = true})
	vim.api.nvim_create_autocmd('FileType', {
		group = 'matlab-dap-gui-windows',
		pattern = 'matlab',
		callback = function (args)
			_set_keymaps_normal(args.buf)
		end
	})

	-- set keymaps for all opened buffer
	for _, bufnr in ipairs(vim.api.nvim_list_bufs()) do
		if vim.api.nvim_buf_is_valid(bufnr) then
			if vim.bo[bufnr].filetype == 'matlab' then -- for matlab buffer
				_set_keymaps_normal(bufnr)
			end
		end
	end
end

--- setup keymaps for matlab debugging
---@param dap table
---@param opts dap_matlab.config
M.set_syntax_to_repl = function(dap, opts)

	--- apply lsp feature / syntax / keymap for repl
	---@param bufnr number repl buffer number
	local function _set_syntax_to_repl(bufnr)
		local session = dap.session()
		local adapter_state = require('nvim-dap-matlab.adapter').get_state()

		-- only during matlab debug session
		if session and session.config.type == 'matlab' then
			repl_state.syntax = vim.bo[bufnr].syntax -- save default syntax

			-- attach matlab lsp to repl to use completion
			vim.lsp.buf_attach_client(bufnr, adapter_state.lsp_client.id)
			vim.bo[bufnr].syntax = 'matlab'
			vim.diagnostic.enable(false, {bufnr = bufnr}) -- disable diagnostics

			repl_state.bufnr = bufnr
			repl_state.lsp_client = adapter_state.lsp_client
			repl_state.augroup = 'matlab-dap-repl'
		end
	end

	-- autocmd for repl
	vim.api.nvim_create_augroup('matlab-dap-repl', {clear = true})
	vim.api.nvim_create_autocmd('FileType', {
		group = 'matlab-dap-repl',
		pattern = opts.repl.filetype,
		callback = function (args)
			_set_syntax_to_repl(args.buf)
		end
	})

	-- set keymaps for all opened buffer
	for _, bufnr in ipairs(vim.api.nvim_list_bufs()) do
		if vim.api.nvim_buf_is_valid(bufnr) then
			if vim.tbl_contains(opts.repl.filetype, vim.bo[bufnr].filetype) then -- for repl
				_set_syntax_to_repl(bufnr)
			end
		end
	end
end

--- delete keymaps for matlab debugging
M.del_syntax_to_repl = function()

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

		-- 3) restore autocmds
		pcall(vim.api.nvim_clear_autocmds, {group = repl_state.augroup})
		repl_state.bufnr = nil
		repl_state.augroup = nil
	end
end

return M
