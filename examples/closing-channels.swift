// https://gobyexample.com/channel-buffering
// The original work is copyright Mark McGranaghan and licensed under a Creative Commons Attribution 3.0 Unported License.
// The swift port is by Josh Baker

// _Closing_ a channel indicates that no more values
// will be sent on it. This can be useful to communicate
// completion to the channel's receivers.

// In this example we'll use a `jobs` channel to
// communicate work to be done from the `main()` goroutine
// to a worker goroutine. When we have no more jobs for
// the worker we'll `close` the `jobs` channel.
func main() {
	let jobs = Chan<Int>(5)
	let done = Chan<Bool>()

	// Here's the worker goroutine. It repeatedly receives
	// from `jobs` with `j, more := <-jobs`. In this
	// special 2-value form of receive, the `more` value
	// will be `false` if `jobs` has been `close`d and all
	// values in the channel have already been received.
	// We use this to notify on `done` when we've worked
	// all our jobs.
	go {
		for ;; {
			let (j, more) = <?jobs
			if more {
				println("received job \(j!)")
			} else {
				println("received all jobs")
				done <- true
				return
			}
		}
	}

	// This sends 3 jobs to the worker over the `jobs`
	// channel, then closes it.
	for var j = 1; j <= 3; j++ {
		jobs <- j
		println("sent job \(j)")
	}
	close(jobs)
	println("sent all jobs")

	// We await the worker using the
	// [synchronization](channel-synchronization) approach
	// we saw earlier.
	<-done
}
