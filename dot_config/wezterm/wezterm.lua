local wezterm = require("wezterm")
local home = os.getenv("HOME")
-- wezterm.add_to_config_reload_watch_list(home .. "/.cache/wal/wezterm.toml")

function get_appearance()
	if wezterm.gui then
		return wezterm.gui.get_appearance()
	end
	return "Dark"
end

function scheme_for_appearance(appearance)
	if appearance:find("Dark") then
		return "Flexoki Dark"
	else
		return "Flexoki Light"
	end
end

local config = {
	font = wezterm.font_with_fallback({
		{
			family = "Cascadia Code",
			harfbuzz_features = { "calt=1", "clig=1", "liga=1", "ss01=1" },
		},
		{
			family = "Fira Code",
			harfbuzz_features = { "cv01=1", "ss05=1", "ss10=1", "ss03=1", "cv02=1", "ss01=1", "zero=1" },
		},
		-------- The quick brown fox jumps over the lazy dog
		{
			family = "Hiragino Sans GB",
		},
		{
			family = "Noto Sans CJK SC",
		},
	}),
	font_rules = {
		{
			italic = true,
			font = wezterm.font_with_fallback({
				{
					family = "Operator Mono",
					style = "Italic",
					harfbuzz_features = { "calt=1", "clig=1", "liga=1", "ss01=1" },
				},
				-------- 東国三力今書鷹酬鬱愛袋永遍角次亮采之门
				{
					family = "FZFW ZhuZi MinchoS",
					style = "Italic",
				},
				{
					family = "Noto Serif CJK SC",
					style = "Italic",
				},
			}),
		},
	},
	-- default_prog = { "/usr/bin/fish", "-l" },
	enable_wayland = true,
	font_size = 12.0,
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
	color_scheme = scheme_for_appearance(get_appearance()),

	-- window_decorations = "RESIZE",
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
