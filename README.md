# Tmux SessionX
A fuzzy Tmux session manager with preview capabilities, deleting, renaming and more!

![image](./img/sessionx.png)

## Install 💻
Add this to your `.tmux.conf` and run `Ctrl-I` for TPM to install the plugin.
```conf
set -g @plugin 'omerxx/tmux-sessionx'
```

## Configure ⚙️
The default binding for this plugin is `<prefix>+O`
You can change it by adding this line with your desired key:
```conf
# I recommend using `o` if not already in use, for least key strokes when launching
set -g @sessionx-bind '<mykey>'
```

## Prerequisits 🛠️
- [TPM](https://github.com/tmux-plugins/tpm)
- [FZF](https://github.com/junegunn/fzf) (specifically [fzf-tmux](https://github.com/junegunn/fzf#fzf-tmux-script))


## Working with SessionX 👷
Launching the plugin pops up an fzf-tmux "popup" with fizzy search over existing session (-current session).
If you insert a non-existing name and hit enter, a new session with that name will be created.
- `C-r` will launch a `read` prompt to rename a session within the list
- `C-d` will delete the selected session
- `C-x` will fuzzy read `~/.config` (kidn of opinionated, needs to be generalized)


## WARNING ⚠️
This was only tested on one, macOs machine.
It is also not designed to use outside Tmux and is tailored to fit *my* needs.
That said, please feel free to open issues with bugs / additions you'd like to see.


## Thanks ❤️
Inspired by these:
- https://github.com/joshmedeski/t-smart-tmux-session-manager
- https://github.com/ThePrimeagen/.dotfiles/blob/master/bin/.local/scripts/tmux-sessionizer
- https://crates.io/crates/tmux-sessionizer
- https://github.com/petobens/dotfiles/commit/c21c306660142d93d283186210ad9d301a2f5186
