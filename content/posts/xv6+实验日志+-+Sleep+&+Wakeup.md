---
title: xv6 实验日志 - Sleep & Wakeup
id: 7bd73765-f0be-4495-a67f-74ed2a103605
date: 2024-08-22 11:19:42
auther: admin
cover: 
excerpt: 实际上是 sleep & wakeup & exit & wait & kill
permalink: /archives/xv6-sleep%26wakeup
categories:
 - courses
tags: 
 - mit-6.s081
 - xv6
 - OS
---

xv6 在进程切换之时还有一些限制：不允许进程在执行switch函数的过程中，持有任何其他的锁。即进程在调用switch函数的过程中，必须要持有 p->lock，但是同时又不能持有任何其他的锁

假设我们在一个只有一个CPU核的机器上，进程 P1 调用了 swtch 函数将 CPU 控制转给了调度器线程，调度器线程发现还有一个进程 P2 的内核线程正在等待被运行，所以调度器线程会切换到运行进程 P2。假设 P2 也想使用磁盘，UART 或者 console，它会对 P1 持有的锁调用 acquire，这是对于同一个锁的第二个 acquire 调用。这形成了死锁

后面讨论 Sleep & Wakeup 如何工作时会再次使用它们

  
  

## Sleep & Wakeup

当我们写一个线程的代码时，有些场景需要等待一些特定的事件，比如读取 pipe 等待非空，磁盘写入一类，可能来自于 I/O，也可能来自于另一个进程

我们怎么能让进程或者线程等待一些特定的事件呢？一种非常直观的方法是通过循环实现 busy-wait。假设我们想从一个 pipe 读取数据，我们就写一个循环一直等待 pipe 的 buffer 不为空

如果你知道你要等待的事件极有可能在 0.1 微秒内发生，通过一个类似的循环等待或许是最正确的方式。通常来说在操作设备硬件的代码中会采用这样的等待方式

如果事件可能需要数个毫秒（要知道现代 PC 每秒运行数亿次指令）甚至你都不知道事件要多久才能发生，那么我们就不想在这一直循环并且浪费本可以用来完成其他任务的 CPU 时间。这时我们想要通过类似 swtch 函数调用的方式出让 CPU，并在我们关心的事件发生时重新获取 CPU。Coordination 就是有关出让 CPU ，直到等待的事件发生再恢复执行的工具。与许多 Unix 风格操作系统一样，xv6 使用 Sleep & Wakeup 的方式
```C
// Atomically release lock and sleep on chan.
// Reacquires lock when awakened.
void
sleep(void *chan, struct spinlock *lk)
{
    struct proc *p = myproc();
      
    // Must acquire p->lock in order to
    // change p->state and then call sched.
    // Once we hold p->lock, we can be
    // guaranteed that we won't miss any wakeup
    // (wakeup locks p->lock),
    // so it's okay to release lk.
    
    acquire(&p->lock);  //DOC: sleeplock1
    release(lk);
    
    // Go to sleep.
    p->chan = chan;
    p->state = SLEEPING;
    
    sched();
    
    // Tidy up.
    p->chan = 0;
    
    // Reacquire original lock.
    release(&p->lock);
    acquire(lk);
}
    

// Wake up all processes sleeping on chan.
// Must be called without any p->lock.
void
wakeup(void *chan)
{
    struct proc *p;
    
    for(p = proc; p < &proc[NPROC]; p++) {
        if(p != myproc()){
            acquire(&p->lock);
            if(p->state == SLEEPING && p->chan == chan) {
                p->state = RUNNABLE;
            }
            release(&p->lock);
        }
    }
}
``` 

sleep 在获取，释放锁之后，设置 channel 与 state 就切换到另外的线程

wakeup 则根据 channel 将 SLEEPING 的进程状态改为 RUNABLE

当我们调用 sleep 函数时，我们传入一个 sleep channel 表明我们等待的特定事件，当然，并不关心这个数值代表什么，当调用 wakeup 时我们希望能传入与调用 sleep 函数相同的 sleep channel 来表明想唤醒哪个线程

