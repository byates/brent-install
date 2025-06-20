return {
	{
		"MagicDuck/grug-far.nvim",
		keys = {
			{
				"<leader>rw",
				function()
					require("grug-far").open({
						prefills = { search = vim.fn.expand("<cword>"), paths = vim.fn.expand("%") },
					})
					vim.defer_fn(function()
						vim.api.nvim_feedkeys(vim.api.nvim_replace_termcodes("<Esc>ji", true, false, true), "n", false)
					end, 50)
				end,
				desc = "Replace current word",
			},
		},
	},
}
