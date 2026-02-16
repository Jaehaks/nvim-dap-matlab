local M = {}
local config = require("nvim-dap-matlab.config").get_opts()

--------------------------------------------------------------------------------
-- lsp client management
--------------------------------------------------------------------------------

--- Finding the MATLAB LSP Client
---@return vim.lsp.Client? object of lsp client
M.get_lsp_client = function(opts)
	local buf_clients = vim.lsp.get_clients({bufnr = 0}) -- get all clients which is attached to current buffer

	-- check matlab lsp is existed
	for _, client in ipairs(buf_clients) do
		local name = client.name or ""
		if name == config.lsp_name then
			return client
		end
	end

	return nil
end

return M
