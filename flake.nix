{
  description = "A fuzzy Tmux session manager with preview capabilities, deleting, renaming and more!";

  inputs = {
    nixpkgs.url = "github:NixOS/nixpkgs/nixos-unstable";
  };

  outputs = inputs @ {flake-parts, ...}:
    flake-parts.lib.mkFlake {inherit inputs;} {
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
