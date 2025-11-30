#!/bin/bash

cp virtual-on.txt virtual-on2.txt

cat virtual-on2.txt | grep -oE '｜[^《]+《[^》]+》' | sed 's/[｜》]//g' | sed 's/《/\t/' > words.log

cat virtual-on2.txt | grep -oE '｜[^《]+《[^》]+》' | sed 's/[｜》]//g' | sed 's/《/\t/' | cut -f 1 | awk '{ print length($0) }' > base.log

cat virtual-on2.txt | grep -oE '｜[^《]+《[^》]+》' | sed 's/[｜》]//g' | sed 's/《/\t/' | cut -f 2 | awk '{ print int(length($0)/2)+1 }' > ruby.log

paste words.log base.log ruby.log | sort | uniq | while read line
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
			replace_to="${ruby_word_half}"
		fi
		sed -i "s/${replace_from}/${replace_to}/g" virtual-on2.txt
	done