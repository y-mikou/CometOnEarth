#!/bin/bash
###################################################################
## 終了処理
###################################################################
function do_exit () {
    rm -f "${TARGET_FILE_WK}"
    exit 0
}

###################################################################
## ルビ文字縮退関数
###################################################################
function ruby_collapse () {
    sed -i 's/《《\([^》]*\)》》/\1/g' "${TARGET_FILE_WK}"

    if ! command -v gawk >/dev/null 2>&1; then
        echo "警告: gawk が見つかりません。gawk をインストールするか、このスクリプトに対応する別の awk 実装を使用してください。" >&2
        return 1
    fi

    gawk -v OFS="" '
    BEGIN { }
    {
        line = $0;
        while (match(line, /｜[^《]+《[^》]+》/)) {
            token = substr(line, RSTART, RLENGTH);
            # capture base and ruby via gensub
            base = gensub(/｜([^《]+)《[^》]+》/, "\\1", "g", token);
            ruby = gensub(/｜[^《]+《([^》]+)》/, "\\1", "g", token);
            bn = length(base);
            rn = length(ruby);
            if (bn >= int((rn/2)+0.9)) {
                repl = base;
            } else {
                repl = "";
                for (i = 0; i < bn; ++i) repl = repl "■";
            }
            # replace at pos
            line = substr(line, 1, RSTART-1) repl substr(line, RSTART + RLENGTH);
        }
        print line;
    }' "${TARGET_FILE_WK}" > "${TARGET_FILE_WK}.tmp" && mv "${TARGET_FILE_WK}.tmp" "${TARGET_FILE_WK}"
}

###################################################################
## 以下は CometOnEarth.sh の本体をそのままコピーしたもの
###################################################################

function view_violation () {

    echo "✨️禁則処理・その他修正必要箇所検出モード"

    : 検出すべき内容の定義 && {
        #3文字以下で終わる行の確認
        REGEX01='^.{1,3}$'

        #行頭が 、。」』）〟！？!?
        REGEX02='^[、。」』）〟！？!?]'

        #折り返し限界-5文字に■(母字より長い可能性があるルビ)がある
        REGEX03="^[^■]{$(( ${FOLD_LENGTH} - 5 )),${FOLD_LENGTH}}■"

        #折り返しをまたぐ形で「……」がある(行頭に1回だけ「…」が登場する)
        REGEX04="^…[^…]"

        #折り返しをまたぐ形で「――」がある(行頭に1回だけ「―」が登場する)
        REGEX05="^―[^―]"

        #行末が 「『（〝
        REGEX06='[「『（〝]$'


    }

    ruby_collapse

    : 発生件数取得と件数指定 && {
        #検出件数を取得
        VIOLATION_COUNT=$(\
            cat "${TARGET_FILE_WK}" \
            | sed -E "s/(.{${FOLD_LENGTH}})/\\1\\n/g" \
            | grep -cE --color=always "(${REGEX01})|(${REGEX02})|(${REGEX03})|(${REGEX04})|(${REGEX05})|(${REGEX06})"
        )

        if [[ -z ${VIEW_COUNT_tmp} ]] ; then
            echo "🗨️ 表示件数指定がなかったためデフォルトの10件表示です"
        fi
        VIEW_COUNT=${VIEW_COUNT_tmp:-10}

        echo "🗿 全${VIOLATION_COUNT}箇所(行)中、${VIEW_COUNT}箇所(行)分の警告箇所を表示します"

        read -p ">Press Enter<"
        echo "---------------------------------------"

        #抽出行は、前1行、HIT行、後1行、区切行、の4行なので、結果の抽出行は件数の4倍で設定する
        if [[ ${VIOLATION_COUNT} -lt ${VIEW_COUNT} ]] ;then
            VIEW_COUNT=${VIOLATION_COUNT}
        fi
        VIEW_ROWS=$(( ${VIEW_COUNT} * 4))
    }

    : 警告箇所検出 && {
        #警告箇所の検出を実行
        cat "${TARGET_FILE_WK}" \
        | sed -E "s/(.{${FOLD_LENGTH}})/\\1\\n/g" \
        | grep -En1 --color=always "(${REGEX01})|(${REGEX02})|(${REGEX03})|(${REGEX04})|(${REGEX05})|(${REGEX06})" \
        | sed -n 1,${VIEW_ROWS}p
    }

    : 終了処理 & {
        echo "---------------------------------------"
        if [ "$VIOLATION_COUNT" -eq 0 ]; then
            echo "✅ 禁則処理候補箇所なし、修正候補箇所なし"
        fi
    }
}

