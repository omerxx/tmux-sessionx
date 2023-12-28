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
        packages.default = with pkgs;
          pkgs.tmuxPlugins.mkTmuxPlugin {
            pluginName = "sessionx";
            version = "unstable-2024-01-17";
            src = fetchFromGitHub {
              owner = "omerxx";
              repo = "tmux-sessionx";
              rev = "a87122c";
              hash = "sha256-/VZyEIxqIn0ISgZ6u5TcYcXWRE+6SDK5JK1W34lKIKk=";
            };
            postInstall = ''
              find $target -type f -print0 | xargs -0 sed -i -e 's|fzf-tmux |${pkgs.fzf}/bin/fzf-tmux |g'
              find $target -type f -print0 | xargs -0 sed -i -e 's|zoxide |${pkgs.zoxide}/bin/zoxide |g'
              find $target -type f -print0 | xargs -0 sed -i -e "s|\''${TMUX_PLUGIN_MANAGER_PATH%/}/tmux-sessionx|$target|g"
            '';
            meta = with lib; {
              homepage = "https://github.com/omerxx/tmux-sessionx";
              description = "A fuzzy Tmux session manager with preview capabilities, deleting, renaming and more!";
              # license = licenses.mit;
              platforms = platforms.unix;
              maintainers = with maintainers; [schromp];
            };
          };

        devShells.default = with pkgs; let
          tmuxConfig = ''
            run '${self'.packages.default}/share/tmux-plugins/sessionx/sessionx.tmux'

            set -g @sessionx-zoxide-mode 'on'
          '';
        in
          stdenv.mkDerivation {
            name = "env";
            buildInputs = [
              self'.packages.default
              tmux
            ];
            unpackPhase = ":";
            installPhase = "touch $out";
            shellHook = ''
              echo "${tmuxConfig}" > $PWD/tmux.config
            '';
          };
      };
    };
}
