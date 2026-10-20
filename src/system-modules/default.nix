{
  # ./common.nix
  # ./common-linux.nix
  # ./common-gui-linux.nix
  # ./common-darwin.nix
  common = [
  ];
  darwin = [
  ];
  linux = [
    ./gaming.nix
    ./avahi.nix
    ./autologin.nix
    ./printing.nix
    ./luks-key.nix
    ./usb-luks-key.nix
  ];
}