function view_fold () {

    ruby_collapse

    : 表示行数の操作 & {
        echo "✨️折り返し確認機能モード。"
        if [[ -z ${VIEW_COUNT_tmp} ]] ; then
            echo "🗨️ 表示件数指定がなかったためデフォルトの1−100行表示です"
        fi
        VIEW_COUNT="${VIEW_COUNT_tmp:-1-100}"

        folded_rows_count=$(cat "${TARGET_FILE_WK}" | sed -E "s/(.{${FOLD_LENGTH}})/\\1\\n/g" | wc -l )

        if [[ ${VIEW_COUNT} -eq 0 ]] ; then
            echo "🗿折返結果、全行を表示します。"
        else
            if [[ ${VIEW_COUNT} =~ [0-9]+-[0-9]+ ]] ; then
                startLine=$(echo ${VIEW_COUNT} | cut -d '-' -f 1)
                endLine=$(echo ${VIEW_COUNT} | cut -d '-' -f 2)
                comnd="${startLine},${endLine}p"
                echo "🗿折返結果、全${folded_rows_count}行中の${startLine}行目〜${endLine}行目を表示します。"
            else
                comnd="1,${VIEW_COUNT}p"
                echo "🗿折返結果、全${folded_rows_count}行中の1行目〜${VIEW_COUNT}行目を表示します。"
            fi
        fi

        read -p ">Press Enter<"
        echo "---------------------------------------"
    }

    : 折り返し表示実行 & {
        if [[ ${VIEW_COUNT} -eq 0 ]] ; then
            cat "${TARGET_FILE_WK}" \
            | sed -E "s/(.{${FOLD_LENGTH}})/\\1\\n/g"
        else
            cat "${TARGET_FILE_WK}" \
            | sed -E "s/(.{${FOLD_LENGTH}})/\\1\\n/g" \
            | sed -n ${comnd}
        fi
    }

    : 終了処理 & {
        echo "---------------------------------------"
    }
}


###################################################################
## ランディンポイント
###################################################################
: 設定と初期化 & {
    TARGET_FILE="$1"
    VIEW_MODE="$2"
    FOLD_LENGTH="$3"
    VIEW_COUNT_tmp="${4}"
    TMP_COUNT=0
    VIOLATION_COUNT=0
}

: 環境チェック & {
    localectl status | grep -Eq "LANG=ja_JP.UTF-8"
    if [[ ${?} -ne 0 ]]; then
        echo "警告: 環境のロケールが ja_JP.UTF-8 ではありません スクリプトを終了します。" >&2
        exit 1
    fi
}

: 引数チェック & {

    if [[ "${VIEW_MODE}" = 'V' ]] ; then
        ## 引数の形式
        if [[ ${VIEW_COUNT_tmp} =~ ^[0-9]+-[0-9]+$ ]] ; then
            echo "🚨 警告:禁則処理・その他修正必要箇所検出モードでは、引数4 (表示数) に範囲は指定できません" >&2
            exit 1
        fi
        if [[ ${VIEW_COUNT_tmp} -le 0 ]] ; then
            echo "🚨 警告:引数4 (表示数) は、1以上の正の整数である必要があります。 (指定された値: $VIEW_COUNT_tmp)" >&2
            exit 1
        fi
    fi

    if [[ ${VIEW_MODE} =~ [VF] ]] ; then
        ## 引数2が正の整数で100以下であるかのチェック
        if [[ ! ${FOLD_LENGTH} =~ ^[0-9]+$ ]] || [[ ${FOLD_LENGTH} -lt 0 ]] || [[ ${FOLD_LENGTH} -gt 100 ]] ; then
            echo "🚨 警告: 引数3 (折返し文字数) は、0から100までの正の整数である必要があります。 (指定された値: $FOLD_LENGTH)" >&2
            exit 1
        fi
    fi

    if [[ ${VIEW_MODE} =~ [VF] ]] ; then
        ## 引数2が正の整数で100以下であるかのチェック
        if [[ ! ${FOLD_LENGTH} =~ ^[0-9]+$ ]] || [[ ${FOLD_LENGTH} -lt 0 ]] || [[ ${FOLD_LENGTH} -gt 100 ]] ; then
            echo "🚨 警告: 引数3 (折返し文字数) は、0から100までの正の整数である必要があります。 (指定された値: $FOLD_LENGTH)" >&2
            exit 1
        fi
    fi

    ## 対象ファイルが存在し、読み取り可能か
    if [ ! -f "$TARGET_FILE" ] || [ ! -r "$TARGET_FILE" ]; then
        echo "🚨 警告: 対象ファイル '$TARGET_FILE' が存在しないか、読み取りできません。" >&2
        exit 1
    fi

    ## モードの選択
    if [[ ! ${VIEW_MODE} =~ [FV] ]]; then
        echo "🚨 警告: モードは F:折返確認 V:警告検出 のいずれかにしてください。 (指定された値: $VIEW_MODE)" >&2
        exit 1
    fi
}

: 内容チェック & {
    ## 対象ファイルは文字コードutf-8であるか
    ENCODING=$(file -i "${TARGET_FILE}" | grep -oP 'charset=[^;]*' | grep -oP "[uU][tT][fF]-*8")
    if [ "$ENCODING" != "utf-8" ]; then
        echo "🚨 警告: 対象ファイル ${TARGET_FILE} の文字コードはutf-8である必要があります。 (現在の文字コード: ${ENCODING})" >&2
        exit 1
    fi

    ## 対象ファイル内の改行コードはlfであるか
    if grep -q $'\\r' "${TARGET_FILE}"; then
        echo "🚨 警告: 対象ファイル ${TARGET_FILE} の改行コードはLFである必要があります。CRLFが含まれています。" >&2
        exit 1
    fi
}

cp "${TARGET_FILE}" "${TARGET_FILE}_wk"
TARGET_FILE_WK="${TARGET_FILE}_wk"

case "${VIEW_MODE}" in
    'F')    view_fold
            ;;
    'V')    view_violation
            ;;
    *  ) ;;
esac

# 正常終了したときに一時ファイルを削除する
trap do_exit EXIT