-- Keymaps are automatically loaded on the VeryLazy event
-- Default keymaps that are always set: https://github.com/LazyVim/LazyVim/blob/main/lua/lazyvim/config/keymaps.lua
-- Add any additional keymaps here

vim.keymap.set("n", "<C-g>", function()
  local path = vim.fn.expand("%:p")
  vim.fn.setreg("+", path)
  vim.cmd("file") -- shows the file info in status line
  print("Copied: " .. path)
end, { desc = "Show file info and copy path to clipboard" })
