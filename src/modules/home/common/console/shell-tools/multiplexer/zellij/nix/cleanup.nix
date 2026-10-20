{
  config,
  lib,
  pkgs,
  ...
}: let
  cfg = config.apps.zellij;

  cleanupScript = pkgs.writeShellApplication {
    name = "zellij-session-cleanup";
    runtimeInputs = [
      config.programs.zellij.package
      pkgs.coreutils
      pkgs.gnugrep
      pkgs.gnused
    ];
    text = ''
      max_age_days="''${1:-${toString cfg.cleanup.maxAgeDays}}"

      if ! printf '%s' "$max_age_days" | grep -Eq '^[0-9]+$'; then
        echo "usage: zellij-session-cleanup [max-age-days]" >&2
        exit 1
      fi

      max_age_secs=$((max_age_days * 86400))

      duration_to_seconds() {
        local total=0
        local token num unit
        local -a tokens

        read -ra tokens <<<"$1"
        for token in "''${tokens[@]}"; do
          num="''${token%%[!0-9]*}"
          unit="''${token#"$num"}"

          case "$unit" in
            year | years) total=$((total + num * 31557600)) ;;
            month | months) total=$((total + num * 2630016)) ;;
            day | days) total=$((total + num * 86400)) ;;
            h) total=$((total + num * 3600)) ;;
            m) total=$((total + num * 60)) ;;
            s) total=$((total + num)) ;;
            ms | us | ns) ;;
            *)
              echo "unknown duration unit: $unit" >&2
              return 1
              ;;
          esac
        done

        echo "$total"
      }

      sessions="$(zellij list-sessions -n 2>/dev/null || true)"

      while IFS= read -r line; do
        case "$line" in
          *"(EXITED - attach to resurrect)"*) ;;
          *) continue ;;
        esac

        name="''${line%% \[Created *}"
        duration="$(printf '%s\n' "$line" | sed -n 's/.*\[Created \(.*\) ago\].*/\1/p')"

        if [ -z "$duration" ]; then
          continue
        fi

        if ! age="$(duration_to_seconds "$duration")"; then
          continue
        fi

        if [ "$age" -ge "$max_age_secs" ]; then
          echo "deleting zellij session '$name' (age ''${age}s)"
          zellij delete-session "$name" || echo "failed to delete zellij session '$name'" >&2
        fi
      done <<<"$sessions"
    '';
  };
in
  lib.mkMerge [
    {
      home.packages = [cleanupScript];
    }

    (lib.mkIf (cfg.cleanup.enable && pkgs.stdenv.hostPlatform.isLinux) {
      systemd.user.services.zellij-session-cleanup = {
        Unit.Description = "Delete exited zellij sessions";
        Service = {
          Type = "oneshot";
          ExecStart = "${cleanupScript}/bin/zellij-session-cleanup";
        };
      };

      systemd.user.timers.zellij-session-cleanup = {
        Unit.Description = "Delete exited zellij sessions every hour";
        Timer = {
          OnCalendar = "hourly";
          Persistent = true;
        };
        Install.WantedBy = ["timers.target"];
      };
    })

    (lib.mkIf (cfg.cleanup.enable && pkgs.stdenv.hostPlatform.isDarwin) {
      launchd.agents.zellij-session-cleanup = {
        enable = true;
        config = {
          ProgramArguments = ["${cleanupScript}/bin/zellij-session-cleanup"];
          StartInterval = 3600;
          RunAtLoad = true;
        };
      };
    })
  ]
