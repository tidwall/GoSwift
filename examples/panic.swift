// https://gobyexample.com/channel-buffering
// The original work is copyright Mark McGranaghan and licensed under a Creative Commons Attribution 3.0 Unported License.
// The swift port is by Josh Baker

// A `panic` typically means something went unexpectedly
// wrong. Mostly we use it to fail fast on errors that
// shouldn't occur during normal operation, or that we
// aren't prepared to handle gracefully.

func main() {
	${  // ${} is required for 'defer', 'panic', 'recover'
		// We'll use panic throughout this site to check for
		// unexpected errors. This is the only program on the
		// site designed to panic.
		panic("a problem")

		// A common use of panic is to abort if a function
		// returns an error value that we don't know how to
		// (or want to) handle. Here's an example of
		// `panic`king if we get an unexpected error when creating a new file.
		var f = fopen("/tmp/file", "wb+")
		if f == nil {
			panic("file error")
		}
	}
}
