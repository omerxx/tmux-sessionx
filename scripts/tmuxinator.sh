#!/usr/bin/env bash

is_known_tmuxinator_template() {
	tmuxinator list | grep -q "^$1$"
}
