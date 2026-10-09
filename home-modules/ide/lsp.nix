{
  lib,
  ...
}: {
  options.apps.lsp = lib.mkOption {
    type = lib.types.nullOr lib.types.attrs;
    default = null;
    description = ''
      Precomputed LSP selection shared by every editor module, normally
      `myLib.lsp.mkServers { blacklist = [...]; }`. When null each editor
      module runs `myLib.lsp.mkServers {}` itself.
    '';
  };
}
