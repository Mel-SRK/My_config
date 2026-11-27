#!/usr/bin/env bash
set -euo pipefail
source "$(cd -- "$(dirname -- "${BASH_SOURCE[0]}")" && pwd)/../lib/base-test.sh"

for cmd in nvim zsh mktemp; do require_command "$cmd"; done
tmp=$(mktemp -d)
trap 'rm -rf "$tmp"' EXIT
cat > "$tmp/editor.lua" <<'LUA'
dofile(assert(os.getenv("MYCONFIG_AUTOCMD")))
for _, case in ipairs({
  { "markdown", "line  " },
  { "rst", "line  " },
  { "diff", "line  " },
  { "text", "line" },
}) do
  vim.cmd.enew({ bang = true })
  vim.bo.filetype = case[1]
  vim.api.nvim_buf_set_lines(0, 0, -1, false, { "line  ", "second" })
  vim.api.nvim_win_set_cursor(0, { 2, 2 })
  vim.fn.setreg("/", "existing-search")
  vim.api.nvim_exec_autocmds("BufWritePre", { buffer = 0 })
  assert(vim.api.nvim_buf_get_lines(0, 0, 1, false)[1] == case[2], case[1])
  assert(vim.fn.getreg("/") == "existing-search", "search register changed")
  assert(vim.deep_equal(vim.api.nvim_win_get_cursor(0), { 2, 2 }), "cursor moved")
end
LUA
NVIM_LOG_FILE="$tmp/nvim.log" MYCONFIG_AUTOCMD="$ROOT/nvim/lua/core/autocmd.lua" \
  nvim --headless -u NONE -i NONE -l "$tmp/editor.lua" ||
  fail '编辑器保存保留语义空格，普通文本清理且不移动光标或改搜索'
pass '编辑器保存保留语义空格，普通文本清理且不移动光标或改搜索'

out=$(env no_proxy='example.test,localhost' NO_PROXY='internal.test' \
  MYCONFIG_ZSHRC="$ROOT/home/.zshrc" zsh -f -c '
    source "$MYCONFIG_ZSHRC"
    source "$MYCONFIG_ZSHRC"
    [[ "$QT_QPA_PLATFORMTHEME" == qt6ct && "$NO_PROXY" == "$no_proxy" ]] || exit 1
    print -r -- "$no_proxy"
  ') || fail 'shell 环境加载成功'
assert_eq 'localhost,127.0.0.1,::1,example.test,internal.test' "$out" '本地代理例外保留原值且嵌套 shell 不重复'

out=$(env -u no_proxy -u NO_PROXY MYCONFIG_ZSHRC="$ROOT/home/.zshrc" zsh -f -c '
  source "$MYCONFIG_ZSHRC"
  print -r -- "$no_proxy"
') || fail '无继承值时加载代理例外'
assert_eq 'localhost,127.0.0.1,::1' "$out" '无继承值时代理例外没有空字段'

if command -v script >/dev/null 2>&1 && [[ -r /usr/share/oh-my-zsh/oh-my-zsh.sh ]]; then
  theme="$tmp/home/.oh-my-zsh/custom/themes/powerlevel10k"
  mkdir -p "$theme" "$tmp/cache"
  touch "$theme/powerlevel10k.zsh-theme"
  cat > "$tmp/reload.zsh" <<'ZSH'
source "$MYCONFIG_ZSHRC"
before="$FPATH"
source "$MYCONFIG_ZSHRC"
[[ "$FPATH" == "$before" && ${#fpath[@]} -eq ${#${(u)fpath}[@]} ]]
ZSH
  out=$(env HOME="$tmp/home" ZDOTDIR="$tmp/home" XDG_CACHE_HOME="$tmp/cache" \
    ZSH_CACHE_DIR="$tmp/cache" ZSH_COMPDUMP="$tmp/.zcompdump" \
    TERM=xterm-256color TERM_PROGRAM=Orca MYCONFIG_ZSHRC="$ROOT/home/.zshrc" \
    MYCONFIG_ZSH_TEST="$tmp/reload.zsh" script -qefc 'zsh -fi "$MYCONFIG_ZSH_TEST"' /dev/null) ||
    fail '重载 Zsh 后补全路径不变且无重复' "$out"
  pass '重载 Zsh 后补全路径不变且无重复'
else
  skip '重载 Zsh 后补全路径不变且无重复' '缺少 script 或 Oh My Zsh'
fi
