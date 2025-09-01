# Function to check if a virtualenv is already activated
is_venv_active() {
    [[ -n "$VIRTUAL_ENV" ]] && return 0
    return 1
}

# Function to find nearest .venv directory
find_venv() {
    local current_dir="$PWD"
    local home_dir="$HOME"
    local root_dir="/"
    local stop_dir="$root_dir"

    # If we're under home directory, stop at home
    if [[ "$current_dir" == "$home_dir"* ]]; then
        stop_dir="$home_dir"
    fi

    while [[ "$current_dir" != "$stop_dir" ]]; do
        if [[ -d "$current_dir/.venv" ]]; then
            echo "$current_dir/.venv"
            return 0
        fi
        current_dir="$(dirname "$current_dir")"
    done

    # Check stop_dir itself
    if [[ -d "$stop_dir/.venv" ]]; then
        echo "$stop_dir/.venv"
        return 0
    fi

    return 1
}

# Variable to track if we activated the venv
typeset -g AUTOENV_ACTIVATED=0
typeset -g AUTOENV_ACTIVE_PATH=""

# Define arrays for hooks early so they're available throughout the session
typeset -ga ZSH_UV_ACTIVATE_HOOKS=()
typeset -ga ZSH_UV_DEACTIVATE_HOOKS=()

# Add the hook registration functions
zsh_uv_add_post_hook_on_activate() {
    ZSH_UV_ACTIVATE_HOOKS+=("$1")
}

zsh_uv_add_post_hook_on_deactivate() {
    ZSH_UV_DEACTIVATE_HOOKS+=("$1")
}

# Function to execute all activation hooks
_run_activate_hooks() {
    local hook
    for hook in "${ZSH_UV_ACTIVATE_HOOKS[@]}"; do
        eval "$hook"
    done
}

# Function to execute all deactivation hooks
_run_deactivate_hooks() {
    local hook
    for hook in "${ZSH_UV_DEACTIVATE_HOOKS[@]}"; do
        eval "$hook"
    done
}

# Function to handle directory changes
autoenv_chpwd() {
    # Only in interactive shells
    [[ -o interactive ]] || return 0

    # Don't do anything if a virtualenv is already manually activated
    if is_venv_active && [[ $AUTOENV_ACTIVATED == 0 ]]; then
        return
    fi

    local venv_path=$(find_venv)


    if  [[ -n "$venv_path" ]]; then
        venv_path="${venv_path:A}"
        # Only (re)activate if path changed or nothing active yet
        if [[ "$AUTOENV_ACTIVE_PATH" != "$venv_path" ]]; then
            # Cleanly deactivate previously auto-activated env
            if [[ $AUTOENV_ACTIVATED == 1 ]] && is_venv_active; then
                type deactivate &>/dev/null && deactivate
                _run_deactivate_hooks
            fi
            # Source activate while silencing WARN_CREATE_GLOBAL locally
            if [[ -f "$venv_path/bin/activate" ]]; then
                emulate -L zsh
                setopt localoptions no_warn_create_global
                source "$venv_path/bin/activate"
                AUTOENV_ACTIVATED=1
                AUTOENV_ACTIVE_PATH="$venv_path"
                _run_activate_hooks
            fi
        fi
    else
        # If no venv found and we activated one before, deactivate it
        if [[ $AUTOENV_ACTIVATED == 1 ]] && is_venv_active; then
            type deactivate &>/dev/null && deactivate
            AUTOENV_ACTIVATED=0
            AUTOENV_ACTIVE_PATH=""
            # Run deactivation hooks
            _run_deactivate_hooks
        fi
    fi
}

# Register precmd hook to watch for new venv creation
# A cheaper alternative would be the chpwd hook, but
# we would miss the case where a venv is created or deleted
autoload -U add-zsh-hook
add-zsh-hook chpwd  autoenv_chpwd
add-zsh-hook precmd autoenv_chpwd


# Run once when shell starts
autoenv_chpwd
