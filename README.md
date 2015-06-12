#<img src="http://tidwall.github.io/GoSwift/logo.png?raw=true" width="75" height="75">&nbsp;GoSwift - Go Goodies for Swift

Bring some of the more powerful features of Go to your iOS / Swift project such as channels, goroutines, and defers.

***Note: Swift 2 now includes the builtin `defer` keyword. At the moment GoSwift is not compatible with Swift 2.*** *A new version of GoSwift is in the works.*

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

##Example

*Note that the following example and all of the examples in the `examples` directory originated from http://gobyexample.com and Mark McGranaghan*

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
	var jobs = Chan<Int>(5)
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

###Run an Example

Each example has a `.swift` and `.go` file that contain the same logic.

```
./run.sh examples/goroutines.swift
./run.sh examples/goroutines.go
```

##Installation (iOS and OS X)

### [Carthage]

[Carthage]: https://github.com/Carthage/Carthage

Add the following to your Cartfile:

```
github "tidwall/GoSwift"
```

Then run `carthage update`.

Follow the current instructions in [Carthage's README][carthage-installation]
for up to date installation instructions.

[carthage-installation]: https://github.com/Carthage/Carthage#adding-frameworks-to-an-application

The `import GoSwift` directive is required in order to access GoSwift features.

### [CocoaPods]

[CocoaPods]: http://cocoapods.org

Add the following to your [Podfile](http://guides.cocoapods.org/using/the-podfile.html):

```ruby
use_frameworks!
pod 'GoSwift'
```

Then run `pod install` with CocoaPods 0.36 or newer.

The `import GoSwift` directive is required in order to access GoSwift features.

###Manually

Copy the `GoSwift\go.swift` file into your project.  

There is no need for `import GoSwift` when manually installing.


## Contact
Josh Baker [@tidwall](http://twitter.com/tidwall)

## License

The GoSwift source code available under the MIT License.

The Go source code in the `examples` directory is copyright Mark McGranaghan and licensed under a
[Creative Commons Attribution 3.0 Unported License](http://creativecommons.org/licenses/by/3.0/).

The Swift version of the example code is by Josh Baker
