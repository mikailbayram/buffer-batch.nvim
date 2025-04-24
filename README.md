# buffer-batch.nvim

**Batch copy, paste, and manage buffers and folders in Neovim.**

A Neovim plugin to collect buffers, paste them together, copy their contents to the clipboard, and even copy the contents of all files in a folder—perfect for code review, sharing, or documentation workflows.


## ✨ Features

- **Batch add buffers** and paste them anywhere
- **Copy buffer contents** to clipboard (with file headers)
- **Copy all files in a folder** to a buffer or clipboard (with file headers)
- **Neo-tree integration** for folder actions
- **User-friendly commands and keymaps**
- **No external dependencies**

## 🚀 Installation

**With [lazy.nvim](https://github.com/folke/lazy.nvim):**

```lua
{
  "mikailbayram/buffer-batch.nvim",
  config = function()
    require("buffer_batch").setup()
  end,
}
```

# Usage

## Buffer Batch Commands

| Command         | Description                       |
|-----------------|-----------------------------------|
| `:BufferBatchAdd` | Add current buffer to batch       |
| `:BufferBatchPaste`| Paste all stored buffers into current buffer |
| `:BufferBatchClear`| Clear the batch                   |
| `:BufferBatchCopy` | Copy all stored buffers to clipboard |

## Folder Actions

| Command                      | Description                                         |
|------------------------------|-----------------------------------------------------|
| `:CopyFolderToBuffer [dir]` | Copy all files in folder to a new buffer (default: cwd) |
| `:CopyFolderToClipboard [dir]`| Copy all files in folder to clipboard (default: cwd) |

# Default Keymaps

| Keymap     | Action             |
|------------|--------------------|
| `<leader>ba` | Add buffer to batch|
| `<leader>bp` | Paste all batched buffers|
| `<leader>bc` | Clear buffer batch |
| `<leader>by` | Copy batch to clipboard|

You can override these in your own config if you wish.

# 📁 Neo-tree Integration

Add these commands to your Neo-tree config for seamless folder actions:

```lua
filesystem = {
  commands = {
    copy_folder_to_buffer = function(state)
      local node = state.tree:get_node()
      if node and node.type == "directory" then
        vim.cmd("CopyFolderToBuffer " .. vim.fn.fnameescape(node.path))
      else
        vim.notify("NeoTree: Please select a directory node first.", vim.log.levels.WARN)
      end
    end,
    copy_folder_to_clipboard = function(state)
      local node = state.tree:get_node()
      if node and node.type == "directory" then
        vim.cmd("CopyFolderToClipboard " .. vim.fn.fnameescape(node.path))
      else
        vim.notify("NeoTree: Please select a directory node first.", vim.log.levels.WARN)
      end
    end,
  },
  window = {
    mappings = {
      ["<leader>cb"] = "copy_folder_to_buffer",
      ["<leader>cc"] = "copy_folder_to_clipboard",
    },
  },
}
```

## Example Workflow

1. Open files you want to batch.
2. Use `<leader>ba` or `:BufferBatchAdd` in each buffer to add them.
3. In your target buffer, use `<leader>bp` or `:BufferBatchPaste` to paste all.
4. Use `<leader>by` or `:BufferBatchCopy` to copy all batched buffers to your clipboard.
5. Use `:CopyFolderToBuffer` or `:CopyFolderToClipboard` to batch all files in a folder.

## Screenshots

Add GIFs or screenshots here to show off your workflow!

## License

MIT

## Contributing

Pull requests and issues are welcome! If you have ideas or find bugs, please open an issue or PR.


