local wezterm = require("wezterm")
local home = os.getenv("HOME")
wezterm.add_to_config_reload_watch_list(home .. "/.cache/wal/wezterm.toml")

local color_scheme
local hour = tonumber(os.date("%H"))
if hour >= 6 and hour < 18 then
	color_scheme = "flexoki-light"
else
	color_scheme = "flexoki-dark"
end

local config = {
	font = wezterm.font_with_fallback({
		{
			family = "CaskaydiaCove NFM",
			harfbuzz_features = { "calt=1", "clig=1", "liga=1", "ss01=1" },
		},
		{
			family = "Noto Sans CJK SC",
			harfbuzz_features = { "calt=1", "clig=1", "liga=1" },
		},
	}),
	font_rules = {
		{
			italic = true,
			font = wezterm.font_with_fallback({
				{
					family = "Operator Mono",
					-- family = "CaskaydiaCove NFM",
					style = "Italic",
					harfbuzz_features = { "calt=1", "clig=1", "liga=1", "ss01=1" },
				},
				{
					family = "Zhuque Fangsong (technical preview)",
					style = "Italic",
					harfbuzz_features = { "calt=1", "clig=1", "liga=1" },
				},
			}),
		},
	},
	enable_wayland = false,
	font_size = 16.0,
	hide_tab_bar_if_only_one_tab = true,
	initial_rows = 24,
	initial_cols = 80,
	mouse_bindings = {
		-- Ctrl-click will open the link under the mouse cursor
		{
			event = { Up = { streak = 1, button = "Left" } },
			mods = "CTRL",
			action = wezterm.action.OpenLinkAtMouseCursor,
		},
	},
	-- colorscheme
	color_scheme_dirs = { home .. "/.cache/wal" },
	-- color_scheme = "pywal", -- wezterm uses pywal file in ~/.cache/wal/wezterm.toml
	color_scheme = color_scheme,

	window_decorations = "RESIZE",
	-- window_background_opacity = 0.9,
	window_close_confirmation = "NeverPrompt",
	window_padding = {
		left = 0,
		right = 0,
		top = 0,
		bottom = 0,
	},
}
return config
