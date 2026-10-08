{
  config,
  lib,
  pkgs,
  ...
}: let
  cfg = config.apps.opencode;
  opencodeV2 = pkgs.callPackage ../pkgs/opencode-v2 {};
in {
  options.apps.opencode.enable =
    lib.mkEnableOption "OpenCode V2 AI coding agent";

  config = lib.mkIf cfg.enable {
    home.packages = [opencodeV2];

    xdg.configFile."opencode/opencode.json".text = ''
      {
        "$schema": "https://opencode.ai/config.json",

        "permissions": [
          // ─────────────────────────────────────────────
          // Default: require approval for everything
          // ─────────────────────────────────────────────

          { "action": "*", "resource": "*", "effect": "ask" },

          // ─────────────────────────────────────────────
          // Reading the repository is OK
          // ─────────────────────────────────────────────

          { "action": "read", "resource": "*", "effect": "allow" },
          { "action": "glob", "resource": "*", "effect": "allow" },
          { "action": "grep", "resource": "*", "effect": "allow" },

          // ─────────────────────────────────────────────
          // But never read secrets
          // ─────────────────────────────────────────────

          { "action": "read", "resource": "*.env", "effect": "deny" },
          { "action": "read", "resource": "*.env.*", "effect": "deny" },

          { "action": "read", "resource": "*.pem", "effect": "deny" },
          { "action": "read", "resource": "*.key", "effect": "deny" },
          { "action": "read", "resource": "*.p12", "effect": "deny" },
          { "action": "read", "resource": "*.pfx", "effect": "deny" },

          { "action": "read", "resource": "secrets/**", "effect": "deny" },

          // ─────────────────────────────────────────────
          // Every modification requires approval
          // edit covers edit/write/patch
          // ─────────────────────────────────────────────

          { "action": "edit", "resource": "*", "effect": "ask" },

          // ─────────────────────────────────────────────
          // Shell commands require approval
          // ─────────────────────────────────────────────

          { "action": "shell", "resource": "*", "effect": "ask" },

          // Safe Git inspection can happen automatically
          { "action": "shell", "resource": "git status *", "effect": "allow" },
          { "action": "shell", "resource": "git diff *", "effect": "allow" },
          { "action": "shell", "resource": "git log *", "effect": "allow" },
          { "action": "shell", "resource": "git show *", "effect": "allow" },

          // ─────────────────────────────────────────────
          // Git state-changing operations: NEVER
          // ─────────────────────────────────────────────

          { "action": "shell", "resource": "git add *", "effect": "deny" },
          { "action": "shell", "resource": "git commit *", "effect": "deny" },
          { "action": "shell", "resource": "git push *", "effect": "deny" },
          { "action": "shell", "resource": "git pull *", "effect": "deny" },
          { "action": "shell", "resource": "git fetch *", "effect": "deny" },
          { "action": "shell", "resource": "git reset *", "effect": "deny" },
          { "action": "shell", "resource": "git checkout *", "effect": "deny" },
          { "action": "shell", "resource": "git switch *", "effect": "deny" },
          { "action": "shell", "resource": "git restore *", "effect": "deny" },
          { "action": "shell", "resource": "git clean *", "effect": "deny" },

          // Don't allow arbitrary writes through git commands
          { "action": "shell", "resource": "git *", "effect": "deny" },

          // ─────────────────────────────────────────────
          // Never leave the project
          // ─────────────────────────────────────────────

          { "action": "external_directory", "resource": "*", "effect": "deny" }
        ]
      }
    '';
  };
}
