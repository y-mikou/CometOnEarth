import re
import unicodedata
import sys
import argparse

# =================================================================
# ユーザー設定領域
# =================================================================
MAX_WIDTH_VALUE = 80      # 全角1文字=幅2 (40文字なら80)
MIN_LAST_LINE_WIDTH = 6   # 最終行の最小幅 (全角3文字分)

# 【重要】描画が半角に化けてしまう全角文字
FIX_WIDTH_CHARS = "｜―…“”‘’❤"

# 禁則文字設定
GYOTO_KINSHI = "、。）」』】〕〉》〉｝ー々ぁぃぅぇぉっゃゅょァィゥェォッャュョ゛゜"
GYOMATSU_KINSHI = "「『（【〔〈《〈｛"

# 強調表示設定
MARK = "\033[7m" #表示を反転する
RESET = "\033[0m"
# =================================================================

# 文字幅取得関数(異体字セレクタ・合成文字に対応。必要があれば追加してください)
def get_char_width(char):
    code = ord(char)
    if 0xFE00 <= code <= 0xFE0F or 0x0300 <= code <= 0x036F:
        return 0
    if char in "❤✨☀☁☂☃☄★☆": #必要があれば追加してください
        return 2
    status = unicodedata.east_asian_width(char)
    if status in "FWA":
        return 2
    return 1

# 段落解析関数
## ルビタグや見出し・脚注タグの除去とルビ情報の抽出
def analyze_paragraph(text):
    text = re.sub(r'^#+\s*', '', text)
    text = re.sub(r'\s+\[[^\]]+\]\s*$', '', text)
    text = re.sub(r'《《(.+?)》》', r'\1', text)
    display_text = ""
    ruby_items = []
    pattern = re.compile(r'｜([^《》\s]+)《([^》]+)》')
    last_end = 0
    for m in pattern.finditer(text):
        display_text += text[last_end:m.start()]
        start_idx = len(display_text)
        display_text += m.group(1)
        ruby_items.append((start_idx, len(display_text)-1, len(m.group(2))))
        last_end = m.end()
    display_text += text[last_end:]
    return display_text, ruby_items

# シミュレーション実行関数
def run_simulation(raw_line):
    display_text, ruby_items = analyze_paragraph(raw_line)
    if not display_text.strip():
        return None
    char_sim = []
    current_w = 0
    line_count = 0
    for i, char in enumerate(display_text):
        if char in "゛゜" and i > 0:
            w = 0
        else:
            w = get_char_width(char)
        if current_w + w > MAX_WIDTH_VALUE:
            current_w = 0
            line_count += 1
        char_sim.append({
            'char': char, 'width': w, 'line': line_count, 'pos': current_w, 'error': False, 'is_invisible': (w == 0)
        })
        current_w += w
    
    # 最終行僅少フラグの付与
    if line_count > 0:
        last_line_chars = [c for c in char_sim if c['line'] == line_count]
        last_line_w = sum(c['width'] for c in last_line_chars)
        if last_line_w <= MIN_LAST_LINE_WIDTH:
            for c in last_line_chars:
                c['error'] = True # 全文字をエラー扱いにして強調対象にする

    # ルビ・禁則エラー
    for s_idx, e_idx, ruby_w in ruby_items:
        if s_idx >= len(char_sim) or e_idx >= len(char_sim): continue
        s, e = char_sim[s_idx], char_sim[e_idx]
        if s['line'] != e['line'] or s['pos'] + ruby_w > MAX_WIDTH_VALUE:
            for idx in range(s_idx, e_idx + 1): char_sim[idx]['error'] = True
    for i in range(1, len(char_sim)):
        curr, prev = char_sim[i], char_sim[i-1]
        if curr['line'] != prev['line']:
            if curr['char'] in GYOTO_KINSHI: curr['error'] = True
            if prev['char'] in GYOMATSU_KINSHI: prev['error'] = True
    return char_sim, line_count

