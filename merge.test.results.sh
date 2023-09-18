#!/bin/bash
for FILE in $(find . -name '*.csv')
do
	while read -r LINE
	do
		FNAME=$(basename $FILE)
		echo "$FNAME, $LINE" | sed 's/\.csv//g'
	done <$FILE
done

