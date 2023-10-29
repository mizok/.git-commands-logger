#!/bin/bash
root_path=${ZDOTDIR:-$HOME}
# 定義要加入到.zshrc的內容
config_lines="
gitCommandLogger=$root_path"'/.git_commands_logger/.git_commands_logger.sh;
source $gitCommandLogger'

# 下載 .git_commands_logger.sh 文件
git_commands_logger_url="https://raw.githubusercontent.com/mizok/.git-commands-logger/main/.git_commands_logger.sh"
download_path="$root_path/.git_commands_logger/.git_commands_logger.sh"
if [  -f "$download_path" ]; then
    rm -f $download_path
fi
curl -fsSL -o "$download_path" "$git_commands_logger_url"
chmod +x $download_path

# 檢查.zshrc文件是否存在
zshrc_path="$root_path/.zshrc"
if [ -f "$zshrc_path" ]; then
    # 檢查是否已經存在相應的設定，如果不存在，則添加到.zshrc文件中
    if ! grep -qF "$config_lines" "$zshrc_path"; then
        echo -e "\n# Add Git Command Logger configuration\n$config_lines" >> "$zshrc_path"
        echo "Configuration added to $zshrc_path"
    else
        echo "Configuration already exists in $zshrc_path"
    fi
else
    echo "$zshrc_path does not exist. Please create the .zshrc file manually and add the configuration."
fi
