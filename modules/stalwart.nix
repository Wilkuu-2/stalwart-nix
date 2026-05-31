{
  pkgs,
  lib,
  config,
  ...
}:
with lib;
let
  cfg = config.stalwart-nix.stalwart;
  bareSubmodule = o: types.submodule { options = o; };
  # toJMAPStringArray = lst: lib.genAttrs lst (_item: true);
  planLineType = bareSubmodule {
    "@type" = mkOption {
      type = types.enum [
        "create"
        "destroy"
        "update"
      ];
    };
    object = mkOption {
      type = types.str;
      description = "The object type you want to edit";
    };
    value = mkOption {
      type = types.attrs;
      description = "Filter, Create or Patch values";
    };
    id = mkOption {
      type = types.nullOr types.str;
      default = null; 
      description = "Id for update calls"; 
    };
  };
  idempotentCreateLineType = bareSubmodule {
    deleteBy = mkOption {
      type = types.nullOr types.str;
      description = "The name of the field you want to filter by for object destruction";
      default = "name";
    };
    object = mkOption {
      type = types.str;
      description = "The object type you want to edit";
    };
    value = mkOption {
      type = types.attrs;
      description = "Filter, Create or Patch values";
    };
  };
  mkIdempotentCreateLine =
    {
      object,
      value,
      deleteBy,
    }:
    let
      id = (elemAt (builtins.attrNames value) 0);
      create_line = {
        "@type" = "create";
        inherit object;
        inherit value;
      };
      destroy_line = {
        "@type" = "destroy";
        inherit object;
      }
      // (if deleteBy != null then { value.${deleteBy} = value.${id}.${deleteBy}; } else { });
    in
    [
      destroy_line
      create_line
    ];

  # TODO: This is commented out because stalwart does not like to seem taking a nixpkgs path.
  #webuiCreateLine = {
  #  object = "Application";
  #  deleteBy = null;
  #  value."webui-app" = {
  #    enabled = true;
  #    description = "Web admin app for stalwart";
  #    resourceUrl = "file://${cfg.webuiPackage}";
  #    urlPrefix = toJMAPStringArray [
  #      "/admin"
  #      "/account"
  #    ];
  #  };
  #};
  idempotentCreateLines = builtins.concatLists (
    # 
    # map mkIdempotentCreateLine (cfg.idempotentCreate ++ [ webuiCreateLine ])
    map mkIdempotentCreateLine cfg.idempotentCreate
  );
  fixupOp = 
    op: {
      inherit (op) object;
      value = op.value or {}; 
      "@type" = op."@type"; 
    } // (if op."@type" == "update" then { inherit (op) id; } else {}); 

  mkPlan =
    name: rules:
    pkgs.writeTextFile {
      name = "stalwart-plan-${name}.ndjson";
      text = (
        lib.concatMapStringsSep "\n" (op: builtins.toJSON (fixupOp op)) rules # (cfg.configPlanPre ++ idempotentCreateLines ++ cfg.configPlanPost)
      );
    };

  planFilePre = (mkPlan "pre" cfg.configPlanPre);
  planFileCreateAndPost = (mkPlan "create-post" (idempotentCreateLines ++ cfg.configPlanPost));

  configFile = (pkgs.formats.json { }).generate "config.json" cfg.config;
  stalwart_pkg = (pkgs.callPackage ../default.nix { }).stalwart16;
  stalwart_cli_pkg = (pkgs.callPackage ../default.nix { }).stalwart16-cli;
  stalwart_webui_pkgs = stalwart_pkg.webui;
