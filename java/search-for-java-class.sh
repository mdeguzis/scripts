#!/bin/bash

# Searches jars on a given path for a given string

path="$1"
search_string="$2"

if [[ $1 == "-h" ]]; then

	cat<<- EOF

	Usage:
	./search-for-java-class.sh PATH SEARCH_STRING

	EOF
	exit

fi

main()
{
	echo -e "Searching jars under $path for $search_string\n"
	sudo find $path -name "*.jar" -exec echo {} \; -exec sh -c \
	"jar -tf {} | grep $search_string*.class" 2> /dev/null \; \
	| grep --color=always -B1 "\.class"
}

main
