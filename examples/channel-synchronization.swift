// https://gobyexample.com/channel-synchronization
// The original work is copyright Mark McGranaghan and licensed under a Creative Commons Attribution 3.0 Unported License.
// The swift port is by Josh Baker

// We can use channels to synchronize execution
// across goroutines. Here's an example of using a
// blocking receive to wait for a goroutine to finish.

// This is the function we'll run in a goroutine. The
// `done` channel will be used to notify another
// goroutine that this function's work is done.
func worker(done : Chan<Bool>) {
	print("working...")
	NSThread.sleepForTimeInterval(1)
	println("done")

	// Send a value to notify that we're done.
	done <- true
}

func main() {

	// Start a worker goroutine, giving it the channel to
	// notify on.
	var done = Chan<Bool>(buffer: 1)
	go { worker(done) }

	// Block until we receive a notification from the
	// worker on the channel.
	<-done
}
