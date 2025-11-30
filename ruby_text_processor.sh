#!/bin/bash

# ファイル単位でルビを処理して標準出力に結果を出す
process_ruby_text_file() {
    local input_file="$1"

    if [[ -z "$input_file" ]]; then
        echo "使用法: $0 <入力ファイル>" >&2
        return 1
    fi
    if [[ ! -f "$input_file" ]]; then
        echo "エラー: ファイル '$input_file' が見つかりません" >&2
        return 1
    fi

    local content
    content=$(cat "$input_file")
    local output=""
    local i=0

    while [[ $i -lt ${#content} ]]; do
        if [[ "${content:$i:1}" == "｜" ]]; then
            i=$((i + 1))
            local parent_text=""
            while [[ $i -lt ${#content} ]] && [[ "${content:$i:1}" != "《" ]]; do
                parent_text+="${content:$i:1}"
                i=$((i + 1))
            done

            if [[ "${content:$i:1}" != "《" ]]; then
                output+="$parent_text"
            else
                i=$((i + 1))
                local ruby_text=""
                while [[ $i -lt ${#content} ]] && [[ "${content:$i:1}" != "》" ]]; do
                    ruby_text+="${content:$i:1}"
                    i=$((i + 1))
                done
                if [[ "${content:$i:1}" == "》" ]]; then
                    i=$((i + 1))
                fi

                if [[ -z "$parent_text" && -z "$ruby_text" ]]; then
                    :
                elif [[ -z "$parent_text" ]]; then
                    local ruby_len=${#ruby_text}
                    local keep=$(( (ruby_len + 1) / 2 ))
                    output+="${ruby_text:0:keep}"
                elif [[ -z "$ruby_text" ]]; then
                    output+="$parent_text"
                else
                    local parent_len=$((${#parent_text} * 2))
                    local ruby_len=${#ruby_text}
                    if [[ $parent_len -ge $ruby_len ]]; then
                        output+="$parent_text"
                    else
                        local keep=$(( (ruby_len + 1) / 2 ))
                        output+="${ruby_text:0:keep}"
                    fi
                fi
            fi
        else
            output+="${content:$i:1}"
            i=$((i + 1))
        fi
    done

    printf "%s" "$output"
}

# メイン: ファイルのみ受け付け、結果は標準出力
if [[ $# -ne 1 ]]; then
    echo "使用法: $0 <入力ファイル>" >&2
    exit 1
fi

if [[ -f "$1" ]]; then
    process_ruby_text_file "$1"
else
    echo "エラー: ファイル '$1' が見つかりません" >&2
    exit 1
fi
