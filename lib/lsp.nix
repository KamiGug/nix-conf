{
  lib,
  pkgs,
  ...
}: let
  system =
    if pkgs.stdenv.hostPlatform.isLinux
    then "linux"
    else "darwin";

  globalIds = ["typos"];

  # Canonical language server registry: id -> { package, command, args, ... }.
  # id is the editor facing name (zed lsp key, helix language-server table key),
  # command is the binary that gets executed.
  servers = {
    rust-analyzer = {
      package = pkgs.rust-analyzer;
      command = "rust-analyzer";
      args = [];
    };

    nil = {
      package = pkgs.nil;
      command = "nil";
      args = [];
    };

    nixd = {
      package = pkgs.nixd;
      command = "nixd";
      args = [];
    };

    tix = {
      package = pkgs.tix;
      command = "tix";
      args = ["lsp"];
    };

    typescript-language-server = {
      package = pkgs.typescript-language-server;
      command = "typescript-language-server";
      args = ["--stdio"];
    };

    vscode-json-language-server = {
      package = pkgs.vscode-langservers-extracted;
      command = "vscode-json-language-server";
      args = ["--stdio"];
    };

    yaml-language-server = {
      package = pkgs.yaml-language-server;
      command = "yaml-language-server";
      args = ["--stdio"];
    };

    taplo = {
      package = pkgs.taplo;
      command = "taplo";
      args = [
        "lsp"
        "stdio"
      ];
    };

    bash-language-server = {
      package = pkgs.bash-language-server;
      command = "bash-language-server";
      args = ["start"];
    };

    fish-lsp = {
      package = pkgs.fish-lsp;
      command = "fish-lsp";
      args = ["start"];
    };

    elvish = {
      package = pkgs.elvish;
      command = "elvish";
      args = ["-lsp"];
    };

    gopls = {
      package = pkgs.gopls;
      command = "gopls";
      args = [];
    };

    clangd = {
      package = pkgs.clang-tools;
      command = "clangd";
      args = [];
    };

    pyright = {
      package = pkgs.pyright;
      command = "pyright-langserver";
      args = ["--stdio"];
    };

    roslyn = {
      package = pkgs.roslyn-ls;
      command = "Microsoft.CodeAnalysis.LanguageServer";
      args = ["--stdio"];
    };

    phpactor = {
      package = pkgs.phpactor;
      command = "phpactor";
      args = [];
    };

    cmake-language-server = {
      package = pkgs.cmake-language-server;
      command = "cmake-language-server";
      args = [];
    };

    csharp-ls = {
      package = pkgs.csharp-ls;
      command = "csharp-ls";
      args = [];
      platforms = ["linux"];
    };

    typos = {
      package = pkgs.typos-lsp;
      command = "typos-lsp";
      args = [];
      initializationOptions = {
        config_path = "./typos.toml";
        diagnostic_severity = "Warning";
      };
    };
  };

  # Language registry: lang id -> how each editor should address it.
  # filetypes are LSP/kakoune filetype names, roots are project markers,
  # editors.<name> lists the language names the given editor uses (null = skip).
  langs = {
    rust = {
      filetypes = ["rust"];
      roots = [
        "Cargo.toml"
        "Cargo.lock"
        ".git"
      ];
      servers = ["rust-analyzer"];
      editors = {
        zed = ["Rust"];
        helix = ["rust"];
      };
    };

    nix = {
      filetypes = ["nix"];
      roots = [
        "flake.nix"
        "flake.lock"
        ".git"
      ];
      servers = [
        "nixd"
        "tix"
        "nil"
      ];
      editors = {
        zed = ["Nix"];
        helix = ["nix"];
      };
    };

    typescript = {
      filetypes = [
        "typescript"
        "typescriptreact"
      ];
      roots = [
        "package.json"
        "tsconfig.json"
        "jsconfig.json"
        ".git"
      ];
      servers = ["typescript-language-server"];
      editors = {
        zed = [
          "TypeScript"
          "TSX"
        ];
        helix = [
          "typescript"
          "tsx"
        ];
      };
    };

    javascript = {
      filetypes = [
        "javascript"
        "javascriptreact"
      ];
      roots = [
        "package.json"
        "tsconfig.json"
        "jsconfig.json"
        ".git"
      ];
      servers = ["typescript-language-server"];
      editors = {
        zed = ["JavaScript"];
        helix = [
          "javascript"
          "jsx"
        ];
      };
    };

    json = {
      filetypes = ["json"];
      roots = [
        "package.json"
        ".git"
      ];
      servers = ["vscode-json-language-server"];
      editors = {
        zed = ["JSON"];
        helix = ["json"];
      };
    };

    yaml = {
      filetypes = ["yaml"];
      roots = [".git"];
      servers = ["yaml-language-server"];
      editors = {
        zed = ["YAML"];
        helix = ["yaml"];
      };
    };

    toml = {
      filetypes = ["toml"];
      roots = [
        "Cargo.toml"
        "pyproject.toml"
        ".git"
      ];
      servers = ["taplo"];
      editors = {
        zed = ["TOML"];
        helix = ["toml"];
      };
    };

    bash = {
      filetypes = [
        "bash"
        "sh"
      ];
      roots = [".git"];
      servers = ["bash-language-server"];
      editors = {
        zed = ["Shell Script"];
        helix = ["bash"];
      };
    };

    fish = {
      filetypes = ["fish"];
      roots = [
        "config.fish"
        ".git"
      ];
      servers = ["fish-lsp"];
      editors = {
        zed = null;
        helix = ["fish"];
      };
    };

    elvish = {
      filetypes = ["elvish"];
      roots = [".git"];
      servers = ["elvish"];
      editors = {
        zed = null;
        helix = ["elvish"];
      };
    };

    go = {
      filetypes = ["go"];
      roots = [
        "go.mod"
        "go.work"
        ".git"
      ];
      servers = ["gopls"];
      editors = {
        zed = ["Go"];
        helix = ["go"];
      };
    };

    c = {
      filetypes = [
        "c"
        "cpp"
        "objc"
        "objcpp"
      ];
      roots = [
        "compile_commands.json"
        "compile_flags.txt"
        ".clangd"
        ".git"
      ];
      servers = ["clangd"];
      editors = {
        zed = [
          "C"
          "C++"
        ];
        helix = [
          "c"
          "cpp"
        ];
      };
    };

    python = {
      filetypes = ["python"];
      roots = [
        "pyproject.toml"
        "setup.py"
        "setup.cfg"
        ".git"
      ];
      servers = ["pyright"];
      editors = {
        zed = ["Python"];
        helix = ["python"];
      };
    };

    csharp = {
      filetypes = ["csharp"];
      roots = [
        "*.sln"
        "*.csproj"
        ".git"
      ];
      servers = [
        "roslyn"
        "csharp-ls"
      ];
      editors = {
        zed = ["C#"];
        helix = ["c-sharp"];
      };
    };

    php = {
      filetypes = ["php"];
      roots = [
        "composer.json"
        "composer.lock"
        ".git"
      ];
      servers = ["phpactor"];
      editors = {
        zed = ["PHP"];
        helix = ["php"];
      };
    };

    cmake = {
      filetypes = ["cmake"];
      roots = [
        "CMakeLists.txt"
        ".git"
      ];
      servers = ["cmake-language-server"];
      editors = {
        zed = ["CMake"];
        helix = ["cmake"];
      };
    };
  };

  resolve = ids:
    lib.filterAttrs
    (
      _: server:
        !(server ? platforms)
        || lib.elem system server.platforms
    )
    (lib.genAttrs ids (id: servers.${id}));

  # mkServers { blacklist } selects languages and servers.
  # Entries are either "lang" (drop the language) or "lang/server-id"
  # (drop one server, the language stays if other servers remain).
  # Plain entries also drop a global server with that id. Defaults to {}.
  mkServers = {blacklist ? []}: let
    parts =
      map (
        entry:
          if lib.hasInfix "/" entry
          then let
            segments = lib.splitString "/" entry;
          in {
            lang = lib.elemAt segments 0;
            server = lib.elemAt segments 1;
          }
          else {
            lang = entry;
            server = null;
          }
      )
      blacklist;

    unknown =
      lib.filter (
        part:
          if part.server == null
          then
            !(builtins.hasAttr part.lang langs)
            && !(lib.elem part.lang globalIds)
          else
            !(builtins.hasAttr part.lang langs)
            || !(lib.elem part.server langs.${part.lang}.servers)
      )
      parts;

    rendered =
      lib.concatMapStringsSep ", " (
        part:
          if part.server == null
          then part.lang
          else "${part.lang}/${part.server}"
      )
      unknown;

    dropLangs = lib.map (part: part.lang) (lib.filter (part: part.server == null) parts);
    dropServers = lib.filter (part: part.server != null) parts;

    keep = lang: server:
      !(lib.any (part: part.lang == lang && part.server == server) dropServers);

    selectedLangs = lib.mapAttrs (
      lang: value:
        value
        // {
          servers = resolve (lib.filter (keep lang) value.servers);
        }
    ) (lib.filterAttrs (lang: _: !(lib.elem lang dropLangs)) langs);

    selectedGlobals = lib.filter (id: !(lib.elem id dropLangs)) globalIds;
  in
    if unknown != []
    then throw "myLib.lsp.mkServers: unknown blacklist entries: ${rendered}"
    else {
      langs = lib.filterAttrs (_: value: value.servers != {}) selectedLangs;
      globals = resolve selectedGlobals;
    };
in {
  inherit servers langs mkServers;
  globals = resolve globalIds;
}
