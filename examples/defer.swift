// https://gobyexample.com/channel-buffering
// The original work is copyright Mark McGranaghan and licensed under a Creative Commons Attribution 3.0 Unported License.
// The swift port is by Josh Baker

// _Defer_ is used to ensure that a function call is
// performed later in a program's execution, usually for
// purposes of cleanup. `defer` is often used where e.g.
// `ensure` and `finally` would be used in other languages.

// Suppose we wanted to create a file, write to it,
// and then close when we're done. Here's how we could
// do that with `defer`.
func main() {
	let f = createFile("/tmp/defer.txt")
	defer { closeFile(f) }
	writeFile(f)
}

func createFile(p : String) -> UnsafeMutablePointer<FILE> {
	println("creating")
	let f = fopen(p, "wb+")
	if f == nil {
		panic("file error")
	}
	return f
}

func writeFile(f : UnsafeMutablePointer<FILE>) {
	println("writing")
	// fprintf(f, "data") // fprintf not available in swift
}

func closeFile(f : UnsafeMutablePointer<FILE>) {
	println("closing")
	fclose(f)
}
