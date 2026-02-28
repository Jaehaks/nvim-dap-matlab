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
	if opts.keymaps.toggle_workspace then
		vim.keymap.set('n', opts.keymaps.toggle_workspace, function () toggle_workspace(dap) end,
		{desc = '[matlab-dap] Toggle workspace window'})
	end
	if opts.keymaps.toggle_filebrowser then
		vim.keymap.set('n', opts.keymaps.toggle_filebrowser, function () toggle_filebrowser(dap) end,
		{desc = '[matlab-dap] Toggle file browser window'})
	end
end

--- delete keymaps for matlab debugging
---@param opts dap_matlab.config
M.del_keymaps = function(opts)
	if opts.keymaps.toggle_workspace then
		pcall(vim.keymap.del, 'n', opts.keymaps.toggle_workspace)
	end
	if opts.keymaps.toggle_filebrowser then
		pcall(vim.keymap.del, 'n', opts.keymaps.toggle_filebrowser)
	end
end

return M
