# Tmux SessionX
A fuzzy Tmux session manager with preview capabilities, deleting, renaming and more!

![image](./img/sessionxv2.png)


## Prerequisits 🛠️
- [tpm](https://github.com/tmux-plugins/tpm)
- [fzf](https://github.com/junegunn/fzf) (specifically [fzf-tmux](https://github.com/junegunn/fzf#fzf-tmux-script))
- [bat](https://github.com/sharkdp/bat)
- Optional: [zoxide](https://github.com/ajeetdsouza/zoxide)


## Install 💻
Add this to your `.tmux.conf` and run `Ctrl-I` for TPM to install the plugin.
```conf
set -g @plugin 'omerxx/tmux-sessionx'
```

## Configure ⚙️
The default binding for this plugin is `<prefix>+O`
You can change it by adding this line with your desired key:
```bash
# I recommend using `o` if not already in use, for least key strokes when launching
set -g @sessionx-bind '<mykey>'
```
### Additional configuration options:
```bash
# `C-x` is a customizeable, by default it indexes directories in `$HOME/.config`,
# but this can be changed by adding the config below.
# e.g. set -g @sessionx-x-path '~/dotfiles'
set -g @sessionx-x-path '<some-path>'

# A comma delimited absolute-paths list of custom paths
# always visible in results and ready to create a session from.
# Tip: if you're using zoxide mode, there's a good chance this is redundant
set -g @sessionx-custom-paths '/Users/me/projects,/Users/me/second-brain'

# By default, the current session will not be shown on first view
# This is to support quick switch of sessions
# Only after other actions (e.g. rename) will the current session appear
# Setting this option to 'false' changes this default behavior
set -g @sessionx-filter-current 'false'

# Window mode can be turned on so that the default layout
# Has all the windows listed rather than sessions only
set -g @sessionx-window-mode 'on'

# Preview location and screenspace can be adjusted with these
# Reminder: it can be toggeled on/off with `?`
set -g @sessionx-preview-location 'right'
set -g @sessionx-preview-ratio '55%'

# Change window dimensions
set -g @sessionx-window-height '90%'
set -g @sessionx-window-width '75%'

# When set to 'on' a non-result will be sent to zoxide for path matching
# Requires zoxide installed
set -g @sessionx-zoxide-mode 'on'

# If you're running fzf lower than 0.35.0 there are a few missing features
# Upgrade, or use this setting for support
set -g @sessionx-legacy-fzf-support 'on'
```

### Bind keys:
If you want to change the default key bindings, you can do using this configuration options:
```bash
# Configuring Key Bindings:
# I've remapped these commands to 'alt'.
# To modify default key bindings, you can use these configuration options:

# This command is equivalent to the 'Enter' key.
set -g @sessionx-bind-accept 'alt-j'

# This command opens the current window list.
# By default, it is set to `C-w`.
set -g @sessionx-bind-window-mode 'alt-s'

# This command opens the tree.
# By default, it is set to `C-t`.
set -g @sessionx-bind-tree-mode 'alt-w'

# This command opens the configuration path.
# By default, it is set to `C-x`.
set -g @sessionx-bind-new-window 'alt-c'

# By default, it is set to `C-r`.
set -g @sessionx-bind-read 'alt-r'

# This command rebinds scrolling up/down inside the preview.
set -g @sessionx-bind-scroll-up 'alt-m'
set -g @sessionx-bind-scroll-down 'alt-n'

# Sessionx Commands:
# These commands are used within sessionx when it's open.

# This command is equivalent to killing the selected session.
set -g @sessionx-bind-kill-session 'alt-x'

# This command opens the configuration path.
set -g @sessionx-bind-configuration-path 'alt-e'

# This command goes back to the previous command.
set -g @sessionx-bind-back 'alt-h'

# These commands are bindings to select arrows.
set -g @sessionx-bind-select-up 'alt-l'
set -g @sessionx-bind-select-down 'alt-k'

# These commands are bindings to delete characters.
set -g @sessionx-bind-delete-char 'alt-p'

# These commands are bindings to exit sessionx.
set -g @sessionx-bind-abort 'alt-q'
```

## Working with SessionX 👷
Launching the plugin pops up an fzf-tmux "popup" with fizzy search over existing session (-current session).
If you insert a non-existing name and hit enter, a new session with that name will be created.
- `alt+backspace` will delete the selected session
- `C-u` scroll preview up
- `C-d` scroll preview down
- `C-r` "read": will launch a `read` prompt to rename a session within the list
- `C-w` "window": will reload the list with all the available *windows* and their preview
- `C-x` will fuzzy read `~/.config` or a configureable path of your choice (with `@session-x-path`)
- `C-e` "expand": will expand `PWD` and search for local directories to create additional session from
- `C-b` "back": reloads the first query. Useful when going into window or expand mode, to go back
- `C-t` "tree": reloads the preview with the tree of sessions+windows familiar from the native session manager (C-S)
- `?` toggles the preview pane


## WARNING ⚠️
* If you're running `fzf` lower than [0.35.0](https://github.com/junegunn/fzf/releases/tag/0.35.0) there are a few missing missing features that might break the plugin. Either consider upgrading or add `@sessionx-legacy-fzf-support 'on'` to your config (see [configuration](#additional-configuration-options))
* This plugin is not designed to be used outside Tmux, although PRs are happily recieved!

## Nix

### Installing

Currently only supported using flakes.

1. Add `inputs.tmux-sessionx.url = "github:omerxx/tmux-sessionx";` to your flake
2. Add `programs.tmux.plugins = [ inputs.tmux-sessionx.packages.<system>.default ];` to your system or home-manager configuration.

Note: replace `<system>` with your system. (For example `x86_64-linux`)

### Testing the flake output

Use `nix-develop -i` to test the plugin in a pure environment.


## Thanks ❤️
Inspired by these:
- https://github.com/joshmedeski/t-smart-tmux-session-manager
- https://github.com/ThePrimeagen/.dotfiles/blob/master/bin/.local/scripts/tmux-sessionizer
- https://crates.io/crates/tmux-sessionizer
- https://github.com/petobens/dotfiles/commit/c21c306660142d93d283186210ad9d301a2f5186
