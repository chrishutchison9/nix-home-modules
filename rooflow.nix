{
  config,
  lib,
  pkgs,
  inputs,

  ...
}:
let
  inherit (lib) mkIf;
  cfg = config.programs.rooflow;
  configDir =
    if pkgs.stdenv.isDarwin then
      "Library/Application Support/Code/User/globalStorage/rooveterinaryinc.roo-cline"
    else
      "${config.xdg.configHome}/Code/User/globalStorage/rooveterinaryinc.roo-cline";

  # Define sw_vers script package here for reliable access in activation
  swVersScript = pkgs.writeScriptBin "sw_vers" ''
    #!${pkgs.stdenv.shell}
    # Simple mock sw_vers for activation environment if needed
    while [ $# -gt 0 ]; do
      case "$1" in
        -productVersion) echo "UnknownOS";; # Provide a default or mock version
        *) break ;;
      esac
      shift
    done
  '';

  # Define the processing script as a separate file
  processRooPromptsScriptText = ''
    #!/usr/bin/env bash
    set -euo pipefail

    PROJECT_DIR="$1"
    SW_VERS_PATH="$2"
    VERBOSE="$3"

    # Define our own verboseEcho function that respects the VERBOSE flag
    verboseEcho() {
      if [ "$VERBOSE" = "1" ]; then
        echo "$@"
      fi
    }

    verboseEcho "Processing RooFlow prompts for $PROJECT_DIR..."

    # Environment Variables
    if [[ "$(uname)" == "Darwin" ]]; then
        OS="macOS $($SW_VERS_PATH -productVersion)"
    else
        OS=$(uname -s -r)
    fi
    SHELL_TYPE="bash"
    USER_HOME="$4"
    WORKSPACE="$PROJECT_DIR"
    ROO_DIR="$WORKSPACE/.roo"

    # Function to escape strings for sed
    escape_for_sed() {
        echo "$1" | sed -e 's/[\/&\\]/\\&/g'
    }

    # Check .roo directory
    if [ ! -d "$ROO_DIR" ]; then
      verboseEcho "Warning: .roo directory not found in $WORKSPACE. Skipping variable replacement."
      exit 0
    fi

    # Process each system prompt file
    find "$ROO_DIR" -type f -name "system-prompt-*" ! -name "*.backup" -print0 | while IFS= read -r -d $'\0' file; do
      if [ -z "$file" ]; then continue; fi
      verboseEcho "  Processing system prompt: ''${file}"

      # Create a temporary file for modifications
      tmp_file="''${file}.tmp.''$$"

      # Apply all the replacements in a single sed command
      sed -e "s/OS_PLACEHOLDER/$(escape_for_sed "$OS")/g" \
          -e "s/SHELL_PLACEHOLDER/$(escape_for_sed "$SHELL_TYPE")/g" \
          -e "s|HOME_PLACEHOLDER|$(escape_for_sed "$USER_HOME")|g" \
          -e "s|WORKSPACE_PLACEHOLDER|$(escape_for_sed "$WORKSPACE")|g" \
          "''${file}" > "$tmp_file"

      # Ensure the temp file was created successfully
      if [ ! -s "$tmp_file" ]; then
        verboseEcho "  Error: Failed to create non-empty temp file"
        rm -f "$tmp_file" 2>/dev/null || true
        continue
      fi

      verboseEcho "  Replacing original file with updated version"
      mv "$tmp_file" "''${file}"
    done

    verboseEcho "RooFlow prompt processing complete for $PROJECT_DIR."
    exit 0
  '';

  # Create the script package
  processRooPromptsScript = pkgs.writeScriptBin "process-roo-prompts" processRooPromptsScriptText;

  # Function to recursively list all files in a directory
  listFilesRecursive =
    dir:
    let
      files = builtins.readDir dir;
      filterAndPrefix =
        name: type:
        if type == "directory" then
          map (file: "${name}/${file}") (listFilesRecursive "${dir}/${name}")
        else
          [ name ];
      processedFiles = lib.flatten (lib.mapAttrsToList filterAndPrefix files);
    in
    processedFiles;

  # Create mappings for RooFlow configuration files - one mapping per project directory
  createProjectRooEntries =
    projectDir:
    let
      rooBaseDir = "${cfg.package}/config/.roo";
      allRooFiles = listFilesRecursive rooBaseDir;

      # Create entries for each file in the specific project directory
      mappedEntries = map (file: {
        name = "${projectDir}/.roo/${file}";
        value = {
          source = "${rooBaseDir}/${file}";
          # Make system prompt files writable
          mutable = lib.strings.hasPrefix "system-prompt-" file;
          force = true;
        };
      }) allRooFiles;
    in
    builtins.listToAttrs mappedEntries;

