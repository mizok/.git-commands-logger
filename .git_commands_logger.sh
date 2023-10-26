#!/bin/zsh

function record_git_commands {
    local command="$1" # 取得目前執行的命令
    local timestamp=$(date "+%Y:%m:%d:%H:%M:%S")
    if [[ $command == "git "* || $command == "git."* ]]; then

        # 記錄命令到日誌文件
        echo "[$timestamp] $command" >>"$log_file"

        # 如果是git co或git checkout指令，追加特定資訊到日誌文件
        if [[ $command == "git co "* || $command == "git checkout "* ]]; then
            local branch_or_commit=$(git symbolic-ref -q --short HEAD || git describe --tags --exact-match)
            echo ">>>>  現在位於 $branch_or_commit 分支/commit 點" >>"$log_file"
        fi

    fi
}

function setup_git_commands_logging {
    local timestamp=$(date "+%Y:%m:%d:%H:%M:%S")
    initial=0
    current_command=""
    max_log_cache=4
    max_log_preserve_day=7

    function my_preexec() {
        # 在執行命令之前執行的程式碼
        # 使用$1來獲取即將執行的指令
        current_command=$1
    }

    # 取得Git倉庫的根目錄名
    if [ -d .git ] || git rev-parse --is-inside-work-tree >/dev/null 2>&1; then
        repo_name=$(basename "$(git rev-parse --show-toplevel)")
        log_directory="/Users/mizokhuangmbp2023/.git_command_log/$repo_name"

        # 如果日誌資料夾不存在，則建立它
        if [ ! -d "$log_directory" ]; then
            mkdir -p "$log_directory"
        fi

        # 產生日誌檔名
        log_file="$log_directory/${repo_name}_git_commands_$(date +%Y%m%d%H%M%S).log"

        # 在日誌檔案中寫入開啟項目的訊息
        echo "已經開啟 $repo_name 專案, 現在時間$timestamp , 開始即時記錄git的相關操作" >>"$log_file"
        echo " " >>"$log_file"
        echo "---" >>"$log_file"
        echo " " >>"$log_file"
        echo "\e[42m\e[30m已經打開 $repo_name 專案, 開始即時記錄git的相關操作\e[0m\e[49m"

        # 自訂鉤子，使得每次指令結束後都會呼叫my_preexec函數
        autoload -U add-zsh-hook
        add-zsh-hook preexec my_preexec

        # 設定precmd鉤子，使得每次指令結束後都會呼叫record_git_commands函數
        precmd() {
            if [[ "$initial" == "0" ]]; then
                initial=1
            else
                record_git_commands $current_command
            fi

        }

        # 檢查並刪除超過7天的日誌文件
        latest_log=$(ls -t "$log_directory/${repo_name}_git_commands_"*.log 2>/dev/null | head -1)
        # 從檔案路徑中提取日期部分（假設日期部分的格式固定）
        date_part=$(echo "$latest_log" | grep -oE '[0-9]{14}')
        # 將日期轉換為Unix時間戳記（以秒為單位）
        unix_timestamp=$(date -j -f "%Y%m%d%H%M%S" "$date_part" "+%s")
        current_timestamp=$(date "+%Y%m%d%H%M%S")
        days_difference=$(((current_timestamp - latest_log_timestamp) / 86400)) # 86400 seconds in a day
        echo $current_timestamp
        echo $latest_log

        if [ "$days_difference" -gt $max_log_preserve_day ]; then
            echo -e "\e[33m日誌已超過 $max_log_preserve_day 天，即將刪除全部日誌。\e[0m"
            echo -e "\e[47m\e[33m是否確定刪除? (y/n):\e[0m\e[49m "
            read userInput

            if [[ "$userInput" == "y" ]]; then
                rm "$log_directory/${repo_name}_git_commands_"*.log
                echo
                echo "檔案已刪除。"
                echo
            else
                echo
                echo "取消刪除。"
                echo
            fi
        fi

        # 檢查並刪除超過50篇的五成日誌文件
        logs_count=$(ls -1 "$log_directory/${repo_name}_git_commands_"*.log 2>/dev/null | wc -l)
        if [ "$logs_count" -gt $max_log_cache ]; then
            num_logs_to_delete=$((logs_count / 2)) # Delete 50% of the logs
            oldest_logs=$(ls -t "$log_directory/${repo_name}_git_commands_"*.log 2>/dev/null | tail -$num_logs_to_delete)

            echo -e "\e[33m即將刪除最舊的 $num_logs_to_delete 篇日誌：\e[0m"
            echo -e "\e[37m$oldest_logs\e[0m"
            echo
            echo -e "\e[47m\e[33m是否確定刪除? (y/n):\e[0m\e[49m "
            read userInput

            if [[ "$userInput" == "y" ]]; then
                rm $oldest_logs
                echo
                echo "檔案已刪除。"
                echo
            else
                echo
                echo "取消刪除。"
                echo
            fi
        fi

    fi
}

setup_git_commands_logging
