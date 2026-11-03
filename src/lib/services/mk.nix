{
  pkgs,
  lib,
  ...
}: {
  name,
  postfix ? "",
  dir,
  templates ? null,
  templatesRecursive ? false,
  composeTemplate ? "auto",
  baseImage ? null,
  buildArgs ? {},
  buildFiles ? {},
  dockerfile ? "Dockerfile",
  backend ? "podman",
  networks ? [],
  ports ? [],
  volumes ? [],
  environment ? {},
  secrets ? {},
  command ? [],
  entrypoint ? null,
  dependsOn ? [],
  healthcheck ? null,
  shmSize ? null,
  privileged ? false,
  gpu ? false,
  hostname ? null,
  serviceUser ? "root",
  containerUser ? null,
  labels ? {},
  extraOptions ? [],
  templateVars ? {},
  fileEnvSupport ? false,
  domain ? null,
  protocol ? null,
  root ? null,
  sopsFile ? null,
  configMount ? null,
}: let
  fullName = "${name}${postfix}";
  image = "localhost/${fullName}:latest";

  render = import ./render.nix {inherit pkgs lib;};
  buildImage = import ./buildImage.nix {inherit pkgs lib;};
  mkVolume = import ./mkVolume.nix;
  mkNetwork = import ./mkNetwork.nix;

  renderVars =
    templateVars
    // {
      inherit
        name
        postfix
        fullName
        domain
        protocol
        root
        networks
        ;
    };

  templatesDir =
    if templates != null
    then templates
    else if builtins.pathExists (dir + "/templates")
    then dir + "/templates"
    else null;

  walkTemplates = prefix: path: let
    entries = builtins.readDir path;
  in
    lib.concatMap (
      entry: let
        child = path + "/${entry}";
        rel =
          if prefix == ""
          then entry
          else "${prefix}/${entry}";
        kind = entries.${entry};
      in
        if kind == "directory"
        then
          (
            if templatesRecursive
            then walkTemplates rel child
            else []
          )
        else if kind == "regular"
        then [
          {
            inherit rel;
            file = child;
          }
        ]
        else []
    ) (builtins.attrNames entries);

  templateFiles =
    if templatesDir == null
    then []
    else walkTemplates "" templatesDir;

  renderedName = rel: lib.removeSuffix ".jinja" (baseNameOf rel);

  config = builtins.listToAttrs (map (f: {
      name = f.rel;
      value = render {
        template = f.file;
        vars = renderVars;
        name = renderedName f.rel;
      };
    })
    templateFiles);

  configVolumes = lib.optionals (configMount != null) (map (rel:
    mkVolume {
      hostPath = "${config.${rel}}/${renderedName rel}";
      containerPath = "${configMount}/${lib.removeSuffix ".jinja" rel}";
      readOnly = true;
      create = false;
    })
  (builtins.attrNames config));

  composePath =
    if composeTemplate == null
    then null
    else if builtins.isPath composeTemplate
    then composeTemplate
    else if composeTemplate == "auto"
    then
      (
        if builtins.pathExists (dir + "/compose.yml.jinja")
        then dir + "/compose.yml.jinja"
        else null
      )
    else dir + "/${composeTemplate}";

  compose =
    if composePath == null
    then null
    else
      render {
        template = composePath;
        vars = renderVars;
        name = "compose.yml";
      };

  secretList =
    lib.mapAttrsToList (var: value: let
      sopsName = value.sopsName or "services/${fullName}/${var}";
      path = value.path or "/run/secrets/${sopsName}";
      envName = value.env or var;
      containerPath =
        value.containerPath
        or (
          if lib.hasPrefix "/run/secrets/" path
          then path
          else "/run/secrets/${envName}"
        );
      effectiveSopsFile = value.sopsFile or sopsFile;
      key = value.key or null;
      optional = value.optional or false;
      random = value.random or null;
      declaredByMk =
        effectiveSopsFile
        != null
        || key != null
        || (value.path or null) != null
        || (value.owner or null) != null
        || (value.group or null) != null
        || (value.mode or null) != null
        || random != null;
      include = !(optional && !declaredByMk);
      sopsOptions = lib.filterAttrs (_: v: v != null) {
        sopsFile = effectiveSopsFile;
        inherit key;
        path = value.path or null;
        mode = value.mode or null;
        owner = value.owner or null;
        group = value.group or null;
        format = value.format or null;
        neededForUsers = value.neededForUsers or null;
      };
    in {
      inherit
        var
        sopsName
        path
        envName
        containerPath
        optional
        include
        declaredByMk
        random
        sopsOptions
        ;
    })
    secrets;

  secretVolumes =
    map
    (s:
      mkVolume {
        hostPath = s.path;
        inherit (s) containerPath;
        readOnly = true;
        create = false;
      })
    (builtins.filter (s: s.include) secretList);

  fileEnv = lib.optionalAttrs fileEnvSupport (builtins.listToAttrs (map (s: {
      name = "${s.envName}_FILE";
      value = s.containerPath;
    })
    (builtins.filter (s: s.include) secretList)));

  sopsModule = {
    sops.secrets = builtins.listToAttrs (map (s: {
        name = s.sopsName;
        value = s.sopsOptions;
      })
      (builtins.filter (s: s.declaredByMk && s.random == null) secretList));
    systemd.services = lib.optionalAttrs (secretList != []) {
      "podman-${fullName}" = {
        after = ["sops-install-secrets.service"];
        wants = ["sops-install-secrets.service"];
      };
    };
  };

  randomModule = {
    systemd.services = builtins.listToAttrs (map (s: {
        name = "random-secret-${lib.replaceStrings ["/" "."] ["-" "-"] s.sopsName}";
        value = {
          description = "Generate ${s.sopsName} on first use";
          wantedBy = ["multi-user.target"];
          before = [
            "sops-install-secrets.service"
            "podman-${fullName}.service"
          ];
          serviceConfig = {
            Type = "oneshot";
            RemainAfterExit = true;
          };
          script = ''
            set -euo pipefail
            path=${lib.escapeShellArg s.path}
            mkdir -p "$(dirname "$path")"
            if [ ! -s "$path" ]; then
              umask 077
              ${pkgs.openssl}/bin/openssl rand -hex 32 >"$path"
            fi
          '';
        };
      })
      (builtins.filter (s: s.include && s.random != null) secretList));
  };

  networkNames = map (n:
    (mkNetwork {
      name = n;
      inherit postfix;
    }).name)
  networks;

  containerModule = import ./container.nix {inherit pkgs lib;} {
    inherit
      image
      backend
      serviceUser
      containerUser
      ports
      labels
      command
      entrypoint
      healthcheck
      shmSize
      privileged
      gpu
      hostname
      dependsOn
      ;
    name = fullName;
    environment = environment // fileEnv;
    volumes = volumes ++ configVolumes ++ secretVolumes;
    extraOptions = extraOptions ++ map (n: "--network=${n}") networkNames;
  };

  ensureDir = import ../file/ensureDirExists.nix {inherit pkgs;};
  volumeModule =
    lib.foldl'
    (acc: volume:
      acc
      // (
        if builtins.isAttrs volume && (volume.create or false)
        then
          ensureDir {
            path = volume.hostMount;
            owner = volume.owner or null;
            group = volume.group or null;
            mode = volume.mode or null;
            parentServiceName = "podman-${fullName}";
          }
        else {}
      ))
    {}
    volumes;

  effectiveBuildArgs =
    lib.optionalAttrs (baseImage != null) {BASE_IMAGE = baseImage;} // buildArgs;

  buildContext = buildImage {
    inherit dockerfile;
    src = dir;
    secretEnvs = builtins.attrNames secrets;
    extraFiles = buildFiles;
  };

  contextHash = builtins.hashString "sha256" (toString buildContext.context);

  buildArgsFlags = lib.concatStringsSep " " (lib.mapAttrsToList (key: value: "--build-arg ${key}=${lib.escapeShellArg (toString value)}") effectiveBuildArgs);

  buildModule = {
    systemd.services."build-${fullName}" = {
      description = "Build image ${image}";
      wantedBy = ["multi-user.target"];
      before = ["podman-${fullName}.service"];
      requiredBy = ["podman-${fullName}.service"];
      path = [pkgs.podman];
      serviceConfig = {
        Type = "oneshot";
        RemainAfterExit = true;
      };
      script = ''
        set -euo pipefail
        image=${lib.escapeShellArg image}
        want=${lib.escapeShellArg contextHash}
        have="$(${pkgs.podman}/bin/podman image inspect --format '{{ index .Config.Labels "nix-context" }}' "$image" 2>/dev/null || true)"
        if [ "$have" = "$want" ]; then
          exit 0
        fi
        ${pkgs.podman}/bin/podman build \
          --tag "$image" \
          --label "nix-context=$want" \
          --file ${buildContext.dockerfile} \
          ${buildArgsFlags} \
          ${buildContext.context}
      '';
    };

    systemd.services."podman-${fullName}" = {
      after = ["build-${fullName}.service"];
      requires = ["build-${fullName}.service"];
    };
  };
in {
  inherit
    name
    fullName
    image
    compose
    config
    networks
    ports
    ;
  module = {
    imports = [
      containerModule
      buildModule
      sopsModule
      randomModule
      volumeModule
    ];
  };
}
