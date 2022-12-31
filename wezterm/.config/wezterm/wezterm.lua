local wezterm = require 'wezterm' 
return {
    font = wezterm.font_with_fallback({
        "IBM Plex Mono Text",
        "Sarasa Mono SC",
    }),
    font_size = 14.0,

	-- ...your existing config
	-- color_scheme = "Dracula", -- or Macchiato, Frappe, Latte
	-- color_scheme = "Catppuccin Mocha", -- or Macchiato, Frappe, Latte
	color_scheme = "Catppuccin Frappe", -- or Macchiato, Frappe, Latte
	-- color_scheme = "Catppuccin Latte", -- or Macchiato, Frappe, Latte
	-- color_scheme = "Catppuccin Macchiato", -- or Macchiato, Frappe, Latte
}