Sleep & wakeup 的一个优点是它们可以很灵活，它们不关心代码正在执行什么操作，你不用告诉 sleep 函数你在等待什么事件，你也不用告诉 wakeup 函数发生了什么事件，你只需要匹配好 64bit 的 sleep channel 就行

不过，对于sleep函数，我们需要将一个锁作为第二个参数传入，这是一个稍微丑陋的实现。总的来说，不太可能设计一个通用的 sleep 函数并完全忽略需要等待的事件

  
  

## Lost Wakeup

sleep 若只传入 sleep channel 可能会触发 lost wakeup，即 wakeup 在 proc 的状态变为 sleep 之前便已调用

我们以 uart 设备的 uartwrite 与 uartintr 为例：这里牵涉到两个锁：进程的锁与 uart 设备的锁

假如 sleep 没有接受 uart 锁的传参，就称这种 sleep 叫 broken\_sleep 吧
```C
void
uartwrite(char buf[],int n)
{
    acquire(&uart_tx_lock);
    int i = 0;
    while(i < n){
        while(tx_done == 0){
            //UART is busy sending a character.
            //wait for it to interrupt.
            //sleep(&tx_chan,&uart_tx_lock);
            release(&uart_tx_lock);
            broken_sleep(&tx_chan);
            acquire(&uart_tx_lock);
        }
        
        WriteReg(THR, buf[i]);
        i +=1 ;
        tx_done =0;
    }
      
    release(&uart_tx_lock);
}

void
uartintr(void)
{
    acquire(&uart_tx_lock);
    if(ReadReg(LSR) & LSR_TX_IDLE){
        //UART finished transmitting;wake up any sending thread.
        tx_done = 1;
        wakeup(&tx_chan);
    }
    release(&uart_tx_lock);
}
```

可以看到 uartwrite 的 broken\_sleep 上下，先释放了 uart\_tx\_lock，sleep 结束后又将其锁上

假如说没有这两把锁是不行的，uartwrite 函数一开始就请求了 uart 设备的锁（毕竟 tx\_done 和 uart 本身是共享的，必须要加锁），而在其 while 循环内，只有当 tx\_done != 0 时才能退出循环，但是只有在 uartintr 里面才可能将这个值设为非 0，但是这个中断处理函数最开始就会请求 uart 的锁，但这是锁被 uartwrite 持有，deadly embrace

上面加锁方式的问题是，uartwrite 在期望中断处理程序执行的同时又持有了锁。而我们唯一期望中断处理程序执行的位置就是 sleep 执行期间，其他的时候 uartwrite 持有锁是没有问题的。所以我们在 sleep 之前释放了锁，待其放回再锁上

好的，假如我们有一个核正运行到 uartwrite 的 sleep 前面，此时另一个 CPU 核正在执行 uartintr 的 acquire。在锁释放的一瞬间，后者得到了锁，发现 UART 硬件完成了发送上一个字符，之后会设置 tx\_done 为 1，最后再调用 wakeup 函数。但假如在 wakeup 的时候 sleep 还没调用，uartwrite 的线程并没又进入 SLEEPING 呢？那么 wakeup 并没有唤醒任何进程，而这次的 sleep 没有人会唤醒它。这就出现了 Lost Wakeup 问题

> 学生提问：当从sleep函数中唤醒时，不是已经知道是来自UART的中断处理程序调用wakeup的结果吗？这样的话tx\_done有些多余。
> 
> Robert教授：我想你的问题也可以描述为：为什么需要通过一个循环while(tx\_done == 0)来调用sleep函数？这个问题的答案适用于一个更通用的场景：实际中不太可能将sleep和wakeup精确匹配。并不是说sleep函数返回了，你等待的事件就一定会发生。举个例子，假设我们有两个进程同时想写UART，它们都在uartwrite函数中。可能发生这种场景，当一个进程写完一个字符之后，会进入SLEEPING状态并释放锁，而另一个进程可以在这时进入到循环并等待UART空闲下来。之后两个进程都进入到SLEEPING状态，当发生中断时UART可以再次接收一个字符，两个进程都会被唤醒，但是只有一个进程应该写入字符，所以我们才需要在sleep外面包一层while循环。实际上，你可以在XV6中的每一个sleep函数调用都被一个while循环包着。因为事实是，你或许被唤醒了，但是其他人将你等待的事件拿走了，所以你还得继续sleep。这种现象还挺普遍的。

