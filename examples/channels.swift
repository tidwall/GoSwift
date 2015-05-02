// https://gobyexample.com/channels
// The original work is copyright Mark McGranaghan and licensed under a Creative Commons Attribution 3.0 Unported License.
// The swift port is by Josh Baker

// _Channels_ are the pipes that connect concurrent
// goroutines. You can send values into channels from one
// goroutine and receive those values into another
// goroutine.

func main() {

	// Create a new channel with `make(chan val-type)`.
	// Channels are typed by the values they convey.
	var messages = Chan<String>()

	// _Send_ a value into a channel using the `channel <-`
	// syntax. Here we send `"ping"`  to the `messages`
	// channel we made above, from a new goroutine.
	go { messages <- "ping" }

	// The `<-channel` syntax _receives_ a value from the
	// channel. Here we'll receive the `"ping"` message
	// we sent above and print it out.
	var msg = <-messages
	println(msg!)
}
