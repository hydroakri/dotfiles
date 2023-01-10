local wezterm = require 'wezterm'
return {
    font = wezterm.font_with_fallback{
        {
            family = "Sarasa Term SC Semibold",
            harfbuzz_features = { 'calt=1', 'clig=1', 'liga=1' },
        },
        {
            family = "Cascadia Code",
            harfbuzz_features = { 'calt=1', 'clig=1', 'liga=1' },
        },
        
    },
    font_size = 16.0,
    hide_tab_bar_if_only_one_tab = true,
    default_prog = { 'fish' }, 

	-- color_scheme = "Dracula", -- or Macchiato, Frappe, Latte
	-- color_scheme = "Catppuccin Mocha", -- or Macchiato, Frappe, Latte
	-- color_scheme = "Catppuccin Frappe", -- or Macchiato, Frappe, Latte
	-- color_scheme = "Catppuccin Latte", -- or Macchiato, Frappe, Latte
	-- color_scheme = "Catppuccin Macchiato", -- or Macchiato, Frappe, Latte
     color_scheme = "Solarized Dark (base16)",
    -- color_scheme = "Solarized Light (base16)",
    
    window_decorations = "RESIZE",

}
