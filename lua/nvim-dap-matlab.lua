local M = {}

M.setup = function(opts)
	require("nvim-dap-matlab.config").set_opts(opts)
end



-- // Proxy pattern
return setmetatable(M, {
	__index = function(_, k)
		return require('nvim-dap-matlab.command')[k]
	end
})