# チェックモード関数
def check_mode(file_path):
    print(f"🔍️ 禁則・文字数チェック開始 (幅:全角{MAX_WIDTH_VALUE}文字)")
    with open(file_path, 'r', encoding='utf-8') as f:
        for line_num, line in enumerate(f, 1):
            raw_line = line.rstrip('\n')
            res = run_simulation(raw_line)
            if not res: continue
            char_sim, line_count = res
            
            error_reported = False

            # 最終行僅少の判定（run_simulationでerrorフラグ付与済みだがメッセージ用）
            if line_count > 0:
                last_line_w = sum(c['width'] for c in char_sim if c['line'] == line_count)
                if last_line_w <= MIN_LAST_LINE_WIDTH:
                    print(f"L{line_num:4}: 【最終行僅少】 第{line_count+1}折返行が3文字以下です。")
                    error_reported = True

            lines_map = {}
            for c in char_sim: lines_map.setdefault(c['line'], []).append(c)
            for l_idx in sorted(lines_map.keys()):
                if error_reported: break
                chars = lines_map[l_idx]
                h_count = sum(1 for c in chars if c['width'] == 1)
                if h_count % 2 != 0:
                    print(f"L{line_num:4}: 【半角奇数】 第{l_idx+1}折返行に半角が{h_count}文字あります。")
                    error_reported = True
                    continue
                if any(c['error'] for c in chars):
                    if chars[0]['error'] and chars[0]['char'] in GYOTO_KINSHI:
                        print(f"L{line_num:4}: 【行頭禁則】 「{chars[0]['char']}」が第{l_idx+1}折返行の先頭です。")
                    elif chars[-1]['error'] and chars[-1]['char'] in GYOMATSU_KINSHI:
                        print(f"L{line_num:4}: 【行末禁則】 「{chars[-1]['char']}」が第{l_idx+1}折返行の末尾です。")
                    else:
                        print(f"L{line_num:4}: 【ルビ/親文字/構成エラー】 第{l_idx+1}折返行付近を確認。")
                    error_reported = True

# レイアウトプレビューモード関数
def view_mode(file_path):
    print(f"📝 簡易レイアウトプレビュー (幅: 全角{MAX_WIDTH_VALUE//2}文字)")
    print(" " * 6 + "＋" + "ー" * (MAX_WIDTH_VALUE // 2) + "＋")
    with open(file_path, 'r', encoding='utf-8') as f:
        for line_num, line in enumerate(f, 1):
            raw_line = line.rstrip('\n')
            if not raw_line:
                print(f"{line_num:4}: ｜" + "　" * (MAX_WIDTH_VALUE // 2) + "｜")
                continue
            res = run_simulation(raw_line)
            if not res: continue
            char_sim, _ = res
            
            has_marked_error = False
            current_p_line = 0
            prefix = f"{line_num:4}: ｜"
            output = prefix
            w_acc = 0
            
            for i, c in enumerate(char_sim):
                if c['line'] != current_p_line:
                    rem = MAX_WIDTH_VALUE - w_acc
                    output += "　" * (rem // 2) + (" " if rem % 2 != 0 else "")
                    print(output + "｜")
                    output, w_acc, current_p_line = "      ｜", 0, c['line']
                
                if c['is_invisible']: continue
                char_str = c['char']
                if char_str in FIX_WIDTH_CHARS: char_str += " "
                
                if c['error'] and not has_marked_error:
                    char_str = f"{MARK}{char_str}{RESET}"
                    if i + 1 < len(char_sim):
                        if not char_sim[i+1]['error']:
                            has_marked_error = True
                    else:
                        has_marked_error = True
                
                output += char_str
                w_acc += c['width']
            
            rem = MAX_WIDTH_VALUE - w_acc
            output += "　" * (rem // 2) + (" " if rem % 2 != 0 else "")
            print(output + "｜")
    print(" " * 6 + "＋" + "ー" * (MAX_WIDTH_VALUE // 2) + "＋")

if __name__ == "__main__":
    parser = argparse.ArgumentParser(description="日本原稿修正箇所候補検出ツール")
    parser.add_argument("file", help="対象のテキストファイルパスを指定してください。")
    group = parser.add_mutually_exclusive_group(required=True)
    group.add_argument("-c", "--check 修正候補を列挙します", action="store_true", dest="mode_check")
    group.add_argument("-v", "--view 簡易プレビューを表示し、修正候補をマークします", action="store_true", dest="mode_check")
    args = parser.parse_args()
    try:
        if args.mode_check:
            check_mode(args.file)
        elif args.mode_view:
            view_mode(args.file)
    except FileNotFoundError:
        print(f"💩 エラー: ファイル '{args.file}' が見つかりません")
    except Exception as e:
        print(f"An error occurred: {e}")