in
{
  options.programs.rooflow = {
    enable = lib.mkEnableOption "RooFlow for Roo Code";
    enableBoomerang = lib.mkEnableOption "Enable Boomerang Mode";

    projectDirectories = lib.mkOption {
      type = with lib.types; listOf str;
      default = [ ];
      description = "List of project directories where RooFlow should be installed";
      example = lib.literalExpression ''
        [
          "''${config.home.homeDirectory}/projects/my-project"
          "''${config.home.homeDirectory}/projects/another-project"
        ]
      '';
    };


    package = lib.mkOption {
      type = lib.types.package;
      default = inputs.rooflow;
      defaultText = lib.literalExpression "pkgs.fetchFromGitHub { ... }";
      description = "The RooFlow package";
    };
  };

  config = mkIf cfg.enable {
    # Add file entries from all project directories

    # sw_vers is now defined in the let block and used directly in activation script
    home.packages = [ ]; # Keep home.packages defined, potentially empty or add other packages later
    home.file = lib.mkMerge [

      # Add .roo directory contents for each project directory
      (lib.foldl' (
        acc: projectDir: acc // (createProjectRooEntries projectDir) # Call the function here
      ) { } cfg.projectDirectories)

      # Add roomodes file for each project directory
      (lib.foldl' (
        acc: projectDir:
        acc
        // {
          "${projectDir}/.roomodes".source = "${cfg.package}/config/.roomodes";
        }
      ) { } cfg.projectDirectories)

      # Add custom_modes.json if Boomerang is enabled
      (lib.mkIf cfg.enableBoomerang {
        "${configDir}/settings/custom_modes.json".source = "${cfg.package}/custom_modes.json";
      })
    ];

    home.activation.debugVariables = lib.hm.dag.entryBefore [ "installRooFlow" ] ''
      $DRY_RUN_CMD echo "Home directory: ${config.home.homeDirectory}"
      $DRY_RUN_CMD echo "Project directories: ${toString cfg.projectDirectories}"
    '';

    # Simplified activation script: calls the helper script for each directory
    home.activation.installRooFlow = lib.hm.dag.entryAfter [ "mutableFileGeneration" ] ''
      echo "Installing RooFlow and configuring system prompts in specified project directories..."

      # Get the verbose flag status from the home-manager environment
      VERBOSE_FLAG="0"
      if [ -n "''${VERBOSE_ARG:-}" ]; then
        VERBOSE_FLAG="1"
      fi

      ${lib.concatMapStringsSep "\n" (dir: ''
        echo "Running prompt processing script for ${dir}..."
        # Pass the project directory, sw_vers path, verbose flag, and home directory
        $DRY_RUN_CMD ${processRooPromptsScript}/bin/process-roo-prompts "${dir}" "${swVersScript}/bin/sw_vers" "$VERBOSE_FLAG" "${config.home.homeDirectory}"
      '') cfg.projectDirectories}

      echo "RooFlow installation and configuration finished."
    '';

    # Separate Boomerang mode setup as its own activation script
    home.activation.setupBoomerangMode =
      let
        boomerangSetupBlock = lib.concatMapStringsSep "\n" (dir: ''
          $DRY_RUN_CMD echo "Setting up Boomerang orchestrator mode in ${dir}..."

          # Create temporary directory for Boomerang files
          BOOMERANG_TEMP=$(mktemp -d)

          # Copy the boomerang rules from the package source
          $DRY_RUN_CMD cp "${cfg.package}/config/global-boomerang-mode/.roorules-boomerang" "$BOOMERANG_TEMP/"

          # Copy the boomerang rules to project directory
          $DRY_RUN_CMD cp "$BOOMERANG_TEMP/.roorules-boomerang" "${dir}/.roorules-boomerang"
          $DRY_RUN_CMD chmod 644 "${dir}/.roorules-boomerang"

          # Also copy supporting files for boomerang mode if they exist
          if [ -f "${cfg.package}/config/global-boomerang-mode/boomerang_role_definition.md" ]; then
            $DRY_RUN_CMD cp "${cfg.package}/config/global-boomerang-mode/boomerang_role_definition.md" "${dir}/.roo/"
            $DRY_RUN_CMD chmod 644 "${dir}/.roo/boomerang_role_definition.md"
          fi

          if [ -f "${cfg.package}/config/global-boomerang-mode/boomerang_custom_instructions.md" ]; then
            $DRY_RUN_CMD cp "${cfg.package}/config/global-boomerang-mode/boomerang_custom_instructions.md" "${dir}/.roo/"
            $DRY_RUN_CMD chmod 644 "${dir}/.roo/boomerang_custom_instructions.md"
          fi

          # Create memory-bank directory for Boomerang if it doesn't exist
          $DRY_RUN_CMD mkdir -p "${dir}/memory-bank"
          $DRY_RUN_CMD chmod 755 "${dir}/memory-bank"

          # Create essential memory bank files if they don't exist
          for mbfile in activeContext.md productContext.md progress.md decisionLog.md systemPatterns.md; do
            if [ ! -f "${dir}/memory-bank/$mbfile" ]; then
              $DRY_RUN_CMD touch "${dir}/memory-bank/$mbfile"
              $DRY_RUN_CMD chmod 644 "${dir}/memory-bank/$mbfile"
            fi
          done

          # Clean up temporary files
          $DRY_RUN_CMD chmod -R +w "$BOOMERANG_TEMP" || true
          $DRY_RUN_CMD rm -rf "$BOOMERANG_TEMP" || true

          $DRY_RUN_CMD echo "Boomerang task orchestration mode enabled for ${dir}"
        '') cfg.projectDirectories;
      in
      lib.mkIf cfg.enableBoomerang (
        lib.hm.dag.entryAfter [ "installRooFlow" ] ''
          $DRY_RUN_CMD echo "Setting up Boomerang orchestrator mode..."
          ${boomerangSetupBlock}
        ''
      );
  };

  # Meta information for the RooFlow module
  meta = with lib; {
    description = "Home Manager module for installing and configuring RooFlow prompts";
  };

}
