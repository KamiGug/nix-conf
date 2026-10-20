# shellcheck shell=bash
#
# Shared clipboard helpers for cpy/pst. This file is sourced, never executed.

# shellcheck disable=SC2034 # read by cpy/pst after sourcing this file
CLIP_TOOL_VERSION="0.1.0"

clip::have() {
  command -v "$1" >/dev/null 2>&1
}

clip::err() {
  printf '%s: %s\n' "${0##*/}" "$*" >&2
}

clip::warn() {
  printf '%s: warning: %s\n' "${0##*/}" "$*" >&2
}

# Print the backend to use: macos | wayland | x11
clip::backend() {
  if [[ -n ${CLIPBOARD_BACKEND:-} ]]; then
    case "$(printf '%s' "$CLIPBOARD_BACKEND" | tr '[:upper:]' '[:lower:]')" in
      macos | darwin | osx)
        printf 'macos\n'
        return 0
        ;;
      wayland | wl)
        printf 'wayland\n'
        return 0
        ;;
      x11 | x | xcb)
        printf 'x11\n'
        return 0
        ;;
      *)
        clip::err "unknown CLIPBOARD_BACKEND '$CLIPBOARD_BACKEND' (expected macos, wayland or x11)"
        return 1
        ;;
    esac
  fi

  if [[ "$(uname -s)" == Darwin ]] && clip::have pbcopy && clip::have pbpaste; then
    printf 'macos\n'
    return 0
  fi

  if [[ -n ${WAYLAND_DISPLAY:-} ]] && clip::have wl-copy && clip::have wl-paste; then
    printf 'wayland\n'
    return 0
  fi

  if [[ -n ${DISPLAY:-} ]] && { clip::have xclip || clip::have xsel; }; then
    printf 'x11\n'
    return 0
  fi

  clip::err "no clipboard backend found (need wl-clipboard, xclip/xsel, or a macOS session)"
  return 1
}

# Print the X11 tool to use: xclip | xsel
clip::x11_tool() {
  if [[ -n ${CLIP_X11_TOOL:-} ]]; then
    case "$CLIP_X11_TOOL" in
      xclip | xsel)
        printf '%s\n' "$CLIP_X11_TOOL"
        return 0
        ;;
      *)
        clip::err "unknown CLIP_X11_TOOL '$CLIP_X11_TOOL' (expected xclip or xsel)"
        return 1
        ;;
    esac
  fi

  if clip::have xclip; then
    printf 'xclip\n'
    return 0
  fi
  if clip::have xsel; then
    printf 'xsel\n'
    return 0
  fi

  clip::err "no X11 clipboard tool found (install xclip or xsel)"
  return 1
}

clip::is_text_type() {
  case "$1" in
    text | text/* | application/json | application/xml | application/*+xml | application/javascript | application/x-shellscript)
      return 0
      ;;
    *)
      return 1
      ;;
  esac
}

# Strip exactly one trailing newline from stdin, binary safe.
clip::trim_stdin() {
  if clip::have perl; then
    perl -0777 -pe 's/\n\z//'
  elif clip::have python3 || clip::have python; then
    local py=python3
    if ! clip::have python3; then
      py=python
    fi
    "$py" -c 'import sys
d = sys.stdin.buffer.read()
sys.stdout.buffer.write(d[:-1] if d.endswith(b"\n") else d)'
  else
    # Text-only fallback: command substitution drops the sentinel instead of
    # the trailing newline we actually want to remove.
    local data
    data="$(
      cat
      printf x
    )"
    data="${data%x}"
    printf '%s' "${data%$'\n'}"
  fi
}

# Best-effort probe: does the given X selection currently hold text?
# Returns 0 (text), 1 (non-text). Fails open to "text" when unsure.
clip::x11_selection_is_text() {
  local sel="$1" targets atom found_text=0 found_any=0

  if ! targets="$(xclip -selection "$sel" -o -t TARGETS 2>/dev/null)"; then
    return 0
  fi

  # Command substitution strips the trailing newline, and read() reports EOF
  # on a final line that has none, so add one back or the last atom is lost.
  while IFS= read -r atom; do
    [[ -z $atom ]] && continue
    found_any=1
    case "$atom" in
      text | text/* | UTF8_STRING | STRING | TEXT | COMPOUND_TEXT)
        found_text=1
        ;;
    esac
  done < <(printf '%s\n' "$targets" | tr -s '[:space:]' '\n')

  if ((found_text)); then
    return 0
  fi
  if ((found_any)); then
    return 1
  fi
  return 0
}

# Best-effort probe: does the selection carry a password-manager "this is
# sensitive" hint (the same atom wl-clipboard watches for)?
clip::x11_selection_is_sensitive() {
  xclip -selection "$1" -o -t TARGETS 2>/dev/null |
    tr -s '[:space:]' '\n' |
    grep -qx 'x-kde-passwordManagerHint'
}