在最初给的 sleep 与 wakeup 的源代码便解决了这个问题，这是由下面这些规则确保的：

-   调用sleep时需要持有 condition lock，这样 sleep 函数才能知道相应的锁
    
-   sleep 函数只有在获取到进程的锁 p->lock 之后，才能释放 condition lock
    
-   wakeup 需要同时持有两个锁才能查看进程
    

  
  

## Exit

在 xv6 中，一个进程如果退出的话，我们需要释放用户内存，释放 page table，释放 rapframe 对象，将进程在进程表单中标为 REUSABLE

这里会产生的两大问题：

-   首先我们不能直接单方面的摧毁另一个线程。另一个线程可能正在另一个CPU核上运行，并使用着自己的栈；也可能另一个线程正在内核中持有了锁；也可能另一个线程正在更新一个复杂的内核数据
    
-   另一个问题是，即使一个线程调用了exit系统调用，并且是自己决定要退出，它仍然还是要运行一小段代码。但只要它还在执行代码，它就不能释放正在使用的资源
    

xv6 有两个函数与关闭线程进程相关。第一个是 exit，第二个是 kill。让我们先来看位于 proc.c 中的 exit 函数
```C
// Exit the current process.  Does not return.
// An exited process remains in the zombie state
// until its parent calls wait().
void
exit(int status)
{
    struct proc *p = myproc();
    
    if(p == initproc)
        panic("init exiting");
    
    // Close all open files.
    for(int fd = 0; fd < NOFILE; fd++){
        if(p->ofile[fd]){
            struct file *f = p->ofile[fd];
            fileclose(f);
            p->ofile[fd] = 0;
        }
    }
    
    begin_op();
    iput(p->cwd);
    end_op();
    p->cwd = 0;
    
    acquire(&wait_lock);
    
    // Give any children to init.
    reparent(p);
    
    // Parent might be sleeping in wait().
    wakeup(p->parent);
      
    acquire(&p->lock);
    
    p->xstate = status;
    p->state = ZOMBIE;
    
    release(&wait_lock);
    
    // Jump into the scheduler, never to return.
    sched();
    panic("zombie exit");
}
```
首先 exit 关闭了所有已打开的文件，将当前目录的引用释放给文件系统，接下来需要设置子进程的父进程为 init 进程，之后通过调用 wakeup 函数唤醒当前进程的父进程，然后设置进程状态为 ZOMBIE。现在进程还没有完全释放它的资源，还不能被重用，并且进程不会再运行。最后 sched 调度其他的进程

  
  

## Wait
```C
// Wait for a child process to exit and return its pid.
// Return -1 if this process has no children.
int
wait(uint64 addr)
{
    struct proc *np;
    int havekids, pid;
    struct proc *p = myproc();
    
    acquire(&wait_lock);
    
    for(;;){
        // Scan through table looking for exited children.
        havekids = 0;
        for(np = proc; np < &proc[NPROC]; np++){
            if(np->parent == p){
                // make sure the child isn't still in exit() or swtch().
                acquire(&np->lock);
    
                havekids = 1;
                if(np->state == ZOMBIE){
                    // Found one.
                    pid = np->pid;
                    if(addr != 0 && copyout(p->pagetable, addr, (char *)&np->xstate,sizeof(np->xstate)) < 0) {
                    release(&np->lock);
                    release(&wait_lock);
                    return -1;
                }
                freeproc(np);
                release(&np->lock);
                release(&wait_lock);
                return pid;
            }
            release(&np->lock);
      }
    }
    
    // No point waiting if we don't have any children.
    if(!havekids || p->killed){
        release(&wait_lock);
          return -1;
        }
        
        // Wait for a child to exit.
        sleep(p, &wait_lock);  //DOC: wait-sleep
    }
}
```

