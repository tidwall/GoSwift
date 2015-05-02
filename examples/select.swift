// https://gobyexample.com/channel-buffering
// The original work is copyright Mark McGranaghan and licensed under a Creative Commons Attribution 3.0 Unported License.
// The swift port is by Josh Baker

// Go's _select_ lets you wait on multiple channel
// operations. Combining goroutines and channels with
// select is a powerful feature of Go.

func main() {

	// For our example we'll select across two channels.
	var c1 = Chan<String>()
	var c2 = Chan<String>()

	// Each channel will receive a value after some amount
	// of time, to simulate e.g. blocking RPC operations
	// executing in concurrent goroutines.
	go {
		NSThread.sleepForTimeInterval(1)
		c1 <- "one"
	}
	go {
		NSThread.sleepForTimeInterval(2)
		c2 <- "two"
	}

	// We'll use `select` to await both of these values
	// simultaneously, printing each one as it arrives.
	for var i = 0; i < 2; i++ {
		select {
			_case(c1) { (msg1, ok) in
				println("received \(msg1!)")
			}
			_case(c2) { (msg2, ok) in
				println("received \(msg2!)")
			}
		}
	}
}
