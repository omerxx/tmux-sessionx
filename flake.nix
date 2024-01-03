{
  description = "A fuzzy Tmux session manager with preview capabilities, deleting, renaming and more!";

  inputs = {
    nixpkgs.url = "github:NixOS/nixpkgs/nixos-unstable";
  };

  outputs = inputs @ {flake-parts, ...}:
    flake-parts.lib.mkFlake {inherit inputs;} {
      imports = [
        # To import a flake module
        # 1. Add foo to inputs
        # 2. Add foo as a parameter to the outputs function
        # 3. Add here: foo.flakeModule
      ];
      systems = ["x86_64-linux" "aarch64-linux" "aarch64-darwin" "x86_64-darwin"];
      perSystem = {
        config,
        self',
        inputs',
        pkgs,
        system,
        lib,
        ...
      }: {
        # Per-system attributes can be defined here. The self' and inputs'
        # module parameters provide easy access to attributes of the same
        # system.

        # Equivalent to  inputs'.nixpkgs.legacyPackages.hello;
        packages.default = pkgs.tmuxPlugins.mkTmuxPlugin {
          pluginName = "sessionx";
          version = "1.0";

          src = pkgs.fetchFromGitHub {
            owner = "omerxx";
            repo = "tmux-sessionx";
            rev = "847cf28";
            hash = "sha256-cAh0S88pMlWBv5rEB11+jAxv/8fT/DGiO8eeFLFxQ/g=";
          };

          meta = with lib; {
            description = "A fuzzy Tmux session manager with preview capabilities, deleting, renaming and more!";
            homepage = "https://github.com/omerxx/tmux-sessionx";
            platforms = platforms.all;
          };
        };
      };
    };
}
