#GoSwift - Go Goodies for Swift

Bring some of the more powerful features of Go to your iOS / Swift project such as channels, goroutines, and defers.

##Features

- Goroutines
- Defer
- Panic, Recover
- Channels
	- Buffered Channels
	- Select, Case, Default
	- Closing
- Sync Package
	- Mutex, Cond, Once, WaitGroup
- Error type

##Install (iOS and OS X)

###CocoaPods

You can use [CocoaPods](http://cocoapods.org/?q=GoSwift) to install the `GoSwift` framework.

Add the following lines to your `Podfile`.

```ruby
use_frameworks!
pod 'GoSwift'
```

The `import GoSwift` directive is required in order to access GoSwift features.


###Manual

Just drop the `go.swift` file into your project.

There is no need for `import GoSwift` when manually installing.

##Run an Example

Using terminal clone this repository and enter the goswift directory.
Each example has a swift and go file that contain the same logic.

```
./run.sh examples/goroutines.swift
./run.sh examples/goroutines.go
```


##Example

*Note that the following example and all of the examples in the `example` directory originated from http://gobyexample.com and Mark McGranaghan*

**Go**

```go
package main

import "fmt"

func main() {
	jobs := make(chan int, 5)
	done := make(chan bool)

	go func() {
		for {
			j, more := <-jobs
			if more {
				fmt.Println("received job", j)
			} else {
				fmt.Println("received all jobs")
				done <- true
				return
			}
		}
	}()

	for j := 1; j <= 3; j++ {
		jobs <- j
		fmt.Println("sent job", j)
	}
	close(jobs)
	fmt.Println("sent all jobs")

	<-done
}
```

**Swift**

```swift
func main() {
	var jobs = Chan<Int>(buffer: 5)
	var done = Chan<Bool>()

	go {
		for ;; {
			var (j, more) = <?jobs
			if more {
				println("received job \(j!)")
			} else {
				println("received all jobs")
				done <- true
				return
			}
		}
	}

	for var j = 1; j <= 3; j++ {
		jobs <- j
		println("sent job \(j)")
	}
	close(jobs)
	println("sent all jobs")

	<-done
}

```

## Contact
Josh Baker [@tidwall](http://twitter.com/tidwall)

## License

The GoSwift source code available under the MIT License.

The Go source code in the `examples` directory is copyright Mark McGranaghan and licensed under a
[Creative Commons Attribution 3.0 Unported License](http://creativecommons.org/licenses/by/3.0/).

The Swift version of the example code is by Josh Baker
