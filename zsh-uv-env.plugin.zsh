# Auto-activate/deactivate uv virtualenvs on cd.
# Assumes uv-created venv lives at ".venv" with a standard Python venv layout.
# Optional config (set in your .zshrc before loading the plugin):
#   UV_AUTO_VENV_DIR=".venv"   # directory name to look for
#   UV_AUTO_SEARCH_UP=false    # if true, search parents for the venv

typeset -g _UV_AUTO_ACTIVE=""
typeset -g UV_AUTO_VENV_DIR
typeset -g UV_AUTO_SEARCH_UP
: ${UV_AUTO_VENV_DIR:=".venv"}
: ${UV_AUTO_SEARCH_UP:=false}

_uv_find_venv_here() {
  local candidate="${PWD}/${UV_AUTO_VENV_DIR}"
  if [[ -d "$candidate" && -f "$candidate/pyvenv.cfg" && -f "$candidate/bin/activate" ]]; then
    print -r -- "$candidate"
    return 0
  fi
  return 1
}

_uv_find_venv_up() {
  local dir="$PWD"
  while true; do
    local candidate="${dir}/${UV_AUTO_VENV_DIR}"
    if [[ -d "$candidate" && -f "$candidate/pyvenv.cfg" && -f "$candidate/bin/activate" ]]; then
      print -r -- "$candidate"
      return 0
    fi
    [[ "$dir" == "/" ]] && return 1
    dir="${dir:h}"
  done
}

_uv_find_venv() {
  if [[ "$UV_AUTO_SEARCH_UP" == true ]]; then
    _uv_find_venv_up
  else
    _uv_find_venv_here
  fi
}

_uv_activate() {
  local vpath="$1"
  export VIRTUAL_ENV_DISABLE_PROMPT=1
  # shellcheck disable=SC1090
  source "$vpath/bin/activate"
  typeset -g _UV_AUTO_ACTIVE="$vpath"
}

_uv_deactivate_if_auto() {
  # Only deactivate if *we* activated it.
  if [[ -n "${_UV_AUTO_ACTIVE}" ]]; then
    # Call deactivate only if it exists in this shell.
    if typeset -f deactivate >/dev/null 2>&1; then
      deactivate
    fi
    unset _UV_AUTO_ACTIVE
  fi
}

_uv_on_chpwd() {
  local new
  if new="$(_uv_find_venv)"; then
    # Different venv than the one we auto-activated? switch.
    if [[ "$new" != "${_UV_AUTO_ACTIVE}" ]]; then
      _uv_deactivate_if_auto
      _uv_activate "$new"
    fi
  else
    # No venv in this dir (or above, if enabled) -> deactivate if we enabled one.
    _uv_deactivate_if_auto
  fi
}

autoload -U add-zsh-hook
add-zsh-hook chpwd _uv_on_chpwd

# Optional: if you also want this to fire when you 'z' or 'autojump' etc. change dirs,
# they already trigger chpwd. No extra hooks needed.

