#!/bin/zsh

#如果通配符無法匹配到任何檔案時，會產生“no matches found”的錯誤, 設置NO_NOMATCH 以避開錯誤狀況
setopt NO_NOMATCH

log_file=""
repo_name=""
root_path=${ZDOTDIR:-$HOME}
days_to_keep_logs=7
max_time_diff_limit=8
branch_remind_prefix=">>>>>>>"
time_diff_remind="====================="

function setup_git_commands_logging {
    local timestamp=$(date "+%Y/%m/%d %H:%M:%S")
    local initialized=false
    current_command=""

    function my_preexec() {
        # 在執行命令之前執行的程式碼
        # 使用$1來獲取即將執行的指令
        current_command=$1
    }

    # 找到 log 文件中最新的命令執行紀錄
    function find_latest_command_timestamp {
        local date_current=$(date "+%Y/%m/%d %H:%M:%S")
        local current_timestamp=$(date -jf "%Y/%m/%d %H:%M:%S" "$date_current" "+%s")
        local latest_command=""
        local is_new_command=true
        local latest_command_timestamp=$current_timestamp
        if [[ -e $log_file ]]; then
            # 讀取 log 文件，按行解析
            while IFS= read -r line; do
                if [[ "$line" == "$time_diff_remind"* ]]; then
                    # 遇到分隔線，表示上一條命令執行的時間距離現在超過固定時數
                    is_new_command=false
                elif [[ "$line" == "$branch_remind_prefix"* ]]; then
                    # 遇到包含">>>>>>>"的行，表示上一條命令是切換分支的命令
                    is_new_command=true
                    latest_command="${line//>*/}"
                elif [[ "$line" == "["* && "$line" != "$time_diff_remind"* ]]; then
                    is_new_command=true
                    # 遇到日期行，表示一條新的命令
                    if [[ $is_new_command == true ]]; then
                        latest_command="$line"
                        # 提取日期部分（假設日期部分的格式固定）
                        local date_part=$(echo "$line" | grep -oE '\[.*\]')
                        # 將日期轉換為Unix時間戳記（以秒為單位）
                        latest_command_timestamp=$(date -jf "[%Y/%m/%d %H:%M:%S]" "$date_part" "+%s")
                    fi
                fi
            done <"$log_file"
        fi

        return $latest_command_timestamp
    }

    function record_git_commands {
         # 如果日誌資料夾不存在，則建立它
        if [ ! -d "$log_directory" ]; then
            mkdir -p "$log_directory"
        fi
        
        local command="$1" # 取得目前執行的命令
        local date_current=$(date "+%Y/%m/%d %H:%M:%S")
        find_latest_command_timestamp
        local last_entry_timestamp=$?
        local current_timestamp=$(date -jf "%Y/%m/%d %H:%M:%S" "$date_current" +%s)
        local time_diff=$(((current_timestamp - last_entry_timestamp) / 3600))

        if [[ $time_diff -gt $max_time_diff_limit ]]; then
            echo "" >>"$log_file"
            echo "$time_diff_remind" >>"$log_file"
            echo "" >>"$log_file"
        fi

        if [[ $command == "git "* || $command == "git."* ]]; then
            # 記錄命令到日誌文件
            echo "[$date_current] $command" >>"$log_file"

            # 如果是git co或git checkout指令，追加特定資訊到日誌文件
            if [[ $command == "git co "* || $command == "git checkout "* ]]; then
                local branch_or_commit=$(git symbolic-ref -q --short HEAD || git describe --tags --exact-match)
                echo ">>>>>  現在位於 $branch_or_commit 分支/commit 點" >>"$log_file"
            fi
        fi
    }

    # 取得Git倉庫的根目錄名
    if [ -d .git ] || git rev-parse --is-inside-work-tree >/dev/null 2>&1; then
        repo_name=$(basename "$(git rev-parse --show-toplevel)")
        local log_directory="$root_path/.git_commands_logger/logs"

        # 如果日誌資料夾不存在，則建立它
        if [ ! -d "$log_directory" ]; then
            mkdir -p "$log_directory"
        fi

        # 產生日誌檔名
        log_file="$log_directory/${repo_name}_git_commands.log"

        echo "\e[42m\e[30m已經打開 $repo_name 專案, 開始即時記錄git的相關操作\e[0m\e[49m"

        # 自訂鉤子，使得每次指令結束後都會呼叫my_preexec函數
        autoload -U add-zsh-hook
        add-zsh-hook preexec my_preexec

        # 設定precmd鉤子，使得每次指令結束後都會呼叫record_git_commands函數
        precmd() {
            if [[ ! $initialized ]]; then
                initialized=true
            else
                record_git_commands $current_command
            fi
        }

    fi

}

setup_git_commands_logging

function chpwd {
    if [[ "$PWD" != "$OLDPWD" ]]; then
        # 检查当前目录是否在同一个Git工作区下
        if [ -d .git ] || git rev-parse --is-inside-work-tree >/dev/null 2>&1; then
            local current_repo_name=$(basename "$(git rev-parse --show-toplevel)")
            # 如果在同一个Git工作区下，不重新设置日志记录
            if [[ "$current_repo_name" != "$repo_name" ]]; then
                setup_git_commands_logging
            fi
        fi

    fi
}
