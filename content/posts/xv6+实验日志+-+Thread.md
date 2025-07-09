---
title: xv6 实验日志 - Thread
id: 5c92315d-8566-4c5a-88e9-15310ecb44bb
date: 2024-08-20 16:35:21
auther: admin
cover: 
excerpt: 线程调度过程
permalink: /archives/xv6-thread
categories:
 - courses
tags: 
 - mit-6.s081
 - xv6
---

在 xv6 中，我们认为线程就是单个串行执行代码的单元，它只占用一个CPU并且以普通的方式一个接一个的执行指令

线程具有状态，我们可以随时保存线程的状态并暂停线程的运行，并在之后通过恢复状态来恢复线程的运行。线程的状态包含了三个部分：PC，寄存器，栈

在 xv6 中，每个进程有两个线程，一个用户线程执行用户空间代码，一个内核线程处理系统调用之类的事，并且存在限制使得一个进程要么运行在用户空间线程，要么为了执行系统调用或者响应中断而运行在内核空间线程 ，但是永远也不会两者同时运行。除此之外，每个 CPU 都有一个调度器线程，这些调度器线程有自己独立的栈

Linux 允许在一个用户进程中包含多个线程，进程中的多个线程共享进程的地址空间

> 学生提问：操作系统都带了线程的实现，如果想要在多个CPU上运行一个进程内的多个线程，那需要通过操作系统来处理而不是用户空间代码，是吧？那这里的线程切换是怎么工作的？是每个线程都与进程一样了吗？操作系统还会遍历所有存在的线程吗？比如说我们有8个核，每个CPU核都会在多个进程的更多个线程之间切换。同时我们也不想只在一个CPU核上切换一个进程的多个线程，是吧？
> 
> Robert教授：Linux是支持一个进程包含多个线程，Linux的实现比较复杂，或许最简单的解释方式是：几乎可以认为Linux中的每个线程都是一个完整的进程。Linux中，我们平常说一个进程中的多个线程，本质上是共享同一块内存的多个独立进程。所以Linux中一个进程的多个线程仍然是通过一个内存地址空间执行代码。如果你在一个进程创建了2个线程，那基本上是2个进程共享一个地址空间。之后，调度就与XV6是一致的，也就是针对每个进程进行调度

在 xv6 和其他的操作系统中，线程调度是这么实现的：定时器中断会强制的将 CPU 控制权从用户进程给到内核，这里是 pre-emptive scheduling（先发制人，或防御性调度），之后内核会代表用户进程（注，实际是内核中用户进程对应的内核线程会代表用户进程出让CPU），使用 voluntary scheduling

在执行线程调度的时候，操作系统需要能区分几类线程：

1.  RUNNING：当前在 CPU 上运行的线程
    
2.  RUNABLE： 一旦CPU有空闲时间就想要运行在CPU上的线程
    
3.  SLEEPING： 以及不想运行在CPU上的线程，因为这些线程可能在等待I/O或者其他事件
    

对于 xv6 来说，并不会直接让用户线程出让CPU或者完成线程切换，而是由内核在合适的时间点做决定。内核会在两个场景下出让 CPU：一是定时器中断触发了，二是任何时候一个进程调用了系统调用并等待I/O

当人们在说 context switching（上下文切换）时，可以指线程切换也可以指进程切换，还可以是用户与内核的切换。这里的 context switching 主要是指一个内核线程和调度器线程之间的切换

每一个CPU核在一个时间只会做一件事情，每个CPU核在一个时间只会运行一个线程，它要么是运行用户进程的线程，要么是运行内核线程，要么是运行这个CPU核对应的调度器线程。所以在任何一个时间点，CPU核并没有做多件事情，而是只做一件事情。线程的切换创造了多个线程同时运行在一个CPU上的假象。类似的每一个线程要么是只运行在一个CPU核上，要么它的状态被保存在context中。线程永远不会运行在多个CPU核上，线程要么运行在一个CPU核上，要么就没有运行

  
  

## xv6 线程调度

### 用户进程切换流程

1.  从一个用户进程切换到另一个用户进程，都需要从第一个用户进程接入到内核中，保存用户进程的状太并运行第一个用户进程的内核线程
    
2.  再从第一个用户进程的内核线程切换到 CPU 的调度线程
    
3.  调度线程选择好了之后会进入第二个用户进程的内核线程
    
4.  之后，第二个用户进程的内核线程暂停自己，并恢复第二个用户进程的用户寄存器
    
5.  最后返回到第二个用户进程继续执行
    

### 状态保存位置

用户进程状态保存在 trapframe，内核线程状态保存在 proc 的 context，调度线程的状态保存在 cpu 的 context

现在，我们可以重新看看这几个熟悉的结构体了：
```C
struct cpu {
    struct proc *proc;          // The process running on this cpu, or null.
    struct context context;     // swtch() here to enter scheduler().
    int noff;                   // Depth of push_off() nesting.
    int intena;                 // Were interrupts enabled before push_off()?
  };
    
  struct proc {
    struct spinlock lock;
    
    // p->lock must be held when using these:
    enum procstate state;        // Process state
    void *chan;                  // If non-zero, sleeping on chan
    int killed;                  // If non-zero, have been killed
    int xstate;                  // Exit status to be returned to parent's wait
    int pid;                     // Process ID
    
    // wait_lock must be held when using this:
    struct proc *parent;         // Parent process
    
    // these are private to the process, so p->lock need not be held.
    uint64 kstack;               // Virtual address of kernel stack
    uint64 sz;                   // Size of process memory (bytes)
    pagetable_t pagetable;       // User page table
    struct trapframe *trapframe; // data page for trampoline.S
    struct context context;      // swtch() here to run process
    struct file *ofile[NOFILE];  // Open files
    struct inode *cwd;           // Current directory
    char name[16];               // Process name (debugging)
};
```

