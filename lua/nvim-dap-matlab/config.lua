local M = {}

-- gui windows
---@class dap_matlab.config.gui_windows
---@field auto_open dap_matlab.config.gui_windows.auto_open
---@field keymaps dap_matlab.config.gui_windows.keymaps

---@class dap_matlab.config.gui_windows.auto_open
---@field workspace boolean open workspace window automatically
---@field filebrowser boolean open file browser window automatically

---@class dap_matlab.config.gui_windows.keymaps
---@field toggle_workspace string keymap to toggle workspace gui window
---@field toggle_filebrowser string keymap to toggle file browser gui window

-- repl
---@class dap_matlab.config.repl
---@field filetype string[]
---@field keymaps dap_matlab.config.repl.keymaps

---@class dap_matlab.config.repl.keymaps
---@field previous_command_in_repl string keymap to insert previous command history
---@field next_command_in_repl string keymap to insert next command history


-- default configuration
---@class dap_matlab.config
---@field lsp_name string matlab lsp name which user configured
---@field gui_windows dap_matlab.config.gui_windows
---@field repl dap_matlab.config.repl
local default_config = {
	lsp_name = 'matlab-ls',
	gui_windows = {
		auto_open = {
			workspace = false,
			filebrowser = false,
		},
		keymaps = {
			toggle_workspace = '<leader>dw',
			toggle_filebrowser = '<leader>df',
		},
	},
	repl = {
		filetype = {'dap-repl', 'dap-view'},
		keymaps = {
			previous_command_in_repl = '<C-k>',
			next_command_in_repl = '<C-j>',
		},
	}
}

local config = vim.deepcopy(default_config)

-- get configuration
M.get_opts = function ()
	return config
end

-- set configuration
M.set_opts = function (opts)
	config = vim.tbl_deep_extend('force', default_config, opts or {})
end


return M
