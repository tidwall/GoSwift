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
	cat goswift.swift > /tmp/goswift-main.swift
	echo "private var printmut = Mutex();func print(value: Any){printmut.lock {\"\\(value)\".writeToFile(\"/dev/stdout\", atomically:false, encoding:NSUTF8StringEncoding, error:nil)}}" >> /tmp/goswift-main.swift
	echo "func println(value: Any){print(\"\\(value)\\n\")}" >> /tmp/goswift-main.swift
	cat "$f" >> /tmp/goswift-main.swift
	echo "" >> /tmp/goswift-main.swift
	echo "main()" >> /tmp/goswift-main.swift
	swift /tmp/goswift-main.swift
elif [[ "$ext" == "go" ]]; then
	GOMAXPROCS=4 go run "$f"
else 
	echo "$f: invalid file type"	
	exit -1
fi
