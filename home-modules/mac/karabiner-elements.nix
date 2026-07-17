{
  config,
  lib,
  pkgs,
  ...
}: let
  cfg = config.apps.karabiner;
in {
  options.apps.karabiner = {
    enable = lib.mkEnableOption "Karabiner Elements configuration";

    swapBacktickSection = lib.mkOption {
      type = lib.types.bool;
      default = true;
      description = "Swap § and ` keys";
    };
  };

  config = lib.mkIf cfg.enable {
    # home.packages = [
    #   pkgs.karabiner-elements
    # ];

    home.file.".config/karabiner/karabiner.json".text = let
      swapRules = lib.optionals cfg.swapBacktickSection [
        {
          from = {
            key_code = "grave_accent_and_tilde";
          };

          to = [
            {
              key_code = "non_us_backslash";
            }
          ];
        }

        {
          from = {
            key_code = "non_us_backslash";
          };

          to = [
            {
              key_code = "grave_accent_and_tilde";
            }
          ];
        }
      ];
    in
      builtins.toJSON {
        global = {
          check_for_updates_on_startup = false;
        };

        profiles = [
          {
            name = "default";
            selected = true;

            devices = [
              {
                identifiers = {
                  is_keyboard = true;
                };

                simple_modifications = swapRules;
              }
            ];

            virtual_hid_keyboard = {
              keyboard_type_v2 = "ansi";
            };
          }
        ];
      };
  };
}
