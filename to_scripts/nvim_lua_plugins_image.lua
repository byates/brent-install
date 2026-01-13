return {
  "3rd/image.nvim",
  dependencies = { "nvim-treesitter/nvim-treesitter" },
  opts = {
    backend = "kitty",
    processor = "magick_cli",
    integrations = {
      markdown = {
        enabled = true,
        clear_in_insert_mode = false,
        only_render_image_at_cursor = false,
      },
    },
    max_width = 200,
    max_height = 200,
    max_width_window_percentage = 100,
    max_height_window_percentage = 100,
  },
}
