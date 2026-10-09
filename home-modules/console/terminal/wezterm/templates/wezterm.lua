local wezterm = require 'wezterm'
local config = wezterm.config_builder()

config.font = wezterm.font("{{ font }}")
config.font_size = 12
config.colors = { foreground = "#ffffff" }
config.hide_tab_bar_if_only_one_tab = true
config.keys = {
  { key = "Z", mods = "CTRL", action = "DisableDefaultAssignment" },
}

return config
