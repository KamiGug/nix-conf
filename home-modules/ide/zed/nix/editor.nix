{
  # Do NOT set `mutableUserSettings = false`: with userSettings/extensions empty
  # that key is a no-op, but the moment either is set it makes home-manager also
  # write zed/settings.json, conflicting with the template managed below.
  programs.zed-editor.enable = true;
}
