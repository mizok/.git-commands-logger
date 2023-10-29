#!/bin/bash

# 生成目錄
root_path=${ZDOTDIR:-$HOME}
logger_directory="$root_path/.git_commands_logger"
if [ ! -d "$logger_directory" ]; then
    mkdir -p "$logger_directory"
fi

# 下載腳本並保存到目標路徑
git_commands_logger_url="https://raw.githubusercontent.com/mizok/.git-commands-logger/main/.git_commands_logger.sh"
download_path="$logger_directory/.git_commands_logger.sh"

if [ -f "$download_path" ]; then
    rm -f "$download_path"
fi

curl -fsSL -o "$download_path" "$git_commands_logger_url"

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
    # 檢查是否已經存在相應的設定，如果不存在，則添加到 .zshrc 文件中
    if ! grep -qF "$config_lines" "$zshrc_path"; then
        echo "\n# Add Git Command Logger configuration\n$config_lines" >> "$zshrc_path"
        echo "Configuration added to $zshrc_path"
    else
        echo "Configuration already exists in $zshrc_path"
    fi
else
    echo "$zshrc_path does not exist. Please create the .zshrc file manually and add the configuration."
fi
