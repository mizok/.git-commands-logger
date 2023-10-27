# git-command-logger
git command logger shell(zsh)

用來記錄macOS terminal git 指令操作的小工具。

## 安裝方法

1. 把這一段shell(zsh) 複製到.zshrc內部

    ```shell
    gitCommandLogger=$HOME/.git_commands_logger/.git_commands_logger.sh;
    source $gitCommandLogger
    function chpwd {
        if [[ "$PWD" != "$OLDPWD" ]]; then
        source $gitCommandLogger
        fi
    }
    ```
2. `git clone`本專案，並放置在使用者的主目錄($HOME)底下

## 使用方法與注意事項

1. 若有妥善安裝, 則每次打開terminal都會執行本腳本
2. 若偵測到當前terminal的path為`git workspace`(有`git`版控的資料夾)時, 就會自動開始偵測並記錄`git`操作
3. 本腳本的log檔案會存放在`$HOME/.git_commands_logger/logs/`底下
4. 請注意本腳本無法紀錄`VSCode`內建版控功能的git操作