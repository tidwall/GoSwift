// https://gobyexample.com/channel-buffering
// The original work is copyright Mark McGranaghan and licensed under a Creative Commons Attribution 3.0 Unported License.
// The swift port is by Josh Baker

// By default channels are _unbuffered_, meaning that they
// will only accept sends (`chan <-`) if there is a
// corresponding receive (`<- chan`) ready to receive the
// sent value. _Buffered channels_ accept a limited
// number of  values without a corresponding receiver for
// those values.

func main() {

	// Here we `make` a channel of strings buffering up to
	// 2 values.
	var messages = Chan<String>(buffer: 2)

	// Because this channel is buffered, we can send these
	// values into the channel without a corresponding
	// concurrent receive.
	messages <- "buffered"
	messages <- "channel"

	// Later we can receive these two values as usual.
	println((<-messages)!)
	println((<-messages)!)
}
