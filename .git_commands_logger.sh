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

function delete_outdated_logs {
    # log保存數量上限
    local max_log_cache=30
    # log保存的天數上限
    local max_log_preserve_day=7
    # 檢查並刪除超過n天的日誌文件
    local latest_log=$(ls -t "$log_directory/${repo_name}_git_commands_"*.log 2>/dev/null | head -1)
    # 從檔案路徑中提取日期部分（假設日期部分的格式固定）
    local date_part=$(echo "$latest_log" | grep -oE '[0-9]{14}')
    local date_current=$(date "+%Y%m%d%H%M%S")
    # 將日期轉換為Unix時間戳記（以秒為單位）
    local latest_log_timestamp=$(date -j -f "%Y%m%d%H%M%S" "$date_part" "+%s")
    local current_timestamp=$(date -j -f "%Y%m%d%H%M%S" "$date_current" "+%s")
    local days_difference=$(((current_timestamp - latest_log_timestamp) / 86400)) # 86400 seconds in a day

    if [ "$days_difference" -gt $max_log_preserve_day ]; then
        echo -e "\e[33此專案的日誌皆已過期 $max_log_preserve_day 天以上，請問是否刪除所有日誌檔案？ (y/n):\e[0m"
        read userInput

        if [[ "$userInput" == "y" ]]; then
            rm "$log_directory/${repo_name}_git_commands_"*.log
            echo
            echo "已刪除所有過期的日誌檔案。"
            echo
        else
            echo
            echo "取消刪除。"
            echo
        fi
    fi

    # 檢查日誌檔案是否超過n篇, 若超過則只保留n/2篇的日誌, 剩下的刪除
    logs_count=$(ls -1 "$log_directory/${repo_name}_git_commands_"*.log 2>/dev/null | wc -l)
    if [ "$logs_count" -gt $max_log_cache ]; then
        local num_logs_to_keep=0
        if [[ $(($max_log_cache % 2)) -eq 1 ]]; then
            num_logs_to_keep=$((($max_log_cache - 1) / 2))
        else
            num_logs_to_keep=$(($max_log_cache / 2))
        fi

        local num_logs_to_delete=$((logs_count - num_logs_to_keep))

        local oldest_logs=$(ls -t "$log_directory/${repo_name}_git_commands_"*.log 2>/dev/null | tail -$num_logs_to_delete)
        local oldest_logs_arr=("$=oldest_logs")

        echo -e "\e[33m由於日誌數量已超過上限的 $max_log_cache 篇:\e[0m"
        echo -e "\e[37m$oldest_logs\e[0m"
        echo
        echo -e "\e[47m\e[30m請問是否要將上述最舊的 $num_logs_to_delete 篇日誌刪除? (y/n):\e[0m\e[49m "
        read userInput

        if [[ "$userInput" == "y" ]]; then
            for log_file in "${oldest_logs_arr[@]}"; do
                rm "$log_file"
            done
            echo
            echo "已刪除指定的日誌檔案。"
            echo
        else
            echo
            echo "取消刪除。"
            echo
        fi
    fi

}

function setup_git_commands_logging {
    local timestamp=$(date "+%Y/%m/%d %H:%M:%S")
    local initial=0
    current_command=""

    function my_preexec() {
        # 在執行命令之前執行的程式碼
        # 使用$1來獲取即將執行的指令
        current_command=$1
    }

    # 取得Git倉庫的根目錄名
    if [ -d .git ] || git rev-parse --is-inside-work-tree >/dev/null 2>&1; then
        repo_name=$(basename "$(git rev-parse --show-toplevel)")
        log_directory="$HOME/.git_commands_logger/logs/$repo_name"

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

        #刪除過期的log
        delete_outdated_logs

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

    fi
}

setup_git_commands_logging
