{
  config,
  lib,
  pkgs,
  ...
}: let
  cfg = config.my.gaming;
  gameify = pkgs.writeShellScriptBin "gameify" ''
    #!/usr/bin/env bash
    if [ "$#" -eq 0 ]; then
      echo "Usage: gameify <command> [args...]"
      exit 1
    fi
    TO_RUN="$@"

    if [ -n "$(gamescope)" ]; then
        TO_RUN="
        ${lib.getExe pkgs.gamescope} \
          -b \
          --xwayland-count 3 \
          -W 1920 \
          -H 1080 \
          --mangoapp \
          --force-grab-cursor \
          -- $TO_RUN"
    fi

    if [ -n "$(nvidia-offload)" ]; then
        TO_RUN="nvidia-offload $TO_RUN"
    fi

    echo $TO_RUN
  '';

  inherit
    (lib)
    mkEnableOption
    mkOption
    mkIf
    types
    optional
    optionals
    ;
in {
  options.my.gaming = {
    enable = mkEnableOption "gaming configuration";

    steam = {
      enable = mkEnableOption "Steam";

      gamescope = mkOption {
        type = types.bool;
        default = true;
        description = "Enable Gamescope session support for Steam.";
      };

      remotePlayFirewall = mkOption {
        type = types.bool;
        default = true;
        description = "Open firewall for Steam Remote Play.";
      };

      dedicatedServerFirewall = mkOption {
        type = types.bool;
        default = false;
        description = "Open firewall for Steam dedicated servers.";
      };
    };

    lutris.enable = mkEnableOption "Lutris";
    heroic.enable = mkEnableOption "Heroic Games Launcher";

    gamemode.enable = mkOption {
      type = types.bool;
      default = true;
      description = "Enable GameMode.";
    };

    mangohud.enable = mkOption {
      type = types.bool;
      default = true;
      description = "Install MangoHud.";
    };

    gamescope.enable = mkOption {
      type = types.bool;
      default = true;
      description = "Install Gamescope.";
    };

    sunshine = {
      enable = mkOption {
        type = types.bool;
        default = false;
        description = "Install and autostart Sunshine";
      };
      waylandSupport = mkOption {
        type = types.bool;
        default = true;
        description = "Enable on a linux install with wayland";
      };
    };

    nvidia = {
      enable = mkEnableOption "NVIDIA configuration";

      open = mkOption {
        type = types.bool;
        default = false;
        description = "Use NVIDIA open kernel modules.";
      };

      package = mkOption {
        type = types.nullOr types.package;
        default = null;
        description = "Custom NVIDIA driver package.";
      };

      prime = {
        enable = mkOption {
          type = types.bool;
          default = false;
          description = "Enable NVIDIA PRIME offload (hybrid graphics).";
        };

        intelBusId = mkOption {
          type = types.nullOr types.str;
          default = null;
          example = "PCI:0:2:0";
          description = "Intel GPU PCI bus ID.";
        };

        nvidiaBusId = mkOption {
          type = types.nullOr types.str;
          default = null;
          example = "PCI:1:0:0";
          description = "NVIDIA GPU PCI bus ID.";
        };
      };
    };
  };

  config = mkIf cfg.enable {
    hardware.graphics = {
      enable = true;
      enable32Bit = true;
    };

    security.rtkit.enable = true;

    programs.gamemode.enable = cfg.gamemode.enable;

    programs.steam = mkIf cfg.steam.enable {
      enable = true;

      gamescopeSession.enable = cfg.steam.gamescope;

      remotePlay.openFirewall = cfg.steam.remotePlayFirewall;

      dedicatedServer.openFirewall =
        cfg.steam.dedicatedServerFirewall;
      package = pkgs.steam.override {
        extraPkgs = pkgs':
          with pkgs';
            optionals cfg.mangohud.enable [
              mangohud
            ];
        extraArgs = "-system-composer";
      };
    };

    programs.xwayland.enable = true;

    environment.systemPackages = with pkgs;
      [
        vulkan-tools
        mesa-demos
        protonup-ng
        gameify
      ]
      ++ optional cfg.gamescope.enable gamescope
      ++ optional cfg.mangohud.enable mangohud
      ++ optional cfg.lutris.enable lutris
      ++ optional cfg.heroic.enable heroic;

    environment.sessionVariables = {
      STEAM_EXTRA_COMPAT_TOOLS_PATHS = "\${HOME}/.steam/root/compatibilitytools.d";
    };

    services.sunshine = mkIf cfg.sunshine.enable {
      enable = true;
      autoStart = true;
      capSysAdmin = true;
      openFirewall = true;
    };

    security.wrappers.sunshine = mkIf cfg.sunshine.enable && cfg.sunshine.waylandSupport {
       owner = "root";
       group = "root";
       capabilities = "cap_sys_admin+p";
       source = "${pkgs.sunshine}/bin/sunshine";
    };

    # -----------------------------
    # NVIDIA (basic)
    # -----------------------------
    hardware.nvidia = mkIf cfg.nvidia.enable {
      modesetting.enable = true;
      open = cfg.nvidia.open;
      nvidiaSettings = true;

      package =
        if cfg.nvidia.package != null
        then cfg.nvidia.package
        else config.boot.kernelPackages.nvidiaPackages.stable;

      # -----------------------------
      # PRIME OFFLOAD (hybrid laptops)
      # -----------------------------
      prime = mkIf cfg.nvidia.prime.enable {
        offload.enable = true;
        offload.enableOffloadCmd = true;

        intelBusId = cfg.nvidia.prime.intelBusId;
        nvidiaBusId = cfg.nvidia.prime.nvidiaBusId;
      };
    };

    services.xserver.videoDrivers = mkIf cfg.nvidia.enable [
      "nvidia"
    ];
  };
}
