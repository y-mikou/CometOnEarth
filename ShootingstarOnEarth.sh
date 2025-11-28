#!/bin/bash

# --- 設定と初期化 ---
TARGET_FILE="$1"
FOLD_LENGTH="$2"
TEMP_FILE=$(mktemp) # 中間ファイル
CURRENT_LOCALE=""
MAX_VIOLATIONS=10 # 最大検出数

# ANSIエスケープコードによる色の設定
# 赤色で強調
HIGHLIGHT_START='\033[31m'
HIGHLIGHT_END='\033[0m'
VIOLATION_COUNT=0 # 検出カウンター

# 終了時の処理 (クリーンアップとロケール復元)
cleanup() {
    rm -f "$TEMP_FILE"
    if [ -n "$CURRENT_LOCALE" ] && [ "$CURRENT_LOCALE" != "$(locale -a | grep -i '^ja_jp.utf8$')" ]; then
        export LC_ALL="$CURRENT_LOCALE"
    fi
}
trap cleanup EXIT

# --- 1. 引数のチェック (変更なし) ---
## 引数2が正の整数で100以下であるかのチェック
if ! [[ "$FOLD_LENGTH" =~ ^[0-9]+$ ]] || [ "$FOLD_LENGTH" -le 0 ] || [ "$FOLD_LENGTH" -gt 100 ]; then
    echo "🚨 警告: 引数2 (折返し文字数) は、1から100までの正の整数である必要があります。 (指定された値: $FOLD_LENGTH)" >&2
    exit 1
fi

## 対象ファイルが存在し、読み取り可能か
if [ ! -f "$TARGET_FILE" ] || [ ! -r "$TARGET_FILE" ]; then
    echo "🚨 警告: 対象ファイル '$TARGET_FILE' が存在しないか、読み取りできません。" >&2
    exit 1
fi

## 対象ファイルは文字コードutf-8であるか
ENCODING=$(file -i "$TARGET_FILE" | grep -oP 'charset=\K[^;]*')
if [ "$ENCODING" != "utf-8" ]; then
    echo "🚨 警告: 対象ファイル '$TARGET_FILE' の文字コードはutf-8である必要があります。 (現在の文字コード: $ENCODING)" >&2
    exit 1
fi

## 対象ファイル内の改行コードはlfであるか
if grep -q $'\r' "$TARGET_FILE"; then
    echo "🚨 警告: 対象ファイル '$TARGET_FILE' の改行コードはLFである必要があります。CRLFが含まれています。" >&2
    exit 1
fi


# --- 2. ロケール管理 (変更なし) ---
if ! locale | grep -q 'LC_ALL\|LANG' | grep -i -q 'ja_jp.utf8'; then
    CURRENT_LOCALE="${LC_ALL:-${LANG}}"
    if locale -a | grep -i -q '^ja_jp.utf8$'; then
        export LC_ALL="ja_JP.UTF-8"
    else
        echo "⚠️ 注意: ja_JP.UTF-8ロケールが見つかりません。文字数カウントに影響が出る可能性があります。" >&2
    fi
fi


# --- 3. 折り返し処理と中間ファイル出力 (変更なし) ---
echo "⚙️ テキストを${FOLD_LENGTH}文字ごとに折り返して処理中..."
while IFS= read -r line; do
    echo "$line" | grep -oE ".{1,${FOLD_LENGTH}}" | sed '$!s/$/\n/'
done < "$TARGET_FILE" > "$TEMP_FILE"


# --- 4. 禁則処理/修正候補チェック ---
echo "🔎 禁則処理/修正候補箇所をチェック中..."

while IFS= read -r line; do
    # 現在の行の文字数を取得 (改行文字を除く)
    LINE_LENGTH=$(echo "$line" | wc -m)
    ACTUAL_LENGTH=$((LINE_LENGTH - 1))
    
    IS_VIOLATION=false

    # 4-1. 禁則処理候補: 行の頭が「、」「。」「」」「）」「』」「〟」いずれかだった場合
    if echo "$line" | grep -qE '^[,。）」』〟]'; then
        # 条件を満たす箇所の文字色を変更して目立たせる
        FIRST_CHAR=$(echo "$line" | head -c 1)
        REST_OF_LINE=$(echo "$line" | tail -c +2)
        
        echo "❌ **禁則処理候補**: 行頭が句読点/閉じ括弧です。"
        echo "   行内容: ${HIGHLIGHT_START}${FIRST_CHAR}${HIGHLIGHT_END}${REST_OF_LINE}"
        
        IS_VIOLATION=true

    # 4-2. 修正候補: 行の長さが2文字以下の場合
    elif [ "$ACTUAL_LENGTH" -le 2 ]; then
        
        echo "💡 **修正候補箇所**: 行の長さが2文字以下です。 ($ACTUAL_LENGTH 文字)"
        echo "   行内容: $line"
        
        IS_VIOLATION=true
    fi
    
    # 候補が見つかった場合の処理
    if $IS_VIOLATION; then
        VIOLATION_COUNT=$((VIOLATION_COUNT + 1))
        
        # 検出数が上限に達したかチェック
        if [ "$VIOLATION_COUNT" -ge "$MAX_VIOLATIONS" ]; then
            echo "---"
            echo "🛑 検出数が上限の${MAX_VIOLATIONS}個に達しました。"
            echo "⚠️ **禁則処理候補もしくは修正候補箇所あり**としてスクリプトを終了します。"
            exit 1
        fi
    fi

done < "$TEMP_FILE"

# --- 5. 終了処理 ---
echo "---"
if [ "$VIOLATION_COUNT" -gt 0 ]; then
    echo "⚠️ **禁則処理候補もしくは修正候補箇所あり** (${VIOLATION_COUNT}個検出) としてスクリプトを終了します。"
    exit 1
else
    echo "✅ **禁則処理候補箇所なし、修正候補箇所なし**としてスクリプトを終了します
