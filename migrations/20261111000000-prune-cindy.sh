echo "清扫退役的 cindy 启动包装与 desktop 项"

prune_cindy() {
  local path="$1" expected="$2" actual
  if [[ ! -e "$path" && ! -L "$path" ]]; then
    echo "已不存在：$path"
    return 0
  fi
  # Directories, broken links and unreadable files cannot match a retired file.
  if [[ -f "$path" ]] && actual=$(sha256sum -- "$path"); then
    if [[ "${actual%% *}" == "$expected" ]]; then
      rm -f -- "$path"
      echo "已删除：$path"
      return 0
    fi
  fi
  echo "内容不匹配，保留不动：$path"
}

prune_cindy "$HOME/.local/bin/cindy" 'f5314cca9db9efd3b928739750d423bc0147d8691bd047a29582a79ee4123bd2'
prune_cindy "$HOME/.local/share/applications/cindy.desktop" '210fc34dc53db8e0091ddd881e71ed93a8badaed3ed8a3cfbe96947a1aabfb91'
exit 0
