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
	cat GoSwift/go.swift > /tmp/go-main.swift
	echo "private var printmut = Mutex();func print(value: Any){printmut.lock {\"\\(value)\".writeToFile(\"/dev/stdout\", atomically:false, encoding:NSUTF8StringEncoding, error:nil)}}" >> /tmp/go-main.swift
	echo "func println(value: Any){print(\"\\(value)\\n\")}" >> /tmp/go-main.swift
	cat "$f" >> /tmp/go-main.swift
	echo "" >> /tmp/go-main.swift
	echo "main()" >> /tmp/go-main.swift
	swift /tmp/go-main.swift
elif [[ "$ext" == "go" ]]; then
	GOMAXPROCS=4 go run "$f"
else 
	echo "$f: invalid file type"	
	exit -1
fi
