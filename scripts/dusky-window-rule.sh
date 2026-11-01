#!/usr/bin/env bash
# User-scoped Dusky/Hyprland integration for Duskyport. Run as regular user.
set -euo pipefail

mode="${1:-install}"
config_home="${XDG_CONFIG_HOME:-$HOME/.config}"
hypr_dir="$config_home/hypr"
user_lua="$hypr_dir/user.lua"
state_home="${XDG_DATA_HOME:-$HOME/.local/share}/duskyport"
backup_dir="$state_home/hypr-backups"
begin='-- BEGIN DUSKYPORT MANAGED WINDOW RULE'
end='-- END DUSKYPORT MANAGED WINDOW RULE'

if [[ ! -f "$hypr_dir/hyprland.lua" ]]; then
  exit 0
fi
mkdir -p "$hypr_dir" "$backup_dir"

strip_block() {
  python3 - "$user_lua" "$begin" "$end" <<'PY'
from pathlib import Path
import sys
p=Path(sys.argv[1]); begin=sys.argv[2]; end=sys.argv[3]
if not p.exists():
    raise SystemExit(0)
s=p.read_text()
while begin in s:
    a=s.index(begin)
    b=s.find(end,a)
    if b < 0:
        s=s[:a]
        break
    b += len(end)
    if b < len(s) and s[b:b+1] == '\n': b += 1
    s=s[:a] + s[b:]
p.write_text(s.rstrip()+('\n' if s.strip() else ''))
PY
}

if [[ "$mode" == remove ]]; then
  strip_block
  command -v hyprctl >/dev/null 2>&1 && hyprctl reload >/dev/null 2>&1 || true
  exit 0
fi
[[ "$mode" == install ]] || { echo "usage: $0 [install|remove]" >&2; exit 2; }

if [[ -f "$user_lua" ]]; then
  cp -a "$user_lua" "$backup_dir/user.lua.$(date +%Y%m%d-%H%M%S)"
else
  : > "$user_lua"
fi
strip_block
cat >> "$user_lua" <<'LUA'
-- BEGIN DUSKYPORT MANAGED WINDOW RULE
hl.window_rule({
    name   = "float-duskyport-custom",
    match  = { title = "^(duskyport)$" },
    float  = true,
    size   = { 1280, 820 },
    center = true,
})
-- END DUSKYPORT MANAGED WINDOW RULE
LUA
command -v hyprctl >/dev/null 2>&1 && hyprctl reload >/dev/null 2>&1 || true
