#!/bin/bash
# 生成目錄
root_path=${ZDOTDIR:-$HOME}
logger_directory="$root_path/.git_commands_logger"
if [ ! -d "$logger_directory" ]; then
    mkdir -p "$logger_directory"
fi

remotePrefix="https://raw.githubusercontent.com/mizok/.git-commands-logger/main"

set_global_hooks() {
    # 設置全域的Git hooks
    hooks_path="$root_path/.git_hooks"
    git config --global core.hooksPath $hooks_path

    if [ ! -d "$hooks_path" ]; then
        mkdir -p "$hooks_path"
    fi

    # 創建commit-msg hook
    
    commit_msg_hooks_content=$(curl -s "$remotePrefix/hooks/commit-msg")
    local_commit_msg_hook_file="$hooks_path/commit-msg"

    if ! grep -qF "$commit_msg_hooks_content" "$local_commit_msg_hook_file"; then
        echo "$commit_msg_hooks_content" >> $local_commit_msg_hook_file
        chmod +x $local_commit_msg_hook_file
    fi
    

    # 創建pre-push hook

    pre_push_hooks_content=$(curl -s "$remotePrefix/hooks/pre-push")
    local_pre_push_hook_file="$hooks_path/pre-push"

    if ! grep -qF "$pre_push_hooks_content" "$local_pre_push_hook_file"; then
        echo "$pre_push_hooks_content" >> $local_commit_msg_hook_file
        chmod +x $local_pre_push_hook_file
    fi
    

    echo
    echo "\033[33m全域Git hooks已被設置為 $hooks_path\033[0m"
}

echo "\033[32m請問是否要設定全域Git hooks偵測功能 (y/n)?\033[0m"
read userInput1
if [[ $userInput1 == 'y' ]]; then
    echo
    echo "\033[32m此設定將會改寫git的全域屬性core.hook , 是否確認這個改動 (y/n)?\033[0m"
    read userInput2
    if [[ $userInput2 == 'y' ]]; then
        set_global_hooks
    else
        echo "\033[36m已取消設置全域Git hooks偵測功能。\033[0m"
    fi
else
    echo "\033[36m未設置全域Git hooks偵測功能。\033[0m"
fi

# 下載腳本並保存到目標路徑
git_commands_logger_url="$remotePrefix/.git_commands_logger.sh"
download_path="$logger_directory/.git_commands_logger.sh"

if [ -f "$download_path" ]; then
    rm -f "$download_path"
fi

curl -fsSL -o "$download_path" "$git_commands_logger_url"

# 留一行空白
echo

# 檢查下載是否成功
if [ $? -eq 0 ]; then
    echo "腳本已成功下載到您的主目錄。"
    chmod +x "$download_path" # 賦予腳本執行權限（如果需要）
else
    echo "無法下載腳本。請檢查網絡連接和URL。"
fi

# 添加到 .zshrc 文件中
zshrc_path="$root_path/.zshrc"
config_lines="gitCommandLogger=$root_path"'/.git_commands_logger/.git_commands_logger.sh;
source $gitCommandLogger'

if [ -f "$zshrc_path" ]; then
    # 留一行空白
    echo
    # 檢查是否已經存在相應的設定，如果不存在，則添加到 .zshrc 文件中

    if ! grep -qF "$config_lines" "$zshrc_path"; then
        echo "\n# Add Git Command Logger configuration\n$config_lines" >>"$zshrc_path"
        echo "Configuration added to $zshrc_path"
    else
        echo "Configuration already exists in $zshrc_path"
    fi
else
    echo "$zshrc_path does not exist. Please create the .zshrc file manually and add the configuration."
fi
