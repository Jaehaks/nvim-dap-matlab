local M = {}

---@class dap_matlab.config.auto_open
---@field workspace boolean
---@field filebrowser boolean
---
---@class dap_matlab.config.keymaps
---@field toggle_workspace string
---@field toggle_filebrowser string


-- default configuration
---@class dap_matlab.config
---@field lsp_name string matlab lsp name which user configured
---@field auto_open dap_matlab.config.auto_open window open automatically
---@field keymaps dap_matlab.config.keymaps
local default_config = {
	lsp_name = 'matlab-ls',
	auto_open = {
		workspace = false,
		filebrowser = false,
	},
	keymaps = {
		toggle_workspace = '<leader>dw',
		toggle_filebrowser = '<leader>df',
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
