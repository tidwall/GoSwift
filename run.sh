#!/bin/bash

set -e
cd $(dirname "${BASH_SOURCE[0]}")

if [[ "$@" == "" ]]; then 
	echo "usage: $0 [file (.swift | .go)]"
	echo ""
	echo "examples:"
	echo "       $0 examples/goroutines.swift"
	echo "       $0 examples/goroutines.go"
	exit -1
fi

f="$@"
ext=${f##*.}

if [[ "$ext" == "swift" ]]; then
	cat gokit.swift "$f" > /tmp/gokit-main.swift
	echo "" >> /tmp/gokit-main.swift
	echo "main()" >> /tmp/gokit-main.swift
	swift /tmp/gokit-main.swift
elif [[ "$ext" == "go" ]]; then
	GOMAXPROCS=4 go run "$f"
else 
	echo "$f: invalid file type"	
	exit -1
fi
