local wezterm = require 'wezterm'
return {
    font = wezterm.font_with_fallback{
        {
            family = "Sarasa Term SC Semibold",
            harfbuzz_features = { 'calt=1', 'clig=1', 'liga=1' },
        },
        {
            family = "FiraCode Nerd Font",
            weight = 'Medium',
            harfbuzz_features = { 'calt=1', 'clig=1', 'liga=1' },
        },
        {
            family = "Cascadia Code",
            harfbuzz_features = { 'calt=1', 'clig=1', 'liga=1' },
        },
        -- {
        --     family = "Source Han Sans CN Medium",
        --     harfbuzz_features = { 'calt=1', 'clig=1', 'liga=1' },
        -- },
    },
    font_size = 20.0,
    hide_tab_bar_if_only_one_tab = true,
    default_prog = { 'fish' },
    mouse_bindings = {
  -- Ctrl-click will open the link under the mouse cursor
  {
    event = { Up = { streak = 1, button = 'Left' } },
    mods = 'CTRL',
    action = wezterm.action.OpenLinkAtMouseCursor,
  },
},

	-- color_scheme = "Dracula (Official)", -- or Macchiato, Frappe, Latte
	 color_scheme = "Catppuccin Mocha", -- or Macchiato, Frappe, Latte
	-- color_scheme = "Catppuccin Frappe", -- or Macchiato, Frappe, Latte
	-- color_scheme = "Catppuccin Latte", -- or Macchiato, Frappe, Latte
	-- color_scheme = "Catppuccin Macchiato", -- or Macchiato, Frappe, Latte
    -- color_scheme = "Solarized Dark (base16)",
    -- color_scheme = "Solarized Light (base16)",
    window_decorations = "RESIZE",
    -- window_background_opacity = 0.8,
    window_padding = {
        left = 0,
        right = 0,
        top = 0,
        bottom = 0,
    },

}
