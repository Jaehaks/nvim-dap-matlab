# nvim-dap-matlab

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

---

## Requirements

| Dependency                                                                    | Required | Notes                                                              |
| ----------------------------------------------------------------------------- | -------- | ------------------------------------------------------------------ |
| **Neovim**                                                                    | required | 0.10+ recommended (uses `vim.uv`)                                  |
| **MATLAB**                                                                    | required | R2021b+ (Tested at R2024b)                                         |
| [MATLAB Language Server](https://github.com/mathworks/MATLAB-language-server) | required | Running in `--stdio` mode                                          |
| [Jaehaks/nvim-dap](https://github.com/Jaehaks/nvim-dap)                       | required | forked to fix empty breakpoints until it is fixed in original repo |
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

```lua
vim.lsp.config('matlab-ls', {
  root_dir = function (bufnr, cb)
    local root = vim.fs.root(bufnr, {'.git'}) or vim.fn.expand('%:p:h')
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

> [!TIP] Tip:
> Recommend to set `pwd` to project folder.

### 2) nvim-dap


Below code is an example.

> [!TIP] Tip:
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
  lsp_name = 'matlab-ls',              -- lsp name which you set using vim.lsp
  auto_open = {                        -- these windows are opened automatically when debug starts.
    workspace = false,
    filebrowser = false,
  },
  keymaps = {                          -- native keymaps
    toggle_workspace = '<leader>dw',   -- toggle workspace window to see variable list in GUI
    toggle_filebrowser = '<leader>df', -- toggle file browser window to see file list
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