可以看到，wait 会循环扫描进程表单，去查找自己 ZOMBIE 的子进程。找到后，它会调用 freeproc 去释放子进程例如 trapframe，pagetable 等资源，并将 state 置为 UNUSED

wait 实际上也是进程退出的一个重要组成部分。在 Unix 中，对于每一个退出的进程，都需要有一个对应的 wait 系统调用，这就是为什么当一个进程退出时，它的子进程需要变成 init 进程的子进程。init 进程的工作就是在一个循环中不停调用 wait，因为每个进程都需要对应一个 wait，这样它的父进程才能调用 freeproc 函数，并清理进程的资源

当父进程完成了清理进程的所有资源，子进程的状态会被设置成 UNUSED。之后，fork 系统调用才能重用进程在进程表单的位置。直到子进程 exit 的最后，它都没有释放所有的资源，因为它还在运行的过程中，所以不能释放这些资源。最后是父进程释放了运行子进程代码所需要的资源。这样的设计可以让我们极大的精简 exit 的实现

  
  

## Kill

kill 的实现比想象中更加的......朴素。Uni x中的一个进程可以将另一个进程的 ID 传递给 kill 系统调用，并让另一个进程停止运行。但是这会牵扯到上面讲过的问题，比如我们想要杀掉的进程的内核线程还在更新一些数据，像更新文件系统，创建一个文件之类的，我们不能就这样杀掉。所以 kill 系统调用不能直接停止目标进程的运行。实际上，在 xv6 和其他的 Unix 系统中，kill 基本上不做任何事情
```C
// Kill the process with the given pid.
// The victim won't exit until it tries to return
// to user space (see usertrap() in trap.c).
int
kill(int pid)
{
    struct proc *p;
    
    for(p = proc; p < &proc[NPROC]; p++){
        acquire(&p->lock);
        if(p->pid == pid){
            p->killed = 1;
            if(p->state == SLEEPING){
                // Wake process from sleep().
                p->state = RUNNABLE;
            }
            release(&p->lock);
            return 0;
        }
        release(&p->lock);
    }
    return -1;
}
```
它先扫描进程表单，找到目标进程。然后只是将进程的 proc 结构体中 killed 标志位设置为 1。如果进程正在 SLEEPING 状态，将其设置为 RUNNABLE

而目标进程运行到内核代码中能安全停止运行的位置时，会检查自己的 killed 标志位，如果为 1，目标进程会自愿的执行 exit(-1)。在 usertrap 的最后就会做这样的检查，例如当一个定时器中断到来，usertrap 发现 p->killed === 1，就直接 exit 了

所以 kill 系统调用并不是真正的立即停止进程的运行，从调用 kill，到另一个进程真正退出，中间可能有很明显的延时

但其实在 xv6 的很多位置中，如果进程在 SLEEPING 状态时被 kill 了，进程会实际的退出。首先 kill 会将 SLEEPING 改为 RUNABLE，这样调度器线程会重新运行这个线程，而在很多地方的 sleep 循环内（比如下面的 piperead），会对 killed 进行检测：
```C
while(pi->nread == pi->nwrite && pi->writeopen){  //DOC: pipe-empty
    if(pr->killed){
        release(&pi->lock);
        return -1;
    }
    sleep(&pi->nread, &pi->lock); //DOC: piperead-sleep
}
```
于是函数会立马返回到 usertrap，然后 exit

因为 pipe 再度 sleep 的时候，pipe 内大概率还是没有数据，所以 kill 了影响不大。但是在更新文件系统这样的操作时， while 里面就不会检查 killed 了，因为必须等待这个操作完成
```C
while(b->disk == 1)
    sleep(b, &disk.vdisk_lock);
```