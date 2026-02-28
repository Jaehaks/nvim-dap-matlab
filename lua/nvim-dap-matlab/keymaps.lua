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
	pcall(vim.api.nvim_clear_autocmds, {group = 'matlab-dap-gui-windows' })
end

return M
