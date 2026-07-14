-- Options are automatically loaded before lazy.nvim startup
-- Default options that are always set: https://github.com/LazyVim/LazyVim/blob/main/lua/lazyvim/config/options.lua
-- Add any additional options here

-- Route yanks to the system clipboard. There is no X11/Wayland display and no
-- xclip/xsel here (remote SSH box), so reach the clipboard via terminal
-- escapes. How that works depends on whether we're inside tmux.
if vim.env.TMUX then
  -- Inside tmux (e.g. iTerm2 -> SSH -> tmux -> nvim). nvim's native OSC 52
  -- provider does not get forwarded through tmux here, but tmux's own
  -- clipboard forwarding (`load-buffer -w`, requires `set-clipboard on`) does
  -- -- verified end to end -- so route nvim's clipboard through tmux.
  -- `save-buffer` returns the tmux buffer for paste (`p`); use the terminal's
  -- own paste (e.g. iTerm2 Cmd+V) for text that originated outside nvim.
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

  -- Bulletproof copy: mirror every yank to the tmux clipboard on the
  -- TextYankPost event, independent of the 'clipboard' option or provider, so
  -- LazyVim's SSH guard (clipboard="") cannot defeat it.
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
else
  -- No tmux (e.g. a direct SSH terminal that supports OSC 52). Use nvim's
  -- built-in OSC 52 provider, which reaches the terminal directly here.
  vim.g.clipboard = {
    name = "OSC 52",
    copy = {
      ["+"] = require("vim.ui.clipboard.osc52").copy("+"),
      ["*"] = require("vim.ui.clipboard.osc52").copy("*"),
    },
    paste = {
      -- OSC 52 read-back is blocked by most terminals; reuse the last yank so
      -- `p` never hangs. Use the terminal's own paste for outside text.
      ["+"] = function()
        return { vim.fn.split(vim.fn.getreg(""), "\n"), vim.fn.getregtype("") }
      end,
      ["*"] = function()
        return { vim.fn.split(vim.fn.getreg(""), "\n"), vim.fn.getregtype("") }
      end,
    },
  }
end

-- LazyVim forces clipboard="" when SSH_CONNECTION is set (lazyvim/config/
-- options.lua) and its options load synchronously *after* this file, so
-- re-assert unnamedplus on a scheduled callback that runs once startup
-- settles.
vim.schedule(function()
  vim.opt.clipboard = "unnamedplus"
end)
vim.opt.background = "dark"
vim.opt.autoread = true
