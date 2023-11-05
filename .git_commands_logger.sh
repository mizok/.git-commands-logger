#!/bin/zsh

#如果通配符無法匹配到任何檔案時，會產生“no matches found”的錯誤, 設置NO_NOMATCH 以避開錯誤狀況
setopt NO_NOMATCH

log_file=""
temp_file=""
test_file=""
repo_name=""
root_path=${ZDOTDIR:-$HOME}
log_directory="$root_path/.git_commands_logger/logs"
days_to_keep_logs=7
branch_remind_prefix=">>>>>"

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
                if [[ "$line" == "$branch_remind_prefix"* ]]; then
                    # 遇到包含branch_remind_prefix的行，表示上一條命令是切換分支的命令
                    is_new_command=true
                    latest_command="${line//>*/}"
                elif [[ "$line" == "["* ]]; then
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

        # 檢查是否在Git工作區
        if [ -d .git ] || git rev-parse --is-inside-work-tree >/dev/null 2>&1; then
            # 檢查是否在分支上
            local current_branch=""
            if git symbolic-ref -q --short HEAD >/dev/null 2>&1; then
                current_branch=$(git symbolic-ref -q --short HEAD)
            else
                # 如果不在分支上，獲取當前commit點的SHA
                current_branch=$(git rev-parse --short HEAD)
            fi

            # 確認獲取的分支或commit點不為空
            if [ -n "$current_branch" ]; then
                local date_current=$(date "+%Y/%m/%d %H:%M:%S")
                find_latest_command_timestamp
                local last_entry_timestamp=$?
                local current_timestamp=$(date -jf "%Y/%m/%d %H:%M:%S" "$date_current" +%s)
                local time_diff=$(((current_timestamp - last_entry_timestamp) / 3600))

                if [[ $command == "git "* || $command == "git."* ]]; then
                    echo "[$date_current] $command" >>"$log_file"

                    if [[ $command == "git co "* || $command == "git checkout "* || $command == "git switch "* ]]; then
                        echo "$branch_remind_prefix  現在位於 $current_branch 分支/commit 點" >>"$log_file"
                    fi
                fi
            fi
        fi
    }

    function delete_outdated_logs {

        function should_write_line {
            local line="$1"
            local current_time=$(date "+%s")
            local line_timestamp=$(echo "$line" | grep -oE '\[.*\]' | tr -d '[]')
            if [[ -n $line_timestamp ]]; then
                local line_time_diff=$(((current_time - $(date -jf "%Y/%m/%d %H:%M:%S" "$line_timestamp" "+%s")) / 86400))
                if [[ $line_time_diff -gt $days_to_keep_logs ]]; then
                    return 1
                fi
            else
                if [[ "$line" == "$branch_remind_prefix"* ]]; then
                    local prev_line=$(tail -n 1 "$temp_file")
                    local prev_line_timestamp=$(echo "$prev_line" | grep -oE '\[.*\]' | tr -d '[]')
                    local prev_line_time_diff=$(((current_time - $(date -jf "%Y/%m/%d %H:%M:%S" "$prev_line_timestamp" "+%s")) / 86400))

                    if [[ $prev_line_time_diff -gt $days_to_keep_logs ]]; then
                        return 1
                    fi
                fi
            fi

            return 0
        }

        function process_log_file {
            while IFS= read -r line || [[ -n $line ]]; do
                if should_write_line "$line"; then
                    echo "$line" >>"$temp_file"
                fi
            done <"$log_file"

            mv "$temp_file" "$log_file"

        }

        check＿if_exist_outdated_logs() {
            local exist_outdated_logs=1
            if [[ -e $log_file ]]; then
                while IFS= read -r line || [[ -n $line ]]; do
                    local timestamp=$(echo "$line" | grep -oE '\[.*\]' | tr -d '[]')
                    if [[ -n $timestamp ]]; then
                        local line_time=$(date -jf "%Y/%m/%d %H:%M:%S" "$timestamp" "+%s")
                        local current_time=$(date "+%s")
                        local time_diff=$(((current_time - line_time) / (3600 * 24)))
                        if [[ $time_diff -gt $days_to_keep_logs ]]; then
                            exist_outdated_logs=0
                        fi
                    fi
                done <"$log_file"
            fi

            return $exist_outdated_logs
        }

        if check＿if_exist_outdated_logs; then
            echo -e "[git command logger] 偵測到存在 $days_to_keep_logs 天以前的舊日誌條目, 請問是否刪除? (y/n)"
            read userInput

            if [[ $userInput ]]; then
                # 處理日誌文件
                process_log_file
                echo "已刪除 $days_to_keep_logs 天以前的舊日誌條目。"
            else
                echo "取消刪除。"
            fi
        fi

    }

    # 取得Git倉庫的根目錄名
    if [ -d .git ] || git rev-parse --is-inside-work-tree >/dev/null 2>&1; then
        repo_name=$(basename "$(git rev-parse --show-toplevel)")

        # 如果日誌資料夾不存在，則建立它
        if [ ! -d "$log_directory" ]; then
            mkdir -p "$log_directory"
        fi

        # 定義日誌檔名
        log_file="$log_directory/${repo_name}_git_commands.log"
        temp_file=$log_file".temp"
        test_file=$log_file".test"

        delete_outdated_logs

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
        # 檢查當前是否有切換路徑或是原地發動cd指令
        if [ -d .git ] || git rev-parse --is-inside-work-tree >/dev/null 2>&1; then
            local current_repo_name=$(basename "$(git rev-parse --show-toplevel)")
            # 如果在同一個git workspace底下，不重新綁定紀錄行為
            if [[ "$current_repo_name" != "$repo_name" ]]; then
                setup_git_commands_logging
            fi
        fi

    fi
}
