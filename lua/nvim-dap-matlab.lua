local M = {}

--- setup nvim-dap config
---@param dap table
---@param opts dap_matlab.config
local function set_dap(dap, opts)
	local adapter = require('nvim-dap-matlab.adapter')
	local keymaps = require('nvim-dap-matlab.keymaps')
	local utils = require('nvim-dap-matlab.utils')

	-- configure matlab dap when starting debugging session.
	dap.adapters.matlab = function (cb, config)
		-- try opening tcp server as adapter between dap and lsp
		local ip, port = adapter.start()
		if not ip then
			return
		end

		-- vim.print(ip .. ':' .. port)
		cb({
			type = "server",
			host = ip,
			port = port
		})
	end

	if not dap.configurations.matlab or #dap.configurations.matlab == 0 then
		dap.configurations.matlab = {
			{
				type = "matlab",            -- it needs to same with dap.adapters.[type]
				request = "launch",         -- 'attach' or 'launch' command
				name = "MATLAB Debug",      -- description of the session
				-- optional
				program = "${file}",        -- file path
				cwd = "${workspaceFolder}", -- workspace directory
			},
		}
	end

	-- launch matlab file manually using 'evaluate' command in after hook instead of `launch`
	-- because matlab_ls doesn't  support launch command.
	dap.listeners.after['launch']['run_matlab'] = function (session, err, _, config, _)
		if err then
			vim.notify("[matlab-dap] hooker after launch is failed: " .. tostring(err), vim.log.levels.ERROR)
			return
		end

		-- Show start message
		local filename = vim.fn.fnamemodify(config.program, ':t')
		vim.notify("[matlab-dap] Run " .. filename)

		-- run current file
		local cmd = string.format("run('%s')", config.program)
		session:evaluate(cmd)

		-- open workspace window at start
		if opts.auto_open.workspace then
			session:evaluate("workspace")
		end

		-- open file browser window at start
		if opts.auto_open.filebrowser then
			session:evaluate("filebrowser")
		end

		-- set keymaps for matlab debugging
		keymaps.set_keymaps(dap, opts)

		utils.start_fidget('continue...')
	end

	dap.listeners.after['event_terminated']["terminate_matlab"] = function ()
		vim.notify("[matlab-dap] Debug session is terminated")
		utils.stop_fidget()
		keymaps.del_keymaps(opts)
	end
	dap.listeners.after['event_exited']["exit_matlab"] = function ()
		vim.notify("[matlab-dap] matlab script is exited")
		utils.stop_fidget()
		keymaps.del_keymaps(opts)
	end

	-- set progress
	dap.listeners.after['continue']['progress'] = function () utils.start_fidget('continue...') end
	dap.listeners.after['event_stopped']['progress'] = function () utils.stop_fidget() end
end

--- setup function
---@param opts dap_matlab.config
M.setup = function(opts)
	local utils = require('nvim-dap-matlab.utils')

	-- set config
	local cf = require("nvim-dap-matlab.config")
	cf.set_opts(opts)

	-- set nvim-dap config for matlab
	local ok, dap = pcall(require, "dap")
	if ok then
		set_dap(dap, cf.get_opts())
	end

	-- check lsp connection progress using handler : use FileType if you want to lazy load
	vim.lsp.handlers["matlab/connection/update/server"] = utils.lsp_connection_check_handler
end

return M
