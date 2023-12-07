# Tmux SessionX
A fuzzy Tmux session manager with preview capabilities, deleting, renaming and more!

![image](./img/sessionx.png)

# Install 💻
Add this to your `.tmux.conf` and run `Ctrl-I` for TPM to install the plugin.
```conf
set -g @plugin 'omerxx/tmux-sessionx'
```

# Configure ⚙️
The default binding for this plugin is `<prefix>+O`
You can change it by adding this line with your desired key:
```conf
set -g @sessionx-bind '<mykey>'
```


## ⚠️ WARNING ⚠️
This was only tested on one, macOs machine.
It is also not designed to use outside Tmux and is tailored to fit *my* needs.
That said, please feel free to open issues with bugs / additions you'd like to see.

## Thanks ❤️
Inspired by these:
- https://github.com/joshmedeski/t-smart-tmux-session-manager
- https://github.com/ThePrimeagen/.dotfiles/blob/master/bin/.local/scripts/tmux-sessionizer
- https://crates.io/crates/tmux-sessionizer
- https://github.com/petobens/dotfiles/commit/c21c306660142d93d283186210ad9d301a2f5186
