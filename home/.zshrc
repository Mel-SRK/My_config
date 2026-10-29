# 登录即进 tmux。必须放在 p10k instant prompt 之前：
# instant prompt 会重定向 fd 0/1/2 且到 zshrc 末尾才恢复，放在后面 attach 必然失败。
# 首个终端开 TS2K，之后每个终端自动建独立视图（session group）：
# 同一 group 内窗口列表共享、当前窗口各自独立，多个终端互不干扰。
if [[ -z "$TMUX" && -o interactive && "$TERM" != "dumb" ]]; then
    if tmux has-session -t TS2K 2>/dev/null; then
        # 固定 view1..view4 轮流复用：关终端时残留的会被下次捡起来，不会越堆越多
        for i in 1 2 3 4; do
            s="view$i"
            if ! tmux has-session -t "$s" 2>/dev/null; then
                tmux new-session -d -t TS2K -s "$s" 2>/dev/null
                tmux attach -t "$s"
                tmux kill-session -t "$s" 2>/dev/null
                break
            elif [ "$(tmux display -p -t "$s" '#{session_attached}' 2>/dev/null)" = "0" ]; then
                tmux attach -t "$s"
                tmux kill-session -t "$s" 2>/dev/null
                break
            fi
        done
    else
        tmux new-session -A -s TS2K
    fi
fi

# Enable Powerlevel10k instant prompt
if [[ -r "${XDG_CACHE_HOME:-$HOME/.cache}/p10k-instant-prompt-${(%):-%n}.zsh" ]]; then
  source "${XDG_CACHE_HOME:-$HOME/.cache}/p10k-instant-prompt-${(%):-%n}.zsh"
fi

# Oh My Zsh
export ZSH="/usr/share/oh-my-zsh"
ZSH_CUSTOM="$HOME/.oh-my-zsh/custom"

# Theme
ZSH_THEME="powerlevel10k/powerlevel10k"

# Plugins
plugins=(
    git
    z
    zsh-autosuggestions
    zsh-syntax-highlighting
)

source $ZSH/oh-my-zsh.sh

# User aliases
alias vim="nvim"
alias vi="nvim"
alias ls="ls --color=auto"
alias ll="ls -la"
alias la="ls -A"

# Environment
export PATH="$HOME/.local/bin:$PATH"
export EDITOR="nvim"
export VISUAL="nvim"

# p10k 配置
[[ ! -f ~/.p10k.zsh ]] || source ~/.p10k.zsh

# vlc皮肤
export QT_QPA_PLATFORMTHEME=qt5ct


# Clash Verge 代理
export http_proxy=http://127.0.0.1:7897
export https_proxy=http://127.0.0.1:7897
export all_proxy=socks5://127.0.0.1:7897

#fuck
eval $(thefuck --alias)

# Oh-my-pi
eval "$(omp completions zsh)"
