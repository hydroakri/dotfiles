local wezterm = require("wezterm")
return {
	font = wezterm.font_with_fallback({
		{
			family = "Hack Nerd Font",
			harfbuzz_features = { "calt=1", "clig=1", "liga=1" },
		},
		{
			family = "Sarasa Term SC",
			harfbuzz_features = { "calt=1", "clig=1", "liga=1" },
		},
		{
			family = "Cascadia Code",
			harfbuzz_features = { "calt=1", "clig=1", "liga=1" },
		},
		{
			family = "Source Han Sans CN Regular",
			harfbuzz_features = { "calt=1", "clig=1", "liga=1" },
		},
	}),
	font_size = 16.0,
	hide_tab_bar_if_only_one_tab = true,
	initial_rows = 24,
	initial_cols = 80,
	-- default_prog = { "bash" },
	mouse_bindings = {
		-- Ctrl-click will open the link under the mouse cursor
		{
			event = { Up = { streak = 1, button = "Left" } },
			mods = "CTRL",
			action = wezterm.action.OpenLinkAtMouseCursor,
		},
	},

	-- color_scheme = "Dracula (Official)", -- or Macchiato, Frappe, Latte
	-- color_scheme = "Catppuccin Mocha", -- or Macchiato, Frappe, Latte
	-- color_scheme = "Catppuccin Frappe", -- or Macchiato, Frappe, Latte
	-- color_scheme = "Catppuccin Latte", -- or Macchiato, Frappe, Latte
	-- color_scheme = "Catppuccin Macchiato", -- or Macchiato, Frappe, Latte
	-- color_scheme = "Builtin Solarized Dark",
	-- color_scheme = "Builtin Solarized Light",
	 color_scheme = "Tomorrow Night Eighties",
	window_decorations = "RESIZE",
	-- window_background_opacity = 0.8,
	window_padding = {
		left = 0,
		right = 0,
		top = 0,
		bottom = 0,
	},
}
