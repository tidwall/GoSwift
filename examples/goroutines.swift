// https://gobyexample.com/goroutines
// The original work is copyright Mark McGranaghan and licensed under a Creative Commons Attribution 3.0 Unported License.
// The swift port is by Josh Baker

// A _goroutine_ is a lightweight thread of execution.

func f(from : String) {
    for var i = 0; i < 3; i++ {
        println("\(from) : \(i)")
    }
}

func main() {

    // Suppose we have a function call `f(s)`. Here's how
    // we'd call that in the usual way, running it
    // synchronously.
    f("direct")

    // To invoke this function in a goroutine, use
    // `go f(s)`. This new goroutine will execute
    // concurrently with the calling one.
    go { f("goroutine") }

    // You can also start a goroutine for an anonymous
    // function call.
    go { { (msg : String) in
        println(msg)
    }("going") }

    // Our two function calls are running asynchronously in
    // separate goroutines now, so execution falls through
    // to here. This `Scanln` code requires we press a key
    // before the program exits.
    NSFileHandle.fileHandleWithStandardInput().availableData
    println("done")
}
