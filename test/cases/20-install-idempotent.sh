#!/usr/bin/env bash
set -euo pipefail
source "$(cd -- "$(dirname -- "${BASH_SOURCE[0]}")" && pwd)/../lib/base-test.sh"

for cmd in mktemp find sort xargs sha256sum readlink stat cmp diff; do require_command "$cmd"; done
tmp=$(mktemp -d)
trap 'rm -rf "$tmp"' EXIT
mkdir -p "$tmp/bin" "$tmp/home"
cat > "$tmp/bin/sudo" <<'SUDO'
#!/usr/bin/env bash
printf '%s\n' "$*" >> "${BASH_SOURCE[0]%/bin/sudo}/sudo.log"
exit 0
SUDO
chmod +x "$tmp/bin/sudo"
export PATH="$tmp/bin:$PATH"

snapshot() {
  (
    cd -- "$tmp/home"
    find . \( -type f -o -type l \) -print0 | LC_ALL=C sort -z | xargs -0 sha256sum
    while IFS= read -r -d '' link; do
      printf 'symlink %q -> %q\n' "$link" "$(readlink -- "$link")"
    done < <(find . -type l -print0 | LC_ALL=C sort -z)
  )
}
real_config="$HOME/.config/niri/config.kdl"
mtime() {
  if [[ -e "$real_config" || -L "$real_config" ]]; then
    stat -c %Y -- "$real_config"
  else
    printf '%s\n' missing
  fi
}
before=$(mtime)
if HOME="$tmp/home" "$ROOT/install.sh" --apply; then
  pass '首次 install --apply 成功'
else
  fail '首次 install --apply 成功'
fi
snapshot > "$tmp/a"
if HOME="$tmp/home" "$ROOT/install.sh" --apply; then
  pass '再次 install --apply 成功'
else
  fail '再次 install --apply 成功'
fi
snapshot > "$tmp/b"
if ! cmp -s "$tmp/a" "$tmp/b"; then
  difference=$(diff -u "$tmp/a" "$tmp/b" | sed -n '1,15p' || true)
  fail '重复安装快照一致（首处差异）' "$difference"
fi
pass '重复安装快照一致'
[[ ! -e "$tmp/sudo.log" ]] || fail '安装不调用 sudo' "$(cat "$tmp/sudo.log")"
pass '安装不调用 sudo'
assert_file "$tmp/home/.config/niri/config.kdl" '安装 niri 配置'
cmp -s "$ROOT/niri/config.kdl" "$tmp/home/.config/niri/config.kdl" || fail 'niri 配置内容一致'
pass 'niri 配置内容一致'
[[ -d "$tmp/home/.config/nvim" && -n "$(find "$tmp/home/.config/nvim" -mindepth 1 -print -quit)" ]] ||
  fail 'nvim 安装目录非空'
pass 'nvim 安装目录非空'
assert_eq "$before" "$(mtime)" '真实 HOME 的 niri 配置 mtime 不变'
