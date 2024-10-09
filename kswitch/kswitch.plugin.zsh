# 获取 ~/.kube 目录下所有以 config- 开头的文件，并去掉前缀 config-
function _get_kube_configs() {
    # 获取所有 kubeconfig 文件名并去掉前缀 "config-"
    ls -1 ~/.kube/config-* 2>/dev/null | sed 's|.*/config-||'
}

# 使用 fzf 或 select 让用户选择配置文件
function _select_kube_config() {
    local configs=("${(@f)$(_get_kube_configs)}")

    # 如果没有找到任何配置文件，提示用户
    if [[ ${#configs[@]} -eq 0 ]]; then
        echo "No kubeconfig files found in ~/.kube."
        return 1
    fi

    # 检查是否安装了 fzf
    if command -v fzf >/dev/null 2>&1; then
        # 使用 fzf 进行选择，确保每个配置文件占一行
        local selection=$(printf '%s\n' "${configs[@]}" | fzf --no-multi)
        echo "$selection"
    else
        # 如果没有安装 fzf，则使用 select 进行选择
        echo "Please choose a kubeconfig:"
        select selection in "${configs[@]}"; do
            if [[ -n "$selection" ]]; then
                echo "$selection"
                break
            else
                echo "Invalid selection."
            fi
        done
    fi
}

# kswitch 函数：用于切换 kubeconfig 配置
function kswitch() {
    # 如果没有参数，则调用通用的选择逻辑
    if [[ -z "$1" ]]; then
        local selection=$(_select_kube_config)
        # 如果没有选择有效的 kubeconfig，退出
        if [[ -z "$selection" ]]; then
            echo "No selection made."
            return 1
        fi
        set -- "$selection"
    fi

    local file="config-$1"

    # 如果目标 kubeconfig 文件不存在，提示错误
    if [[ ! -f "$HOME/.kube/$file" ]]; then
        echo "Kubeconfig file '$HOME/.kube/$file' does not exist."
        return 1
    fi

    # 检查是否已经在使用该配置
    if [ -L "$HOME/.kube/config" ]; then
        local target=$(readlink -f "$HOME/.kube/config")
        target="$(basename ${target})"
    fi
    if [[ -n "$target" && "$target" == "$file" ]]; then
        echo "Already using $file."
        return 0
    fi

    # 执行切换 kubeconfig 的命令
    kubectl switch-config "$1"
    kubectx $(kubectl config current-context) > /dev/null

    # 更新 shell 环境
    #export KUBE_PS1_ENABLED=off
    #export KUBE_PS1_ENABLED=on
    if command -v kube_ps1 > /dev/null 2>&1 ;then
      #source <( kube_ps1 )
      # kubeon && kubeoff
      export KUBE_PS1_CONTEXT=$(kubectl config current-context)
      export KUBE_PS1_NAMESPACE=$(kubectl config view --minify --output 'jsonpath={..namespace}')
    fi
    
}


# 自动补全函数 _kswitch
_kswitch() {
    local -a completions
    local lastParam lastChar prefix

    # 获取当前命令行的参数
    local words=("${(@f)${(z)BUFFER}}")
    local current="${words[CURRENT]}"

    # 获取最后一个参数
    if [[ ${#words[*]} -gt 1 ]];then
        lastParam=${words[-1]}
    fi
    #lastChar=${lastParam[-1]}

    # 获取前缀（当前参数的值）
    prefix="${lastParam}"


    # 获取所有配置文件
    local configs=("${(@f)$(_get_kube_configs)}")

    # 过滤配置文件
    for config in "${configs[@]}"; do
        if [[ "$config" == "$prefix"* ]]; then
            completions+=("$config")
        fi
    done


    # 如果安装了 fzf，则使用 fzf 进行选择
    if command -v fzf >/dev/null 2>&1; then
        local selection=$(printf '%s\n' "${completions[@]}" | fzf --no-multi --query="$prefix")
        if [[ -n "$selection" ]]; then
            #print -z "$selection"
            compadd "$selection"
            return 0
        fi
    else
        # 否则直接用常规补全
        compadd "${completions[@]}"
    fi
}

# 启用补全：将 _kswitch 函数与 kswitch 命令绑定
compdef _kswitch kswitch
