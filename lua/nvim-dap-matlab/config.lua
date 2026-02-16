local M = {}


-- default configuration
---@class dap_matlab.config
local default_config = {
	lsp_name = 'matlab-ls',
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
