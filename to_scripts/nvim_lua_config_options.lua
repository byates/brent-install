-- Options are automatically loaded before lazy.nvim startup
-- Default options that are always set: https://github.com/LazyVim/LazyVim/blob/main/lua/lazyvim/config/options.lua
-- Add any additional options here

-- Route yanks to the system clipboard. This is a remote SSH box inside tmux
-- (no X11/Wayland display, no xclip/xsel), viewed from iTerm2. nvim's native
-- OSC 52 provider does not get forwarded to the terminal here, but tmux's own
-- clipboard forwarding (`load-buffer -w`, requires `set-clipboard on`) does --
-- verified end to end -- so route nvim's clipboard through tmux. `save-buffer`
-- returns the tmux buffer for paste (`p`); use iTerm2's Cmd+V to paste text
-- that originated outside nvim.
vim.g.clipboard = {
  name = "tmux",
  copy = {
    ["+"] = { "tmux", "load-buffer", "-w", "-" },
    ["*"] = { "tmux", "load-buffer", "-w", "-" },
  },
  paste = {
    ["+"] = { "tmux", "save-buffer", "-" },
    ["*"] = { "tmux", "save-buffer", "-" },
  },
  cache_enabled = 0,
}

-- LazyVim forces clipboard="" when SSH_CONNECTION is set (lazyvim/config/
-- options.lua) and its options load synchronously *after* this file, so
-- re-assert unnamedplus on a scheduled callback that runs once startup
-- settles.
vim.schedule(function()
  vim.opt.clipboard = "unnamedplus"
end)

-- Bulletproof copy: mirror every yank to the system clipboard via tmux, the
-- only path that forwards to iTerm2 on this remote box (verified end to end).
-- This runs on the TextYankPost event regardless of the 'clipboard' option or
-- provider, so LazyVim's SSH guard (clipboard="") cannot defeat it.
vim.api.nvim_create_autocmd("TextYankPost", {
  group = vim.api.nvim_create_augroup("tmux_clipboard_yank", { clear = true }),
  callback = function()
    if vim.v.event.operator == "y" then
      vim.fn.system(
        { "tmux", "load-buffer", "-w", "-" },
        table.concat(vim.v.event.regcontents, "\n")
      )
    end
  end,
})
vim.opt.background = "dark"
vim.opt.autoread = true