### 源代码

在 devintr 中，检测到时钟中断会返回 2，值传给了 which\_dev。在 usertrap 里检测到 which\_dev == 2 会调用 yield()
```C
void
yield(void)
{
    struct proc *p = myproc();
    acquire(&p->lock);
    p->state = RUNNABLE;
    sched();
    release(&p->lock);
}
```  

yield 首先获取了进程的锁。这是为了将进程的 state 修改为 RUNABLE 时不被其他的 CPU 调度

然后进入 sched()。sched() 做了一堆合理性检查，然后走到 swtch（switch）
```C
void
sched(void)
{
    int intena;
    struct proc *p = myproc();
    
    if(!holding(&p->lock))
        panic("sched p->lock");
    if(mycpu()->noff != 1)
        panic("sched locks");
    if(p->state == RUNNING)
        panic("sched running");
    if(intr_get())
        panic("sched interruptible");
    
    intena = mycpu()->intena;
    swtch(&p->context, &mycpu()->context);
    mycpu()->intena = intena;
}
```

swtch 在 swtch.S 中定义，a0 是内核线程 context 的地址，a1 则是调度器线程的。这个函数保存了内核线程状态，然后切换到了调度器线程
```Risc-V
    .globl swtch
    swtch:
            sd ra, 0(a0)
            sd sp, 8(a0)
            sd s0, 16(a0)
            sd s1, 24(a0)
            sd s2, 32(a0)
            sd s3, 40(a0)
            sd s4, 48(a0)
            sd s5, 56(a0)
            sd s6, 64(a0)
            sd s7, 72(a0)
            sd s8, 80(a0)
            sd s9, 88(a0)
            sd s10, 96(a0)
            sd s11, 104(a0)
    
            ld ra, 0(a1)
            ld sp, 8(a1)
            ld s0, 16(a1)
            ld s1, 24(a1)
            ld s2, 32(a1)
            ld s3, 40(a1)
            ld s4, 48(a1)
            ld s5, 56(a1)
            ld s6, 64(a1)
            ld s7, 72(a1)
            ld s8, 80(a1)
            ld s9, 88(a1)
            ld s10, 96(a1)
            ld s11, 104(a1)
            
            ret
```   

ra 寄存器记录这 swtch 的返回地址，因此没有必要保存 pc。在 context 中我们只保存了 14 个 Callee Saved Register，因为 swtch 的调用者应默认除此之外的寄存器会被修改

内核线程的 ra 显然指向 sched() 内的下一条指令，但是调度器线程的 ra 是在 scheduler() 的某处。于是在 ret 之后进入到 scheduler()
```C
void
scheduler(void)
{
    struct proc *p;
    struct cpu *c = mycpu();
      
    c->proc = 0;
    for(;;){
        // Avoid deadlock by ensuring that devices can interrupt.
        intr_on();
    
        for(p = proc; p < &proc[NPROC]; p++) {
            acquire(&p->lock);
            if(p->state == RUNNABLE) {
                // Switch to chosen process.  It is the   process's job
                // to release its lock and then reacquire it
                // before jumping back to us.
                p->state = RUNNING;
                c->proc = p;
                swtch(&c->context, &p->context);
    
                // Process is done running for now.
                // It should have changed its p->state before coming back.
                c->proc = 0;
            }
            release(&p->lock);
        }
    }
}
```
    

此时的 pc 应该在 scheduler() 的 swtch 的下方。但是，我们刚刚返回的 swtch 和这里的 swtch 不是一个 swtch。它们所在的线程不同，而且传参的顺序不一样。这里的 swtch 显然是从调度器线程切换到新的内核线程

切换到调度器线程后，CPU 自然就没有在运行用户进程了，所以我们将 c->proc 设置为 0

之前 yield 为了防止线程切换被其他的调度器线程打断而申请了锁，现在我们完成了这一步骤，可以释放锁了

在调度的过程中锁完成了两件事：

1.  首先，出让 CPU 涉及到很多步骤，我们需要将进程的状态从 RUNNING 改成 RUNABLE，我们需要将进程的寄存器保存在 context 对象中，并且我们还需要停止使用当前进程的栈。在这三个步骤完成之前，锁阻止任何一个其他核的调度器线程看到当前进程，确保了三个步骤的原子性。从CPU核的角度来说，三个步骤要么全发生，要么全不发生
    
2.  当我们开始要运行一个进程时，p->lock 也有类似的保护功能。我们希望启动一个进程的过程也具有原子性，这也是为什么 scheduler 加锁
    

好，接下来代码会在一个死循环内检查所有的进程并找到一个来运行。找到之后，通过 swtch 来到这个新的内核线程的 sched()，返回 yield()，usertrap()，usertrapret()，在 userret 返回到对应的新用户进程

关于第一个 swtch 调用，请看[这里](https://mit-public-courses-cn-translatio.gitbook.io/mit6-s081/lec11-thread-switching-robert/11.9-xv6-call-switch-function-first-time)