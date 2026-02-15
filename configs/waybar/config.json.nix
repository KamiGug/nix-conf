{launcher ? "fuzzel"}:
builtins.toJSON {
  layer = "top";
  position = "left";
  orientation = "vertical";
  width = 44;

  modules-left = [
    "custom/launcher"
    "workspaces"
    "clock"
    "network"
    "bluetooth"
    "pulseaudio"
    "battery"
    "tray"
    "custom/power"
  ];

  # --- Launcher ---
  "custom/launcher" = {
    format = "";
    tooltip = false;
    on-click = launcher;
  };

  # --- Clock ---
  clock.format = "{:%H:%M}";

  # --- Network ---
  network = {
    format-wifi = "";
    format-ethernet = "󰈀";
    format-disconnected = "󰖪";
    on-click = "nm-connection-editor";
  };

  # --- Bluetooth ---
  bluetooth = {
    format = "";
    format-disabled = "󰂲";
    on-click = "blueman-manager";
  };

  # --- Sound ---
  pulseaudio = {
    format = "{volume}% ";
    format-muted = "󰝟";
    on-click = "pavucontrol";
  };

  # --- Battery ---
  battery.format = "{capacity}%";

  # --- Power Menu ---
  "custom/power" = {
    format = "⏻";
    tooltip = false;
    on-click = ''
      fuzzel -d "Select Action" \
        "Shutdown" "systemctl poweroff" \
        "Reboot" "systemctl reboot" \
        "Logout" "swaymsg exit" \
        "Lock" "swaylock"
    '';
  };

  # --- Power Profiles ---
  "custom/powerprofiles" = {
    format = "⚡";
    tooltip = false;
    on-click = ''
      fuzzel -d "Power Profile" \
        "Power Saver" "sudo systemctl set-power-profile low" \
        "Balanced" "sudo systemctl set-power-profile balanced" \
        "Performance" "sudo systemctl set-power-profile performance"
    '';
  };

  tray.spacing = 8;
}
