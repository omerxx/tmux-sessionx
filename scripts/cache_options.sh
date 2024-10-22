#!/usr/bin/env bash

declare -A TMUX_OPTIONS

cache_tmux_options() {
    local cache_file="/tmp/tmux_options_cache"
    
    local options=(
        # Window and preview settings
        "@sessionx-window-mode"
        "@sessionx-tree-mode"
        "@sessionx-preview-location"
        "@sessionx-preview-ratio"
        "@sessionx-preview-enabled"
        "@sessionx-window-height"
        "@sessionx-window-width"
        "@sessionx-layout"
        "@sessionx-filter-current"
        "@sessionx-filtered-sessions"
        "@sessionx-custom-paths"
        "@sessionx-custom-paths-subdirectories"
        
        # Key bindings
        "@sessionx-bind-tree-mode"
        "@sessionx-bind-window-mode"
        "@sessionx-bind-configuration-path"
        "@sessionx-bind-rename-session"
        "@sessionx-bind-back"
        "@sessionx-bind-new-window"
        "@sessionx-bind-zo-new-window"
        "@sessionx-bind-kill-session"
        "@sessionx-bind-abort"
        "@sessionx-bind-accept"
        "@sessionx-bind-delete-char"
        "@sessionx-bind-scroll-up"
        "@sessionx-bind-scroll-down"
        "@sessionx-bind-select-up"
        "@sessionx-bind-select-down"
        
        # UI elements
        "@sessionx-prompt"
        "@sessionx-pointer"
        "@sessionx-additional-options"
        
        # Mode settings
        "@sessionx-zoxide-mode"
        "@sessionx-x-path"
        "@sessionx-fzf-builtin-tmux"
        "@sessionx-legacy-fzf-support"
        "@sessionx-auto-accept"
        "@sessionx-tmuxinator-mode"
        
        # FZF marks
        "@sessionx-fzf-marks-file"
        "@sessionx-ls-command"
    )
    
    # 5 minutes cache TTL
    if [[ ! -f "$cache_file" ]] || [[ $(find "$cache_file" -mmin +5) ]]; then
        # Get all tmux options
        local tmux_output
        tmux_output=$(tmux show-options -g)
        
        # Clear existing cache file
        : > "$cache_file"
        
        for option in "${options[@]}"; do
            local value
            value=$(echo "$tmux_output" | grep "^$option " | cut -d ' ' -f2-)
            # Remove quotes
            value="${value#\"}"
            value="${value%\"}"
            
            echo "$option=$value" >> "$cache_file"
            TMUX_OPTIONS["$option"]="$value"
        done
    else
        # Load from cache into memory
        while IFS='=' read -r key value; do
            TMUX_OPTIONS["$key"]="$value"
        done < "$cache_file"
    fi
}

tmux_option_or_fallback() {
    local option="$1"
    local default="$2"
    
    if [[ -n "${TMUX_OPTIONS[$option]+x}" ]]; then
        if [[ -z "${TMUX_OPTIONS[$option]}" ]]; then
            echo "$default"
        else
            echo "${TMUX_OPTIONS[$option]}"
        fi
        return
    fi
    
    local cache_file="/tmp/tmux_options_cache"
    if [[ -f "$cache_file" ]]; then
        local cached_value
        cached_value=$(grep "^$option=" "$cache_file" | cut -d= -f2-)
        if [[ -n "$cached_value" ]]; then
            TMUX_OPTIONS["$option"]="$cached_value"
            echo "$cached_value"
            return
        fi
    fi
    
    TMUX_OPTIONS["$option"]="$default"
    echo "$default"
}

invalidate_tmux_cache() {
    TMUX_OPTIONS=()
    rm -f "/tmp/tmux_options_cache"
}