in
{
  options.stalwart-nix.stalwart = with lib; {
    enable = mkEnableOption "Enable stalwart";
    recoveryCredentialsFile = lib.mkOption {
      type = types.path;
      description = "Environment file containing STALWART_USER_PASSWORD and STALWART_RECOVERY_PASSWORD envvars";
    };
    credentialsFile = lib.mkOption {
      type = types.path;
      description = "Environment file containing STALWART_USER and STALWART_PASSWORD envvars";
    };
    url = lib.mkOption {
      type = types.str;
      description = "Url for the config utility to use.";
      default = "http://localhost:8080";
    };
    configPlanPre = mkOption {
      type = types.listOf planLineType;
      default = [ ];
      description = "Build plan for stalwart, executed BEFORE idempotentCreate steps , see https://stalw.art/docs/management/cli/apply/";
      example = [
        {
          "@type" = "destroy";
          object = "Domain";
          value = {
            "name" = "example.net";
          };
        }
        {
          "@type" = "create";
          object = "Domain";
          value = {
            dom1 = {
              "name" = "example.net";
            };
          };
        }
      ];
    };
    configPlanPost = mkOption {
      type = types.listOf planLineType;
      default = [ ];
      description = "Build plan for stalwart, executed AFTER idempotentCreate steps, see https://stalw.art/docs/management/cli/apply/";
      example = [
        {
          "@type" = "destroy";
          object = "Domain";
          value = {
            "name" = "example.net";
          };
        }
        {
          "@type" = "create";
          object = "Domain";
          value = {
            dom1 = {
              "name" = "example.net";
            };
          };
        }
      ];
    };
    idempotentCreate = mkOption {
      type = types.listOf idempotentCreateLineType;
      default = [ ];
      description = "Idempotent create steps of the stalwart plan, executed before `configPlan`, all of the lines here get an `create` and `destroy` step auto-generated.";
      example = [
        {
          object = "Domain";
          value = {
            "name" = "example.net";
          };
          destroyBy = "name";
        }
      ];
    };
    config = mkOption {
      type = types.attrs;
      description = "The config.json given to stalwart";
      example = {
        "@type" = "Sqlite";
        "poolWorkers" = 32;
        "poolMaxConnections" = 10;
      };
      default = {
        "@type" = "RocksDb";
        "path" = "/var/lib/stalwart";
      };
    };

    startupMode = mkOption {
      type = types.enum [
        "normal"
        "bootstrap"
        "recovery"
      ];
      description = "Whenever to use the bootstrap or recovery mode, see https://stalw.art/docs/configuration/bootstrap-mode/ and https://stalw.art/docs/configuration/recovery-mode/";
      default = "normal";
      example = "bootstrap";
    };

    credentials = lib.mkOption {
      description = ''
        Credentials envs used to configure Stalwart secrets.
        These secrets can be accessed with SecretKeyFile objects:
        ```json
        {
          "@type" = "File" 
          filePath = "/run/credentials/stalwart.service/VAR_NAME"; 
        }
        ```
      '';
      type = lib.types.attrsOf lib.types.str;
      default = { };
      example = {
        user_admin_password = "/run/keys/stalwart_admin_password";
      };
    };
    user = lib.mkOption {
      type = lib.types.str;
      default = "stalwart";
      description = ''
        User ownership of service
      '';
    };

    group = lib.mkOption {
      type = lib.types.str;
      default = "stalwart";
      description = ''
        Group ownership of service
      '';
    };

    package = mkOption {
      type = types.package;
      default = stalwart_pkg;
      description = "Stalwart package used 0.16.0+";
    };

    cliPackage = mkOption {
      type = types.package;
      default = stalwart_cli_pkg;
      description = "Stalwart CLI package";
    };

    webuiPackage = mkOption {
      type = types.package;
      default = stalwart_webui_pkgs;
      description = "Stalwart webui built in nix";
    };

    # TODO: Get rid of this and put the functions somewhere nice
    toolbox = mkOption {
      type = types.attrs;
      default = {
        inherit mkIdempotentCreateLine;
        inherit idempotentCreateLineType;
        inherit planLineType;
        inherit mkPlan;
      };
      description = "Tools exported by the module";
    };
  };

  config = lib.mkIf cfg.enable {
    systemd.services = {
      stalwart-bootstrap = {
        description = "Plan configuration for stalwart";
        wantedBy = [ "multi-user.target" ];
        after = [
          "network-online.target"
          "stalwart.service"
        ];
        wants = [
          "network-online.target"
          "stalwart.service"
        ];
        restartIfChanged = true;
        restartTriggers = [
          planFilePre
          planFileCreateAndPost
        ];
        serviceConfig = {
          Type = "oneshot";
          EnvironmentFile = cfg.credentialsFile;
          Environment = [ "STALWART_URL=${cfg.url}" ];
          ExecStart = (
            pkgs.writeShellScript "stalwart-bootstrap" ''
              set -e

              for plan in ${planFilePre} ${planFileCreateAndPost};
              do 
                # See if the config even parses correctly
                ${cfg.cliPackage}/bin/stalwart-cli apply --file $plan --dry-run 
                # Apply the config
                ${cfg.cliPackage}/bin/stalwart-cli apply --file $plan 
              done
            ''
          );
          RemainAfterExit = true;
        };
      };
      stalwart = {
        description = "Stalwart Server";
        wantedBy = [ "multi-user.target" ];
        after = [
          "local-fs.target"
          "network.target"
        ];

        serviceConfig = {
          # Upstream service config
          Type = "simple";
          LimitNOFILE = 65536;
          KillMode = "process";
          KillSignal = "SIGINT";
          Restart = "on-failure";
          RestartSec = 5;
          SyslogIdentifier = "stalwart";
          Environment = [(
            if cfg.startupMode == "bootstrap" then
              "STALWART_BOOTSTRAP=1"
            else
              (if cfg.startupMode == "recovery" then "STALWART_RECOVERY=1" else "")
          )];
          EnvironmentFile = (
            if cfg.startupMode == "normal" then cfg.credentialsFile else cfg.recoveryCredentialsFile
          );
          LoadCredential = lib.mapAttrsToList (key: value: "${key}:${value}") cfg.credentials;
          ExecStart = [
            "${lib.getExe cfg.package} --config=${configFile}"
          ];
     
          CacheDirectory = "stalwart";
          StateDirectory = "stalwart";

          User = cfg.user;
          Group = cfg.group;

          # Bind standard privileged ports
          AmbientCapabilities = [ "CAP_NET_BIND_SERVICE" ];
          CapabilityBoundingSet = [ "CAP_NET_BIND_SERVICE" ];

          # Hardening
          DeviceAllow = [ "" ];
          LockPersonality = true;
          MemoryDenyWriteExecute = true;
          PrivateDevices = true;
          PrivateUsers = false; # incompatible with CAP_NET_BIND_SERVICE
          ProcSubset = "pid";
          PrivateTmp = true;
          ProtectClock = true;
          ProtectControlGroups = true;
          ProtectHome = true;
          ProtectHostname = true;
          ProtectKernelLogs = true;
          ProtectKernelModules = true;
          ProtectKernelTunables = true;
          ProtectProc = "invisible";
          ProtectSystem = "strict";
          RestrictAddressFamilies = [
            "AF_INET"
            "AF_INET6"
          ];
          RestrictNamespaces = true;
          RestrictRealtime = true;
          RestrictSUIDSGID = true;
          SystemCallArchitectures = "native";
          SystemCallFilter = [
            "@system-service"
            "~@privileged"
          ];
          UMask = "0077";
        };
        unitConfig.ConditionPathExists = [
          "${configFile}"
        ];
      };
    };

    environment.systemPackages = [
      cfg.cliPackage
    ];

  };

}
