import re
import unicodedata
import sys

# --- ページ設定 ---
MAX_WIDTH_VALUE = 80  # 全角1文字=幅2。
MIN_LAST_LINE_WIDTH = 6 # 最終行の許容最小幅 (全角3文字分 = 6)

GYOTO_KINSHI = "、。）」』】〕〉》〉｝ー々ぁぃぅぇぉっゃゅょァィゥェォッャュョ"
GYOMATSU_KINSHI = "「『（【〔〈《〈｛"

def get_char_width(char):
    return 2 if unicodedata.east_asian_width(char) in "FWA" else 1

def analyze_paragraph(text):
    """
    段落を解析し、表示用文字列の生成とルビ情報の抽出を行う。
    """
    # 1. 行頭の連続する「#」とその後の空白を削除
    text = re.sub(r'^#+\s*', '', text)
    
    # 2. 行末の [メタ情報] を削除
    text = re.sub(r'\s+\[[^\]]+\]\s*$', '', text)
    
    display_text = ""  # 印刷時に表示される全文字列
    ruby_items = []    # ルビ情報の格納用リスト
    
    # ｜親文字《ルビ》 形式を正規表現で検索
    pattern = re.compile(r'｜([^《》\s]+)《([^》]+)》')
    
    last_end = 0  
    for m in pattern.finditer(text):
        # 前回のマッチから今回のマッチまでの本文を結合
        display_text += text[last_end:m.start()]
        
        parent = m.group(1) # 親文字
        ruby = m.group(2)   # ルビ
        
        # 表示文字列における親文字の開始・終了位置を記録
        start_idx = len(display_text)
        display_text += parent
        end_idx = len(display_text) - 1
        
        # (開始idx, 終了idx, ルビ文字数)を保存
        ruby_items.append((start_idx, end_idx, len(ruby)))
        last_end = m.end()
    
    # 残っている文字列を結合
    display_text += text[last_end:]
    return display_text, ruby_items

def check_paragraph(line_num, raw_line):
    display_text, ruby_items = analyze_paragraph(raw_line)
    if not display_text.strip():
        return None

    char_coords = []
    current_line_width = 0
    line_count = 0
    
    # 文字幅シミュレーション（濁点結合対応）
    for i in range(len(display_text)):
        char = display_text[i]
        if char in "゛゜" and i > 0:
            char_w = 0
        else:
            char_w = get_char_width(char)

        if current_line_width + char_w > MAX_WIDTH_VALUE:
            current_line_width = 0
            line_count += 1
        
        char_coords.append({
            'char': char, 'width': char_w, 'pos': current_line_width, 'line': line_count
        })
        current_line_width += char_w

    # 1. 親文字割れ ＆ ルビ突き抜けチェック
    for s_idx, e_idx, ruby_w in ruby_items:
        if s_idx >= len(char_coords) or e_idx >= len(char_coords): continue
        s, e = char_coords[s_idx], char_coords[e_idx]
        if s['line'] != e['line']:
            return f"L{line_num:4}: 【親文字割れ】 親文字が改行を跨いでいます。"
        if s['pos'] + ruby_w > MAX_WIDTH_VALUE:
            return f"L{line_num:4}: 【ルビ突き抜け】 ルビ({ruby_w}文字幅)が右端を超過。"

    lines_map = {}
    for c in char_coords:
        lines_map.setdefault(c['line'], []).append(c)

    # 2. 段落全体の構造チェック
    # --- 最終行の短さチェック ---
    if line_count > 0: # 複数行にわたる段落のみ
        last_line_chars = lines_map[line_count]
        last_line_total_width = sum(c['width'] for c in last_line_chars)
        if last_line_total_width <= MIN_LAST_LINE_WIDTH:
            return f"L{line_num:4}: 【最終行僅少】 最終(第{line_count+1}折返行)が3文字以下です。"

    # 3. 各折返行の禁則・半角チェック
    for l_idx in sorted(lines_map.keys()):
        chars_in_line = lines_map[l_idx]
        orikaeshi_num = l_idx + 1
        
        half_width_count = sum(1 for c in chars_in_line if c['width'] == 1)
        if half_width_count % 2 != 0:
            sample = "".join([c['char'] for c in chars_in_line[:10]])
            return f"L{line_num:4}: 【半角奇数】 第{orikaeshi_num}折返行に半角が{half_width_count}文字あります。 周辺: {sample}..."

        first_char = chars_in_line[0]
        if l_idx > 0 and first_char['char'] in GYOTO_KINSHI:
            return f"L{line_num:4}: 【行頭禁則】 「{first_char['char']}」が第{orikaeshi_num}折返行の先頭です。"
        
        last_char = chars_in_line[-1]
        if l_idx < line_count:
            if last_char['char'] in GYOMATSU_KINSHI:
                return f"L{line_num:4}: 【行末禁則】 「{last_char['char']}」が第{orikaeshi_num}折返行の末尾です。"

    return None

def main():
    if len(sys.argv) < 2:
        print("Usage: python script.py target.txt")
        return
    print(f"警告の出そうな箇所を検知します (1行幅:{MAX_WIDTH_VALUE}) ")
    try:
        with open(sys.argv[1], 'r', encoding='utf-8') as f:
            for idx, line in enumerate(f, 1):
                res = check_paragraph(idx, line.rstrip('\n'))
                if res:
                    print(res)
    except Exception as e:
        print(f"Error: {e}")

if __name__ == "__main__":
    main()