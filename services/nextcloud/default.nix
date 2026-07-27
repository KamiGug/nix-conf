{
  pkgs,
  config,
  lib,
  myLib,
  # inputs,
  ...
}:
let
  cfg = config.services.nextcloud;
  testScript = lib.trace pkgs.writeShellScriptBin "test1" "echo 'some config';";
in
{
  options.services.nextcloud = {
     enable = lib.mkEnableOption "Run a nextcloud service";
   };

   config = lib.mkIf cfg.enable ({
     environment.systemPackages = [ testScript ];
   } //  myLib.apps.nextcloud {
       configArgs = {
         protocol = "http";
         rootDomain = "arpa";
         # domain = "127.0.0.1";
       };
     });
}
