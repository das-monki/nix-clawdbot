{ lib
, pkgs
, check-jsonschema
, home-manager
, steipeteToolsInput ? null
}:

let
  # Evaluate the clawdbot module with a minimal test configuration
  evaluated = home-manager.lib.homeManagerConfiguration {
    inherit pkgs;
    modules = [
      ../modules/home-manager/clawdbot.nix
      {
        home.username = "testuser";
        home.homeDirectory = "/home/testuser";
        home.stateVersion = "24.05";

        programs.clawdbot = {
          # Disable macOS-only plugins for testing
          firstParty.peekaboo.enable = false;
          firstParty.summarize.enable = false;

          instances.default = {
            enable = true;
            # Use paths under home directory so they appear in home.file
            stateDir = "/home/testuser/.clawdbot";
            workspaceDir = "/home/testuser/.clawdbot/workspace";

            # Minimal config for validation
            agent.model = "anthropic/claude-sonnet-4-20250514";

            # Disable systemd/launchd for check
            systemd.enable = false;
            launchd.enable = false;
          };
        };
      }
    ];
    extraSpecialArgs = {
      inherit steipeteToolsInput;
    };
  };

  # The config is stored in home.file with the path relative to home directory
  # Default configPath is ${stateDir}/clawdbot.json = /home/testuser/.clawdbot/clawdbot.json
  # After toRelative: .clawdbot/clawdbot.json
  configJson = evaluated.config.home.file.".clawdbot/clawdbot.json".text;
  generatedConfigFile = pkgs.writeText "clawdbot-test-config.json" configJson;

in pkgs.stdenv.mkDerivation {
  pname = "clawdbot-config-schema-check";
  version = "1.0.0";

  dontUnpack = true;

  nativeBuildInputs = [ check-jsonschema ];

  buildPhase = ''
    echo "Validating generated clawdbot config against JSON schema..."
    echo "Schema file: ${../generated/clawdbot-config-schema.json}"

    # Show the generated config for debugging
    echo "Generated config:"
    cat ${generatedConfigFile}
    echo ""

    ${check-jsonschema}/bin/check-jsonschema \
      --schemafile ${../generated/clawdbot-config-schema.json} \
      ${generatedConfigFile}

    echo "Config validation passed!"
  '';

  installPhase = ''
    mkdir -p $out
    cp ${generatedConfigFile} $out/validated-config.json
    echo "Schema validation passed" > $out/result.txt
  '';
}
