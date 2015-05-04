/*
* GoKit (gokit.swift)
*
* Copyright (C) 2015 ONcast, LLC. All Rights Reserved.
* Created by Josh Baker (joshbaker77@gmail.com)
*
* This software may be modified and distributed under the terms
* of the MIT license.  See the LICENSE file for details.
*
*/

import Foundation

private let pt_entry: @objc_block (UnsafeMutablePointer<Void>) -> UnsafeMutablePointer<Void> = { (ctx) in
    let np = UnsafeMutablePointer<()->()>(ctx)
    np.memory()
    np.destroy()
    np.dealloc(1)
    return nil
}
private var pt_entry_imp = imp_implementationWithBlock(unsafeBitCast(pt_entry, AnyObject.self))
private let pt_entry_fp = CFunctionPointer<(UnsafeMutablePointer<Void>) -> UnsafeMutablePointer<Void>>(pt_entry_imp)
func dispatch_thread(block : ()->()){
    let p = UnsafeMutablePointer<()->()>.alloc(1)
    p.initialize(block)
    var t = pthread_t()
    pthread_create(&t, nil, pt_entry_fp, p)
}
protocol Locker {
    func lock()
    func unlock()
}
class Mutex : Locker {
    private var mutex = pthread_mutex_t()
    init(){
        pthread_mutex_init(&mutex, nil)
    }
    deinit{
        pthread_mutex_destroy(&mutex)
    }
    func lock(){
        pthread_mutex_lock(&mutex)
    }
    func unlock(){
        pthread_mutex_unlock(&mutex)
    }
    func lock(closure:()->()){
        lock()
        closure()
        unlock()
    }
}
class Cond {
    private var cond = pthread_cond_t()
    private var mutex : Mutex
    init(locker : Locker){
        if let m = locker as? Mutex{
            self.mutex = m
        } else {
            fatalError("Locker must be a Mutex (for now at least)")
        }
        pthread_cond_init(&cond, nil)
    }
    var locker : Locker {
        return mutex
    }
    
    deinit {
        pthread_cond_destroy(&cond)
    }
    func broadcast(){
        pthread_cond_broadcast(&cond)
    }
    func signal(){
        pthread_cond_signal(&cond)
    }
    func wait(){
        pthread_cond_wait(&cond, &mutex.mutex)
    }
}
class Once {
    private var mutex = Mutex()
    private var oncer = false
    func doit(closure:()->()){
        mutex.lock()
        if oncer{
            mutex.unlock()
            return
        }
        oncer = true
        closure()
        mutex.unlock()
    }
}
class WaitGroup {
    private var cond = Cond(locker: Mutex())
    private var count = 0
    func add(delta : Int){
        cond.locker.lock()
        count += delta
        if count < 0 {
            fatalError("sync: negative WaitGroup counter")
        }
        cond.broadcast()
        cond.locker.unlock()
    }
    func done(){
        add(-1)
    }
    func wait(){
        cond.locker.lock()
        while count > 0 {
            cond.wait()
        }
        cond.locker.unlock()
    }
}
protocol ChanAny {
    func receive(wait : Bool, mutex : Mutex?, inout flag : Bool) -> (msg : Any?, ok : Bool, ready : Bool)
    func send(msg : Any?)
    func close()
    func signal()
}
class Chan<T> : ChanAny {
    private var msgs = [Any?]()
    private var cap = 0
    private var cond = Cond(locker: Mutex())
    private var closed = false
    
