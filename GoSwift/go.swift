/*
* GoSwift (go.swift)
*
* Copyright (C) 2015 ONcast, LLC. All Rights Reserved.
* Created by Josh Baker (joshbaker77@gmail.com)
*
* This software may be modified and distributed under the terms
* of the MIT license.  See the LICENSE file for details.
*
*/

import Foundation

private let pt_entry: @convention(c) (UnsafeMutablePointer<Void>) -> UnsafeMutablePointer<Void> = { (ctx) in
    let np = UnsafeMutablePointer<()->()>(ctx)
    np.memory()
    np.destroy()
    np.dealloc(1)
    return nil
}
public func dispatch_thread(block : ()->()){
    let p = UnsafeMutablePointer<()->()>.alloc(1)
    p.initialize(block)
    var t = pthread_t()
    pthread_create(&t, nil, pt_entry, p)
    pthread_detach(t)
}
public protocol Locker {
    func lock()
    func unlock()
}
public class Mutex : Locker {
    private var mutex = pthread_mutex_t()
    init(){
        pthread_mutex_init(&mutex, nil)
    }
    deinit{
        pthread_mutex_destroy(&mutex)
    }
    public func lock(){
        pthread_mutex_lock(&mutex)
    }
    public func unlock(){
        pthread_mutex_unlock(&mutex)
    }
    func lock(closure : ()->()){
        lock()
        closure()
        unlock()
    }
}
public class Cond {
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
public class Once {
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
public class WaitGroup {
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
public protocol ChanAny {
    func receive(wait : Bool, mutex : Mutex?, inout flag : Bool) -> (msg : Any?, ok : Bool, ready : Bool)
    func send(msg : Any?)
    func close()
    func signal()
    func count() -> Int
    func capacity() -> Int
}
public class Chan<T> : ChanAny {
    private var msgs = [Any?]()
    private var cap = 0
    private var cond = Cond(locker: Mutex())
    private var closed = false
    
    convenience init(){
        self.init(0)
    }
    init(_ buffer: Int){
        cap = buffer
    }
    init(buffer: Int){
        cap = buffer
    }
    public func count() -> Int{
        if cap == 0 {
            return 0
        }
        return msgs.count
    }
    public func capacity() -> Int{
        return cap
    }
    public func close(){
        cond.locker.lock()
        if !closed {
            closed = true
            cond.broadcast()
        }
        cond.locker.unlock()
    }
    public func send(msg: Any?) {
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
    public func receive(wait : Bool, mutex : Mutex?, inout flag : Bool) -> (msg : Any?, ok : Bool, ready : Bool) {
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
            let msg = msgs.removeAtIndex(0)
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
                    let msg = msgs.removeAtIndex(0)
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
                let msg = msgs.removeAtIndex(0)
                cond.broadcast()
                cond.locker.unlock()
                return (msg, true, true)
            }
            cond.wait()
        }
    }
    public func signal(){
        cond.broadcast()
    }
}
infix operator <- { associativity right precedence 155 }
prefix operator <- { }
prefix operator <? { }
public func <-<T>(l: Chan<T>, r: T?){
    l.send(r)
}
public prefix func <?<T>(r: Chan<T>) -> (T?, Bool){
    var flag = false
    let (v, ok, _) = r.receive(true, mutex: nil, flag: &flag)
    return (v as? T, ok)
}
public prefix func <-<T>(r: Chan<T>) -> T?{
    var flag = false
    let (v, _, _) = r.receive(true, mutex: nil, flag: &flag)
    return v as? T
}
public func close<T>(chan : Chan<T>){
    chan.close()
}
public func len<T>(chan : Chan<T>) -> Int{
    return chan.count()
}
public func cap<T>(chan : Chan<T>) -> Int{
    return chan.capacity()
}
private struct GoPanicError {
    var what: AnyObject?
    var file: StaticString = ""
    var line: UInt = 0
}
private class GoRoutineStack {
    var error = GoPanicError()
    var (jump, jumped) = (UnsafeMutablePointer<Int32>(), false)
    var select = false
    var cases : [(msg : Any?, ok : Bool)->()] = []
    var chans : [ChanAny] = []
    var defalt : (()->())?
    init(){
        jump = UnsafeMutablePointer<Int32>(malloc(4*50))
    }
    deinit{
        free(jump)
    }
}
private class GoRoutine {
    var stack = [GoRoutineStack]()
    func $(closure:()->()){
        let s = GoRoutineStack()
        if stack.count > 0 {
            let ls = stack.last!
            s.error = ls.error
            ls.error.what = nil
        }
        stack.append(s)
        if setjmp(s.jump) == 0{
            closure()
        }
        stack.removeLast()
        if s.error.what != nil{
            if stack.count > 0 {
                panic(s.error.what!, file: s.error.file, line: s.error.line)
            } else {
                fatalError("\(s.error.what!)", file: s.error.file, line: s.error.line)
            }
        }
    }
    func panic(what : AnyObject, file : StaticString = __FILE__, line : UInt = __LINE__){
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
    func recover(file : StaticString = __FILE__, line : UInt = __LINE__) -> AnyObject?{
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
    func select(file : StaticString = __FILE__, line : UInt = __LINE__, closure:()->()){
        ${
            let s = self.stack.last!
            s.select = true
            closure()
            let idxs = self.randomInts(s.chans.count)
            if s.defalt != nil{
                var (flag, handled) = (false, false)
                for i in idxs {
                    let (msg, ok, ready) = s.chans[i].receive(false, mutex: nil, flag: &flag)
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
                let wg = WaitGroup()
                wg.add(idxs.count)
                let signal : (except : Int)->() = { (except) in
                    for i in idxs {
                        if i != except {
                            s.chans[i].signal()
                        }
                    }
                }
                var flag = false
                let mutex = Mutex()
                for i in idxs {
                    let (c, f, ci) = (s.chans[i], s.cases[i], i)
                    dispatch_thread {
                        let (msg, ok, ready) = c.receive(true, mutex: mutex, flag: &flag)
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
    func case_(chan : ChanAny, file : StaticString = __FILE__, line : UInt = __LINE__, closure:(msg : Any?, ok : Bool)->()) {
        if stack.count == 0 || !stack.last!.select {
            fatalError("missing select{} context", file: file, line: line)
        }
        let s = stack.last!
        s.cases.append(closure)
        s.chans.append(chan)
    }
    func default_(file : StaticString = __FILE__, line : UInt = __LINE__, closure:()->()) {
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
public func $(closure: ()->()){
    goapp.routine().$(closure)
}
public func go(closure: ()->()){
    goapp.go(closure)
}
public func panic(what : AnyObject, file : StaticString = __FILE__, line : UInt = __LINE__){
    goapp.routine().panic(what, file: file, line: line)
}
public func recover(file : StaticString = __FILE__, line : UInt = __LINE__) -> AnyObject? {
    return goapp.routine().recover(file, line: line)
}
public func select(file : StaticString = __FILE__, line : UInt = __LINE__, closure:()->()) {
    goapp.routine().select(file, line: line, closure: closure)
}
public func _case<T>(l : Chan<T>, file : StaticString = __FILE__, line : UInt = __LINE__, closure:(msg : T?, ok : Bool)->()) {
    goapp.routine().case_(l, file: file, line: line, closure: { (msg, ok) in closure(msg: msg as? T, ok: ok) })
}
public func _default(file : StaticString = __FILE__, line : UInt = __LINE__, closure:()->()) {
    goapp.routine().default_(file, line: line, closure: closure)
}
