{ config, lib, pkgs, ... }:

let
  cfg = config.my.kakoune;

  editor = import ./editor.nix;
  lsp = import ./lsp.nix;

  editorConfig = editor {
    inherit config lib pkgs;
  };

  lspConfig = lsp {
    inherit config lib pkgs;
  };

  nixConfig = lib.mkMerge [
    editorConfig.nix
    lspConfig.nix
  ];

  kakouneConfig = lib.concatStringsSep "\n" [
    editorConfig.kakoune
    lspConfig.kakoune
  ];
in
{
  options.my.kakoune = {
    enable = lib.mkEnableOption "Kakoune editor";
  };

  config = lib.mkIf cfg.enable (
    lib.mkMerge [
      nixConfig

      {
        programs.kakoune.extraConfig = kakouneConfig;
      }
    ]
  );
}
