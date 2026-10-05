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

# tmux 自动 attach
if [ -z "$TMUX" ]; then
    tmux attach -t TS2K || tmux new -s TS2K
fi
# vlc皮肤
export QT_QPA_PLATFORMTHEME=qt5ct


# Clash Verge 代理
export http_proxy=http://127.0.0.1:7897
export https_proxy=http://127.0.0.1:7897
export all_proxy=socks5://127.0.0.1:7897

#fuck
eval $(thefuck --alias)


