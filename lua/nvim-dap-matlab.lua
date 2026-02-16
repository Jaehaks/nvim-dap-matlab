local M = {}
local adapter = require('nvim-dap-matlab.adapter')

--- setup function
---@param opts dap_matlab.config
M.setup = function(opts)
	-- set config
	require("nvim-dap-matlab.config").set_opts(opts)

	-- set nvim-dap config for matlab
	local ok, dap = pcall(require, "dap")
	if ok then
		M.set_dap(dap, opts)
	end
end

--- setup nvim-dap config
---@param dap table
---@param opts dap_matlab.config
M.set_dap = function (dap, opts)
	-- configure matlab dap when starting debugging session.
	dap.adapters.matlab = function (cb, config)
		local client = adapter.get_lsp_client(opts)
		if not client then
			vim.notify('[matlab-dap] matlab lsp cannt be detected', vim.log.levels.ERROR)
			return
		end

		vim.print(client.name)
	end

	if not dap.configurations.matlab or #dap.configurations.matlab == 0 then
		dap.configurations.matlab = {
			{
				type = "matlab",
				request = "launch",
				name = "MATLAB Debug",
			},
		}
	end
end


-- // Proxy pattern
return setmetatable(M, {
	__index = function(_, k)
		return require('nvim-dap-matlab.command')[k]
	end
})
