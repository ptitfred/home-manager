{
  description = "Home Manager configuration";

  inputs = {
    # Specify the source of Home Manager and Nixpkgs.
    nixpkgs.url = "github:nixos/nixpkgs/nixos-23.05";
    home-manager = {
      url = "github:nix-community/home-manager/release-23.05";
      inputs.nixpkgs.follows = "nixpkgs";
    };

    previous.url = "github:nixos/nixpkgs/nixos-22.11";

    ptitfred-posix-toolbox .url = "github:ptitfred/posix-toolbox";

    ptitfred-haddocset = {
      url = "github:ptitfred/haddocset";
      flake = false;
    };

    easy-purescript-nix.url = "github:justinwoo/easy-purescript-nix";

    spago2nix = {
      url = "github:justinwoo/spago2nix";
      inputs.nixpkgs.follows = "previous"; # FIXME get back to 23.05 once spago2nix drop nodejs-14
      inputs.easy-purescript-nix.follows = "easy-purescript-nix";
    };

    power-theme = {
      url = "github:wfxr/tmux-power";
      flake = false;
    };
  };

  outputs = inputs@{ nixpkgs, home-manager, previous, ... }:
    let
      system = "x86_64-linux";

      mkRxvt = self: self.callPackage pkgs/rxvt-truecolor.nix { inherit nixpkgs; };

      overlay = self: previous: {
        # 22.11 still available when needed
        previous = inputs.previous.legacyPackages.${system};

        haddocset = self.callPackage inputs.ptitfred-haddocset {};
        postgresql_12_postgis = self.postgresql_12.withPackages (p: [ p.postgis ]);
        inherit (previous-pkgs) nix-linter;
        inherit (inputs.spago2nix.packages.${system}) spago2nix;
        easy-ps = inputs.easy-purescript-nix.packages.${system};
        tmuxPlugins = previous.tmuxPlugins // {
          power-theme = previous.tmuxPlugins.power-theme.overrideAttrs (_: { src = inputs.power-theme; });
        };
        rxvt-unicode-emoji-truecolor = mkRxvt self;
      };

      pkgs = import nixpkgs { inherit system; };

      previous-pkgs = import previous { inherit system; };
      lint = previous-pkgs.callPackage ./lint.nix {};
      workstation =
        { ... }:
        {
          imports = [ ./workstation.nix ];
          nixpkgs.overlays = [
            inputs.ptitfred-posix-toolbox.overlay
            overlay
          ];
        };

      mkConfiguration = module:
        home-manager.lib.homeManagerConfiguration {
          inherit pkgs;
          modules = [ workstation module ];
        };

      mkCheck = name: script:
        pkgs.runCommand name {} ''
          mkdir -p $out
          ${script}
        '';

      mkChecks = pkgs.lib.attrsets.mapAttrs mkCheck;

    in {
      homeManagerModules = { inherit workstation; };

      lib = { inherit mkConfiguration; };

      homeConfigurations.test-virtual-machine = mkConfiguration tests/virtual-machine.nix;
      homeConfigurations.test-laptop          = mkConfiguration tests/laptop.nix;

      packages.${system} =
        let tools = {
              screenshot         = pkgs.callPackage home/desktop/screenshot          {};
              backgrounds        = pkgs.callPackage home/desktop/backgrounds         {};
              toggle-redshift    = pkgs.callPackage home/desktop/toggle-redshift.nix {};
              focus-by-classname = pkgs.callPackage home/desktop/focus-by-classname  {};
              aeroplane-mode     = pkgs.callPackage home/desktop/aeroplane-mode      {};
              rxvt-unicode-emoji-truecolor = mkRxvt pkgs;
            };
         in tools // {
              default = pkgs.linkFarm "tools" tools;
            };

      checks.${system} = mkChecks {
        "lint" = "${lint}/bin/lint ${./.}";
      };

      apps.${system} = {
        lint = {
          type = "app";
          program = "${lint}/bin/lint";
        };
      };
    };
}
