{ config, lib, pkgs, ... }:

with lib;

let
  cfg = config.services.ai;

  modelFile = pkgs.fetchurl {
    url = cfg.modelUrl;
    sha256 = cfg.modelSha256;
  };

in
{
  options.services.ai = {

    enable = mkEnableOption "Native llama.cpp OpenAI-compatible server";

    modelUrl = mkOption {
      type = types.str;
      description = "Direct URL to public GGUF model.";
    };

    modelSha256 = mkOption {
      type = types.str;
      description = "sha256 of GGUF model.";
    };

    ctxSize = mkOption {
      type = types.int;
      default = 2048;
    };

    threads = mkOption {
      type = types.int;
      default = 4;
    };

    port = mkOption {
      type = types.int;
      default = 8000;
    };

    openFirewall = mkOption {
      type = types.bool;
      default = true;
    };

    openClaw.enable = mkEnableOption "OpenClaw agent";

  };

  config = mkIf cfg.enable {

    networking.firewall.allowedTCPPorts =
      mkIf cfg.openFirewall (
        [ cfg.port ] ++ optional cfg.openClaw.enable 3000
      );

    systemd.services.llama = {
      description = "llama.cpp OpenAI server";
      after = [ "network.target" ];
      wantedBy = [ "multi-user.target" ];

      serviceConfig = {
        ExecStart = ''
          ${pkgs.llama-cpp}/bin/llama-server \
            -m ${modelFile} \
            --host 0.0.0.0 \
            --port ${toString cfg.port} \
            --ctx-size ${toString cfg.ctxSize} \
            --threads ${toString cfg.threads} \
            --parallel 1 \
            --batch-size 512
        '';

        Restart = "always";
        RestartSec = 3;

        MemoryMax = "10G";
        CPUQuota = "${toString (cfg.threads * 100)}%";

        NoNewPrivileges = true;
        ProtectSystem = "strict";
        ProtectHome = true;
        PrivateTmp = true;
      };
    };

    systemd.services.openclaw = mkIf cfg.openClaw.enable {
      description = "OpenClaw Agent";
      after = [ "llama.service" ];
      wantedBy = [ "multi-user.target" ];

      serviceConfig = {
        ExecStart = "${pkgs.nodejs}/bin/npx openclaw";
        Restart = "always";
        RestartSec = 5;

        Environment = [
          "OPENAI_BASE_URL=http://localhost:${toString cfg.port}/v1"
          "OPENAI_API_KEY=dummy"
          "OPENAI_MODEL=local-model"
        ];

        MemoryMax = "2G";
      };
    };
  };
}
