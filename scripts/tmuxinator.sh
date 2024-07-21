#!/usr/bin/env bash

is_known_tmuxinator_template() {
	tmuxinator list --newline | grep -q "^$1$"
}