    convenience init(){
        self.init(buffer: 0)
    }
    init(buffer: Int){
        cap = buffer
    }
    func close(){
        cond.locker.lock()
        if !closed {
            closed = true
            cond.broadcast()
        }
        cond.locker.unlock()
    }
    func send(msg: Any?) {
        cond.locker.lock()
        if closed {
            cond.locker.unlock()
            fatalError("send on closed channel")
        }
        msgs.append(msg)
        cond.broadcast()
        while msgs.count > cap {
            cond.wait()
        }
        cond.locker.unlock()
    }
    func receive(wait : Bool, mutex : Mutex?, inout flag : Bool) -> (msg : Any?, ok : Bool, ready : Bool) {
        // Peek
        if !wait {
            cond.locker.lock()
            if closed {
                cond.locker.unlock()
                return (nil, false, true)
            }
            if msgs.count == 0 {
                cond.locker.unlock()
                return (nil, true, false)
            }
            var msg = msgs.removeAtIndex(0)
            cond.broadcast()
            cond.locker.unlock()
            return (msg, true, true)
        }
        // SharedWait
        if mutex != nil {
            cond.locker.lock()
            for ;; {
                mutex!.lock()
                if flag {
                    mutex!.unlock()
                    cond.locker.unlock()
                    return (nil, true, false)
                }
                if closed {
                    flag = true
                    mutex!.unlock()
                    cond.locker.unlock()
                    return (nil, false, true)
                }
                if msgs.count > 0 {
                    flag = true
                    mutex!.unlock()
                    var msg = msgs.removeAtIndex(0)
                    cond.broadcast()
                    cond.locker.unlock()
                    return (msg, true, true)
                }
                mutex!.unlock()
                cond.wait()
            }
        }
        // StandardWait
        cond.locker.lock()
        for ;; {
            if closed {
                cond.locker.unlock()
                return (nil, false, true)
            }
            if msgs.count > 0 {
                var msg = msgs.removeAtIndex(0)
                cond.broadcast()
                cond.locker.unlock()
                return (msg, true, true)
            }
            cond.wait()
        }
    }
    func signal(){
        cond.broadcast()
    }
}
infix operator <- { associativity right precedence 155 }
prefix operator <- { }
prefix operator <? { }
func <-<T>(l: Chan<T>, r: T?){
    l.send(r)
}
prefix func <?<T>(r: Chan<T>) -> (T?, Bool){
    var flag = false
    let (v, ok, ready) = r.receive(true, mutex: nil, flag: &flag)
    return (v as? T, ok)
}
prefix func <-<T>(r: Chan<T>) -> T?{
    var flag = false
    let (v, ok, ready) = r.receive(true, mutex: nil, flag: &flag)
    return v as? T
}
private struct GoPanicError {
    var what: AnyObject?
    var file: StaticString = ""
    var line: UWord = 0
}
private class GoRoutineStack {
    var error = GoPanicError()
    var defers : [()->()] = []
    var (jump, jumped) = (UnsafeMutablePointer<Int32>(), false)
    var (select, cases:[(msg : Any?, ok : Bool)->()], chans:[ChanAny], defalt:(()->())?)  = (false, [], [], nil)
    init(){
        jump = UnsafeMutablePointer<Int32>(malloc(4*50))
    }
    deinit{
        free(jump)
    }
    func unwind(){
        for var i = defers.count - 1; i >= 0; i-- {
            defers[i]()
        }
        defers = []
    }
}
private class GoRoutine {
    var stack = [GoRoutineStack]()
    func $(closure:()->()){
        let s = GoRoutineStack()
        if stack.count > 0 {
            var ls = stack.last!
            s.error = ls.error
            ls.error.what = nil
        }
        stack.append(s)
        if setjmp(s.jump) == 0{
            closure()
        }
        s.unwind()
        stack.removeLast()
        if s.error.what != nil{
            if stack.count > 0 {
                panic(s.error.what!, file: s.error.file, line: s.error.line)
            } else {
                fatalError("\(s.error.what!)", file: s.error.file, line: s.error.line)
            }
        }
    }
    func defer(file : StaticString = __FILE__, line : UWord = __LINE__, closure: ()->()){
        if stack.count == 0{
            fatalError("missing ${} context", file: file, line: line)
        }
        stack.last!.defers.append({self.${closure()}})
    }
    func panic(what : AnyObject, file : StaticString = __FILE__, line : UWord = __LINE__){
        if stack.count == 0{
            fatalError("\(what)", file: file, line: line)
        }
        let s = stack.last!
        (s.error.what,s.error.file,s.error.line) = (what,file,line)
        if !s.jumped{
            s.jumped = true
            longjmp(s.jump, 1)
        }
    }
    func recover(file : StaticString = __FILE__, line : UWord = __LINE__) -> AnyObject?{
        if stack.count == 0{
            fatalError("missing ${} context", file: file, line: line)
        }
        let s = stack.last!
        let res: AnyObject? = s.error.what
        s.error.what = nil
        return res
    }
    func randomInts(count : Int) -> [Int]{
        var ints = [Int](count: count, repeatedValue:0)
        for var i = 0; i < count; i++ {
            ints[i] = i
        }
        for var i = 0; i < count; i++ {
            let r = Int(arc4random()) % count
            let t = ints[i]
            ints[i] = ints[r]
            ints[r] = t
        }
        return ints
    }
    func select(file : StaticString = __FILE__, line : UWord = __LINE__, closure:()->()){
        ${
            var s = self.stack.last!
            s.select = true
            closure()
            var idxs = self.randomInts(s.chans.count)
            if s.defalt != nil{
                var (flag, handled) = (false, false)
                for i in idxs {
                    var (msg, ok, ready) = s.chans[i].receive(false, mutex: nil, flag: &flag)
                    if ready {
                        s.cases[i](msg: msg, ok: ok)
                        handled = true
                        break
                    }
                }
                if !handled {
                    s.defalt!()
                }
            } else if idxs.count == 0 {
                for ;; {
                    if goapp.singleThreaded {
                        fatalError("all goroutines are asleep - deadlock!", file: file, line: line)
                    }
                    NSThread.sleepForTimeInterval(0.05)
                }
            } else {
                var wg = WaitGroup()
                wg.add(idxs.count)
                var signal : (except : Int)->() = { (except) in
                    for i in idxs {
                        if i != except {
                            s.chans[i].signal()
                        }
                    }
                }
                var flag = false
                var mutex = Mutex()
                for i in idxs {
                    var (c, f, ci) = (s.chans[i], s.cases[i], i)
                    dispatch_thread {
                        var (msg, ok, ready) = c.receive(true, mutex: mutex, flag: &flag)
                        if ready {
                            signal(except: ci)
                            f(msg: msg, ok: ok)
                        }
                        wg.done()
                    }
                }
                wg.wait()
            }
        }
    }
    func case_(chan : ChanAny, file : StaticString = __FILE__, line : UWord = __LINE__, closure:(msg : Any?, ok : Bool)->()) {
        if stack.count == 0 || !stack.last!.select {
            fatalError("missing select{} context", file: file, line: line)
        }
        let s = stack.last!
        s.cases.append(closure)
        s.chans.append(chan)
    }
    func default_(file : StaticString = __FILE__, line : UWord = __LINE__, closure:()->()) {
        if stack.count == 0 || !stack.last!.select {
            fatalError("missing select{} context", file: file, line: line)
        }
        let s = stack.last!
        if s.defalt != nil {
            fatalError("only one default{} per select{}", file: file, line: line)
        }
        s.defalt = closure
    }
    
}
private class GoApp {
    typealias QueueID = UnsafeMutablePointer<Void>
    private var gocount = 0
    private var mutex = pthread_mutex_t()
    private var routines = [QueueID: GoRoutine]()
    init(){
        pthread_mutex_init(&mutex, nil)
    }
    deinit{
        pthread_mutex_destroy(&mutex)
    }
    func lock(){
        pthread_mutex_lock(&mutex)
    }
    func unlock(){
        pthread_mutex_unlock(&mutex)
    }
    var queueID : QueueID {
        return QueueID(pthread_self())
    }
    func routine() -> GoRoutine {
        let id = queueID
        lock()
        var r = routines[id]
        if r == nil {
            r = GoRoutine()
            routines[id] = r
        }
        unlock()
        return r!
    }
    
