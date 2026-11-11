# 登录即进 tmux。必须放在 p10k instant prompt 之前：
# instant prompt 会重定向 fd 0/1/2 且到 zshrc 末尾才恢复，放在后面 attach 必然失败。
# 终端总是进 TS2K；只有当 TS2K 已被别的终端占用时，才开独立视图（session group）：
# 同一 group 内窗口列表共享、当前窗口各自独立，多个终端互不干扰。
# exec 让 tmux 取代 shell：退出 tmux 即退出终端，不会落回 zsh；
# 视图客户端断开时由 destroy-unattached 自毁，不残留、不越堆越多。
# Orca 的终端面板不自动 attach：它的 PTY 是登录 shell，exec tmux 后会和主终端
# 共用 TS2K，还会让 Orca 等 shell-ready 超时才把启动命令敲进去。Orca 里要 tmux 手动敲。
if [[ -z "$TMUX" && "$TERM_PROGRAM" != "Orca" && -o interactive && -t 0 && -t 1 && -n "$TERM" && "$TERM" != "dumb" ]]; then
    if ! tmux has-session -t '=TS2K' 2>/dev/null; then
        exec tmux new-session -A -s TS2K
    fi

    # TS2K 没人占用：优先回到主会话（等同开机首个终端）
    if [[ "$(tmux display -p -t TS2K '#{session_attached}' 2>/dev/null)" == 0 ]]; then
        exec tmux attach -t '=TS2K'
    fi

    # TS2K 已被占用：占用编号最小的空闲视图
    for i in {1..9}; do
        s="view$i"
        tmux has-session -t "=$s" 2>/dev/null ||
            tmux new-session -d -t '=TS2K' -s "$s" 2>/dev/null
        if [[ "$(tmux display -p -t "$s" '#{session_attached}' 2>/dev/null)" == 0 ]]; then
            # 该 client 断开后视图会话自动销毁（视图只在这个终端存活期间存在）
            tmux set-hook -t "$s" client-attached \
                "set-option -t $s destroy-unattached on" 2>/dev/null
            exec tmux attach -t "=$s"
        fi
    done

    # 视图全部占满：退回主会话；若 TS2K 恰好刚消失则直接重建
    exec tmux new-session -A -s TS2K
fi

# 提示符、补全、插件只在真的有终端时加载。工具用管道跑 `zsh -i -c` 时没有控制终端，
# job control 开不起来：powerlevel10k 的 gitstatus 在 `setopt monitor` 处失败，
# 先打印 can't change option: monitor，再打印 gitstatus failed to initialize，
# 这些噪声会盖在命令自己的输出前面，看起来像命令出错。
typeset -gi __have_tty=0
[[ -o interactive && -t 0 && -t 1 ]] && __have_tty=1

# 环境变量对所有 shell 生效，包括没有终端的工具调用
# PATH 幂等：交互式 shell 里再起 zsh 时不要重复叠加同一目录
case ":$PATH:" in
  *":$HOME/.local/bin:"*) ;;
  *) export PATH="$HOME/.local/bin:$PATH" ;;
esac
export EDITOR="nvim"
export VISUAL="nvim"
export QT_QPA_PLATFORMTHEME=qt5ct

# Clash Verge 代理
export http_proxy=http://127.0.0.1:7897
export https_proxy=http://127.0.0.1:7897
export all_proxy=socks5://127.0.0.1:7897

if (( __have_tty )); then
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

    # p10k 配置
    [[ ! -f ~/.p10k.zsh ]] || source ~/.p10k.zsh

    #fuck
    eval $(thefuck --alias)

    # Oh-my-pi
    eval "$(omp completions zsh)"
fi
