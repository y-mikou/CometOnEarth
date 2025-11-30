#!/bin/bash

localectl status | grep -Eq "LANG=ja_JP.UTF-8"
if [[ ${?} -ne 0 ]]; then
	echo "警告: 環境のロケールが ja_JP.UTF-8 ではありません スクリプトを終了します。" >&2
	exit 1
fi

cp virtual-on.txt virtual-on2.txt

sed -i 's/《《\([^》]*\)》》/\1/g' virtual-on2.txt

cat virtual-on2.txt | grep -oE '｜[^《]+《[^》]+》' | sed 's/[｜》]//g' | sed 's/《/\t/' > words.log

# cat virtual-on2.txt | grep -oE '｜[^《]+《[^》]+》' | sed 's/[｜》]//g' | sed 's/《/\t/' | cut -f 1  > base.log
# cat virtual-on2.txt | grep -oE '｜[^《]+《[^》]+》' | sed 's/[｜》]//g' | sed 's/《/\t/' | cut -f 2  > ruby.log

cat virtual-on2.txt | grep -oE '｜[^《]+《[^》]+》' | sed 's/[｜》]//g' | sed 's/《/\t/' | cut -f 1 | awk '{ print length($0) }' > base_count.log

cat virtual-on2.txt | grep -oE '｜[^《]+《[^》]+》' | sed 's/[｜》]//g' | sed 's/《/\t/' | cut -f 2 | awk '{ print length($0) }' > ruby_count.log

paste words.log base_count.log ruby_count.log | sort | uniq | while read line
	do
		base_word=$(echo $line | cut -d' ' -f 1)		
		ruby_word=$(echo $line | cut -d' ' -f 2)
		base_word_count=$(echo $line | cut -d' ' -f 3)
		ruby_word_count=$(echo $line | cut -d' ' -f 4)
		ruby_word_half=${ruby_word:0:(( (${#ruby_word} + 2 - 1) / 2 ))}
		# echo "${ruby_word}/${ruby_word_half}"
		replace_from="｜${base_word}《${ruby_word}》"
		if [[ ${base_word_count} -ge ${ruby_word_count} ]] ; then
			replace_to="${base_word}"
		else
			replace_to=$( echo ${base_word} | sed "s/./■/g" )
		fi
		sed -i "s/${replace_from}/${replace_to}/g" virtual-on2.txt

	done