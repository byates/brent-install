return {
  { "ellisonleao/gruvbox.nvim" },
  { "catppuccin/nvim", name = "catppuccin" },
  {
    "folke/tokyonight.nvim",
    name = "tokyonight",
    lazy = false,
    opts = {
      style = "storm",
    },
  },
  {
    "LazyVim/LazyVim",
    opts = {
      colorscheme = "tokyonight-storm",
      colorscheme_opts = {
        gruvbox = {
          contrast = "hard",
          background = "dark",
        },
      },
    },
  },
}
