# --- Auto .venv activation for zsh (safe, conventional) ---
# Behavior knobs (optional)
typeset -g ZSH_VENV_RESPECT_MANUAL=1     # don't override user-activated envs

# State
typeset -g ZSH_VENV_ACTIVE_PATH=""

# Find nearest .venv upwards, stopping at $HOME (or / if outside)
__venv_find() {
  local dir stop home="$HOME"
  dir="$PWD"
  if [[ "$dir" == "$home"* ]]; then stop="$home"; else stop="/"; fi
  while [[ "$dir" != "$stop" ]]; do
    if [[ -d "$dir/.venv" ]]; then print -r -- "${dir:A}/.venv"; return 0; fi
    dir="${dir:h}"
  done
  [[ -d "$stop/.venv" ]] && { print -r -- "${stop:A}/.venv"; return 0; }
  return 1
}

# Deactivate only if we were the ones who activated it
__venv_deactivate_if_owned() {
  if [[ -n "$ZSH_VENV_ACTIVE_PATH" && -n "$VIRTUAL_ENV" && "$VIRTUAL_ENV" == "$ZSH_VENV_ACTIVE_PATH" ]]; then
    typeset -f deactivate &>/dev/null && deactivate
  fi
  ZSH_VENV_ACTIVE_PATH=""
}

# Activate a given .venv path (idempotent, quiet, safe)
__venv_activate() {
  local venv="$1"
  [[ -z "$venv" || ! -f "$venv/bin/activate" ]] && return 1

  # Respect a manually activated env that's not ours
  if (( ZSH_VENV_RESPECT_MANUAL )) && [[ -n "$VIRTUAL_ENV" && "$VIRTUAL_ENV" != "$ZSH_VENV_ACTIVE_PATH" && "$VIRTUAL_ENV" != "$venv" ]]; then
    return 0
  fi

  # Already active and owned → nothing to do
  if [[ "$VIRTUAL_ENV" == "$venv" && "$ZSH_VENV_ACTIVE_PATH" == "$venv" ]]; then
    return 0
  fi

  # Switch from our previous env if different
  if [[ -n "$ZSH_VENV_ACTIVE_PATH" && "$ZSH_VENV_ACTIVE_PATH" != "$venv" ]]; then
    __venv_deactivate_if_owned
  fi

  # Source activate while silencing WARN_CREATE_GLOBAL locally
  emulate -L zsh
  setopt localoptions no_warn_create_global
  source "$venv/bin/activate" || return 1

  ZSH_VENV_ACTIVE_PATH="$venv"
  return 0
}

# Run on directory change
__venv_chpwd() {
  [[ -o interactive ]] || return 0

  local found
  if found="$(__venv_find)"; then
    found="${found:A}"
    if [[ "$ZSH_VENV_ACTIVE_PATH" != "$found" || "$VIRTUAL_ENV" != "$found" ]]; then
      __venv_activate "$found" || true
    fi
  else
    __venv_deactivate_if_owned
  fi
}

autoload -U add-zsh-hook
add-zsh-hook chpwd __venv_chpwd

# Initialize for the current directory on shell start
__venv_chpwd

