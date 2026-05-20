# nvim-dap-matlab

## Main Demo
<div align="center">
  <video src="https://github.com/user-attachments/assets/09ef298f-7d1c-497e-ab5f-46bba49040a4" style="width: 30%;" controls>
  </video>
</div>

## Use REPL, Watch / Detect error line
<div align="center">
  <video src="https://github.com/user-attachments/assets/a2cd62b0-ee3c-4392-a239-697ac04ef8f4" width="30%" controls>
  </video>
</div>


## What for?

A **DAP (Debug Adapter Protocol) adapter** between [nvim-dap](https://github.com/mfussenegger/nvim-dap) and the [MATLAB Language Server](https://github.com/mathworks/MATLAB-language-server) for debugging MATLAB code directly in Neovim.

The MATLAB Language Server has built-in debugging capabilities after v1.3.0,
but they are only exposed through proprietary LSP notifications not through a standard DAP server.
This plugin bridges that gap by creating a **local TCP server** that translates between nvim-dap's
standard DAP protocol and the MATLAB LSP's custom notification-based debug interface.

> **✅ Windows supported**

---

## Features

- **Pure Lua** — no external runtimes, no Python scripts, no separate debug server
- Use the same `matlab.exe` instance which is spawned by `matlab lsp` to reduce memory
- To prevent crash, it blocks executing debug session while matlab lsp is loading
- Optional [fidget.nvim](https://github.com/j-hui/fidget.nvim) integration for LSP connection progress display
- Supports some keymaps to manage file browser / workspace window.
- Use nvim-dap's repl to interact with matlab with lsp completion and syntax
- Supports multiple `workspaceFolders` setting

---

## Requirements

| Dependency                                                                    | Required | Notes                                                              |
| ----------------------------------------------------------------------------- | -------- | ------------------------------------------------------------------ |
| **Neovim**                                                                    | required | 0.10+ recommended (uses `vim.uv`)                                  |
| **MATLAB**                                                                    | required | R2021b+ (Tested at R2024b)                                         |
| [MATLAB Language Server](https://github.com/mathworks/MATLAB-language-server) | required | Running in `--stdio` mode                                          |
| [Jaehaks/nvim-dap](https://github.com/Jaehaks/nvim-dap)                       | required | forked to fix empty breakpoints Problem [mfussenegger/nvim-dap/#1592](https://github.com/mfussenegger/nvim-dap/pull/1592) until it s fixed in original repo |
| [fidget.nvim](https://github.com/j-hui/fidget.nvim)                           | optional | Shows beautiful progress                                           |

---

## Installation

### lazy.nvim

```lua
{
  "Jaehaks/nvim-dap-matlab",
  dependencies = {
    "Jaehaks/nvim-dap",
  },
  ft = "matlab",
  opts = {}
}
```

---

## Configuration

### 1) MATLAB LSP

The MATLAB Language Server must be running before you can start a debug session.
If you start a debug session before then, a message will be shown asking you to wait until matlab-ls is loaded.

You can configure `matlab-ls` in one of two modes: \

- **Per-project mode**: each project uses its own independent LSP instance.
- **Shared-instance mode**: a single LSP instance is reused, and the workspace is switched as needed.
							It need to turn on workspaceFolder setting.

> I recommend `Shared-instance mode`.

<details>
	<summary> LSP configuration for Per-project mode </summary>

You need to open one project file for a one neovim instance. It cannot switch debug session between projects.
It would be needed high memory because each matlab-lsp(matlab.exe) is attached per project.


```lua
vim.lsp.config('matlab-ls', {
  root_dir = function (bufnr, cb)
    local bufname = vim.api.nvim_buf_get_name(bufnr)
    if string.match(bufname, 'toolbox[\\/]matlab') then -- avoid attaching to installed matlab library
      return
    end
    local root = vim.fs.root(bufnr, { '.git' }) or vim.fn.expand('%:p:h')
    cb(root)
  end,

  cmd = {'matlab-language-server', '--stdio'},
  filetypes = {'matlab'},
  settings = {
    matlab = {
      indexWorkspace = true,
      installPath = '<matlab path>'
      matlabConnectionTiming = 'onStart',
      telemetry = false, -- don't report about any problem
    },
  },
  single_file_support = false, -- if enabled, lsp(matlab.exe) attaches per file, too heavy
})
```

> [!TIP]
> Recommend to set `pwd` to project folder automatically.

</details>




<details>
	<summary> LSP configuration for reusable setting </summary>

`MATLAB-language-server` supports multiple workspaceFolders. So matlab-ls can manages multiple workspaces using one instance.
To prevent fail to diagnosis from lsp from mixed workspace, you need to replace workspace rather than only adding.
Below configuration can achieve replacing workspaces. You can navigate between projects using only one matlab instance.
When you start debug session, it will use the current workspace.

```lua
-- enable multiple workspace folder
-- workspaceFolder will be executed by background even though the capability is not shown in server_capabilities
local matlab_capabilities = get_lsp_capabilities() -- default capabilities
matlab_capabilities.workspace = matlab_capabilities.workspace or {}
matlab_capabilities.workspace.workspaceFolders = true

local root_dir_matlab = 'path/to/root' -- any path to virtual root
vim.lsp.config('matlab-ls', {
  cmd = {'matlab-language-server', '--stdio'},
  filetypes = {'matlab'},
  root_dir = root_dir_matlab,
  reuse_client = function (client, config) -- reuse lsp for matlab-ls
    return client.name == config.name
  end,
  settings = {
    matlab = {
      indexWorkspace = true,
      installPath = require('jaehak.core.paths').lsp.matlab,
      matlabConnectionTiming = 'onStart',
      telemetry = false,
    },
  },
  single_file_support = false,
  capabilities = matlab_capabilities
})

local get_root_matlab = function (bufnr)
  local root = vim.fs.root(bufnr, { '.git' })
  if not root then
    local filepath = vim.api.nvim_buf_get_name(bufnr)
    if filepath ~= '' then
      root = vim.fn.fnamemodify(filepath, ':p:h') -- get parent directory
    else
      root = root_dir_matlab -- fallback, but rared
    end
  end
  return vim.fs.normalize(root)
end

vim.api.nvim_create_autocmd("BufEnter", {
  pattern = "*.m",
  callback = function(args)
    -- library file doesn't be attached lsp
    if string.find(args.file, 'toolbox[\\/]matlab') then
      return
    end

    -- check matlab-ls is attached and get workspaces
    local clients = vim.lsp.get_clients({ name = "matlab-ls" })
    if #clients == 0 then return end
    local client = clients[1]
    local cur_workspace_folders = client.workspace_folders or {}

    -- get workspace based on current file
    local new_workspace = get_root_matlab(args.buf)
    local new_workspace_uri = vim.uri_from_fname(new_workspace) -- make path to uri form

    -- check workspace is changed
    if not (cur_workspace_folders[1] and cur_workspace_folders[1].uri == new_workspace_uri) then
      -- replace workspace with new one
      local new_workspace_folders = {
        name = new_workspace,
        uri = new_workspace_uri,
      }
      client:notify("workspace/didChangeWorkspaceFolders", {
        event = {
          added = { new_workspace_folders },
          removed = cur_workspace_folders
        }
      })
      client.workspace_folders = { new_workspace_folders }

      -- remove attached buffers which is not in current workspace
      for bufnr, _ in pairs(client.attached_buffers) do
        local bufpath = vim.fs.normalize(vim.api.nvim_buf_get_name(bufnr))
        if bufpath ~= "" and not vim.startswith(bufpath, new_workspace) then
          vim.lsp.buf_detach_client(bufnr, client.id)
        end
      end
    end

    -- attach buffer to lsp client (lsp cannot attach buffer automatically)
    if not client.attached_buffers[args.buf] then
      vim.lsp.buf_attach_client(args.buf, client.id)
    end
  end,
})
```

</details>

### 2) nvim-dap


Below code is an example.

> [!TIP]
> When You set conditional breakpoint, you need to input some condition without `if` word


```lua
{
  'Jaehaks/nvim-dap',
  ft = {'matlab'},
  config = function ()
    local dap = require('dap')

	-- nvim-dap-matlab configure its own dap setting. You don't need to setup in nvim-dap.

	-- set keymaps
	-- You can use all nvim-dap's functions to debug.
  end
}
```


### 3) nvim-dap-matlab

```lua
require("nvim-dap-matlab").setup({
  lsp_name = 'matlab-ls',                 -- lsp name which you set using vim.lsp
  gui_windows = {
    auto_open = {                         -- these windows are opened automatically when debug starts.
      workspace = false,
      filebrowser = false,
    },
    keymaps = {
      toggle_workspace = '<leader>dw',    -- toggle workspace window to see variable list in GUI
      toggle_filebrowser = '<leader>df',  -- toggle file browser window to see variable list in GUI
    },
  },
  repl = {
    filetype = {'dap-repl', 'dap-view'},  -- set filetypes to apply lsp autocompletion and syntax
    keymaps = {
      previous_command_histroy = '<C-k>', -- insert previous command history to repl
      next_command_history = '<C-j>',     -- insert next command history to repl
    },
  }
})
```


---

## Usage

### Quick Start

1. Open a `.m` file in Neovim — the MATLAB LSP will connect automatically.
2. Wait for the LSP to finish loading (`fidget.nvim` or `vim.notify()` will show progress if it is completed).
3. Set breakpoints with `dap.toggle_breakpoint()`.
4. Start debugging with `dap.continue()`.
5. When a breakpoint is hit, use `Step Over` / `Step Into` / `Step Out` / `Continue` as usual.

### Recommended Keymaps

```lua
local dap = require("dap")

vim.keymap.set('n', '<F5>', function ()
  local session = dap.session()
  if session and not session.stopped_thread_id then
    dap.close() -- if debug run is completed but session is remaining
  end
  dap.continue()
end, {desc = '[nvim-dap] Debug Run/continue'})
vim.keymap.set('n', '<F10>', dap.step_over, {desc = '[nvim-dap] Debug Step Over'})
vim.keymap.set('n', '<F11>', dap.step_into, {desc = '[nvim-dap] Debug Step Into'})
vim.keymap.set('n', '<F12>', dap.step_out, {desc = '[nvim-dap] Debug Step Out'})
vim.keymap.set('n', '<leader>dp', dap.pause, {desc = '[nvim-dap] Debug Pause'})
vim.keymap.set('n', '<leader>ds', dap.terminate, {desc = '[nvim-dap] Terminate Session'})
vim.keymap.set('n', '<leader>du', dap.clear_breakpoints, {desc = '[nvim-dap] Clear all Breakpoints'})
vim.keymap.set('n', '<leader>db', dap.toggle_breakpoint, {desc = '[nvim-dap] Set Breakpoint '})
vim.keymap.set('n', '<leader>dB', function ()
  local condition = vim.fn.input('condition : ') -- insert condition without 'if' word.
  if condition and condition ~= '' then
    dap.toggle_breakpoint(condition)
  end
end, {desc = '[nvim-dap] Set conditional Breakpoint '})
```


---

## License

[GPL-3.0](LICENSE)
