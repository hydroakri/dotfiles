local wezterm = require("wezterm")
local home = os.getenv("HOME")
wezterm.add_to_config_reload_watch_list(home .. '/.cache/wal/wezterm.toml')

local config = {
	font = wezterm.font_with_fallback({
		{
			family = "CaskaydiaCove NF",
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
			family = "Noto Sans CJK SC",
			harfbuzz_features = { "calt=1", "clig=1", "liga=1" },
		},
	}),
	enable_wayland = false,
	font_size = 18.0,
	hide_tab_bar_if_only_one_tab = true,
	initial_rows = 29,
	initial_cols = 82,
	default_prog = { "fish" },
	mouse_bindings = {
		-- Ctrl-click will open the link under the mouse cursor
		{
			event = { Up = { streak = 1, button = "Left" } },
			mods = "CTRL",
			action = wezterm.action.OpenLinkAtMouseCursor,
		},
	},
    -- colorscheme
    color_scheme_dirs = { home .. '/.cache/wal' },
    color_scheme = "pywal",
	window_decorations = "RESIZE",
	window_background_opacity = 0.8,
	window_close_confirmation = "NeverPrompt",
	window_padding = {
		left = 0,
		right = 0,
		top = 0,
		bottom = 0,
	},
}
return config
