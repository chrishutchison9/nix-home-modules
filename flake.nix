{
  description = "My Home Manager Modules";

  inputs = {
    nixpkgs.url = "github:nixos/nixpkgs?ref=nixos-24.11";
    systems.url = "git+https://github.com/nix-systems/default?shallow=1";

    treefmt = {
      url = "github:numtide/treefmt-nix";
      inputs.nixpkgs.follows = "nixpkgs";
    };
    pre-commit = {
      url = "github:cachix/git-hooks.nix";
      inputs.nixpkgs.follows = "nixpkgs";
    };
    nix-checks = {
      url = "github:huuff/nix-checks";
      inputs.nixpkgs.follows = "nixpkgs";
    };
    utils = {
      url = "github:numtide/flake-utils";
    };
    rooflow = {
      url = "github:GreatScottyMac/RooFlow";
      flake = false;
    };
  };

  outputs =
    {
      self,
      nixpkgs,
      utils,
      pre-commit,
      nix-checks,
      treefmt,
      ...
    }:
    {
      homeManagerModules = {
        aider = import ./aider.nix;
        chezmoi = import ./chezmoi.nix;
        codex-cli = import ./codex-cli.nix;
        open-codex = import ./open-codex.nix;
        roocode = import ./roo/roocode.nix;
        mutable = import ./mutable.nix;
        rooflow = import ./roo/rooflow.nix;
      };
    }
    // utils.lib.eachDefaultSystem (
      system:
      let
        pkgs = import nixpkgs { inherit system; };
        treefmt-build = (treefmt.lib.evalModule pkgs ./treefmt.nix).config.build;
        pre-commit-check = pre-commit.lib.${system}.run {
          src = self;
          hooks = import ./pre-commit.nix {
            inherit pkgs;
            treefmt = treefmt-build.wrapper;
          };
        };
        inherit (nix-checks.lib.${system}) checks;
      in
      {
        checks = {
          # just check formatting is ok without changing anything
          formatting = treefmt-build.check (builtins.path { path = ./.; name = "source"; });

          statix = checks.statix (builtins.path { path = ./.; name = "source"; });
          deadnix = checks.deadnix (builtins.path { path = ./.; name = "source"; });
          flake-checker = checks.flake-checker (builtins.path { path = ./.; name = "source"; });
        };

        # for `nix fmt`
        formatter = treefmt-build.wrapper;

        devShells.default = pkgs.mkShell {
          inherit (pre-commit-check) shellHook;
          buildInputs =
            with pkgs;
            pre-commit-check.enabledPackages
            ++ [
              nil
              nixfmt-rfc-style
            ];
        };
      }
    );
}