    var singleThreaded : Bool{
        var res = false
        lock()
        res = gocount == 0
        unlock()
        return res
    }
    
    func _go(closure: ()->()){
        lock()
        gocount++
        unlock()
        
        routine().$(closure)
        
        lock();
        routines[queueID] = nil
        gocount--
        unlock()
        
    }
    func go(closure: ()->()){
        dispatch_thread{
            self._go(closure)
        }
    }
}
private let goapp = GoApp()
func $(closure: ()->()){
    goapp.routine().$(closure)
}
func go(closure: ()->()){
    goapp.go(closure)
}

func defer(file : StaticString = __FILE__, line : UWord = __LINE__, closure: ()->()){
    goapp.routine().defer(file: file, line: line, closure: closure)
}
func panic(what : AnyObject, file : StaticString = __FILE__, line : UWord = __LINE__){
    goapp.routine().panic(what, file: file, line: line)
}
func recover(file : StaticString = __FILE__, line : UWord = __LINE__) -> AnyObject? {
    return goapp.routine().recover(file: file, line: line)
}
func select(file : StaticString = __FILE__, line : UWord = __LINE__, closure:()->()) {
    goapp.routine().select(file: file, line: line, closure: closure)
}
func _case<T>(l : Chan<T>, file : StaticString = __FILE__, line : UWord = __LINE__, closure:(msg : T?, ok : Bool)->()) {
    goapp.routine().case_(l, file: file, line: line, closure: { (msg, ok) in closure(msg: msg as? T, ok: ok) })
}
func _default(file : StaticString = __FILE__, line : UWord = __LINE__, closure:()->()) {
    goapp.routine().default_(file: file, line: line, closure: closure)
}
