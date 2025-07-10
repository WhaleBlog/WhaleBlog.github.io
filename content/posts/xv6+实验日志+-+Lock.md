---
title: xv6 实验日志 - Lock
id: 0215405d-d13a-403a-8e6d-ec9e06e689ed
date: 2024-08-19 20:07:43
auther: admin
cover: 
excerpt: 锁的特性与实现
permalink: /archives/xv6-lock
categories:
 - notes
 - courses
tags: 
 - mit-6.s081
 - xv6
 - OS
---

刚开始接触这个概念的时候觉得锁更像是通行证一类的东西。问了下 AI，它这么和我解释：

锁（Lock）通常用于确保同一时间只有一个进程或线程能够访问某个资源。当进程或线程想要访问资源时，它必须先获得锁，完成操作后释放锁。这有点像是进入一个房间，你必须拿到钥匙（锁）才能进入，用完后再把钥匙还回去，这样其他人才能使用

锁就是一个对象，就像其他在内核中的对象一样。有一个结构体叫做 lock，它包含了一些字段，这些字段中维护了锁的状态。锁有非常直观的 API：

-   acquire，接收指向 lock 的指针作为参数。acquire 确保了在任何时间，只会有一个进程能够成功的获取锁
    
-   release，也接收指向 lock 的指针作为参数。在同一时间尝试获取锁的其他进程需要等待，直到持有锁的进程对锁调用 release
    

锁的 acquire 和 release 之间的代码，通常被称为 critical section

之所以被称为 critical section，是因为通常会在这里以原子的方式执行共享数据的更新。所以基本上来说，如果在 acquire 和 release 之间有多条指令，它们要么会一起执行，要么一条也不会执行。所以永远也不可能看到位于 critical section 中的代码，如同在 race condition 中一样在多个 CPU 上交织的执行，所以这样就能避免 race condition

锁序列化了代码的执行。如果两个处理器想要进入到同一个 critical section 中，只会有一个能成功进入，另一个处理器会在第一个处理器从 critical section 中退出之后再进入。所以这里完全没有并行执行

锁的使用完全是由程序员决定的。如果你想要一段代码具备原子性，那么其实是由程序员决定是否增加锁的 acquire 和 release。其次，代码不会自动加锁，程序员自己要确定好是否将锁与数据结构关联，并在适当的位置增加锁的 acquire 和 release

  

## 什么时候用锁

### 一个简单的规则

一个非常保守同时也是非常简单的规则：如果两个进程访问了一个共享的数据结构，并且其中一个进程会更新共享的数据结构，那么就需要对于这个共享的数据结构加锁

但这条规则又很矛盾：这条规则某种程度上来说又太过严格了。如果有两个进程共享一个数据结构，并且其中一个进程会更新这个数据结构，在某些场合不加锁也可以正常工作；而有时候这个规则又太过宽松了。除了共享的数据，在一些其他场合也需要锁，例如对于 printf，如果我们将一个字符串传递给它，xv6 会尝试原子性的将整个字符串输出，而不是与其他进程的 printf 交织输出。尽管这里没有共享的数据结构，但在这里锁仍然很有用处，因为我们想要printf的输出也是序列化的

好吧，这条规则并不完美，但是它已经是一个足够好的指导准则

### 自动加锁

如果按照刚刚的简单规则，一旦我们有了一个共享的数据结构，任何操作这个共享数据结构都需要获取锁，那么对其进行操作时自动地获取锁即可

但是这样并不行，假如说我要把 ~/dir1/x 文件 mv 到 ~/dir2/y，那么按照这条规则，先对 x 加锁，删除 x，然后释放锁；再对 y 加锁，创建 y，接着释放锁。

文件系统具有一致性要求，即文件在任何时候看起来都是存在的。但是，在 x 删除完成，而 y 未创建之际，在其他进程的视角下，文件消失了

换言之，我们希望 mv 的操作是原子的，正确的解决方法是，我们在重命名的一开始就对d1和d2加锁，之后删除x再添加y，最后再释放对于d1和d2的锁。

在这个例子中，我们的操作需要涉及到多个锁，但是直接为每个对象自动分配一个锁会带来错误的结果。在这个例子中，锁应该与操作而不是数据关联，所以自动加锁在某些场景下会出问题

> 学生提问：可不可以在访问某个数据结构的时候，就获取所有相关联的数据结构的锁？
> 
> Frans教授：这是一种实现方式。但是这种方式最后会很快演进成big kernel lock，这样你就失去了并发执行的能力，但是你肯定想做得更好。这里就是使用锁的矛盾点了，如果你想要程序简单点，可以通过coarse-grain locking（注，也就是大锁），但是这时你就失去了性能。

  
  

## 死锁

一个死锁的最简单的场景就是：首先 acquire 一个锁，然后进入到 critical section；在 critical section 中，再 acquire 同一个锁；第二个 acquire 必须要等到第一个 acquire 状态被 release 了才能继续执行，但是不继续执行的话又走不到第一个 release，所以程序就一直卡在这了。这就是一个死锁

当有多个锁的时候，场景会更加有趣。假设现在我们有两个 CPU，一个是 CPU1，另一个是 CPU2。CPU1 执行 rename 将文件 d1/x 移到 d2/y，CPU2 执行 rename 将文件 d2/a 移到 d1/b。这里 CPU1 将文件从 d1 移到 d2，CPU2 正好相反将文件从 d2 移到 d1。我们假设我们按照参数的顺序来 acquire 锁，那么 CPU1 会先获取 d1 的锁，如果程序是真正的并行运行，CPU2 同时也会获取 d2 的锁。之后 CPU1 需要获取 d2 的锁，这里不能成功，因为 CPU2 现在持有锁，所以 CPU1 会停在这个位置等待 d2 的锁释放。而另一个 CPU2，接下来会获取 d1 的锁，它也不能成功，因为 CPU1 现在持有锁。这也是死锁的一个例子，有时候这种场景也被称为 deadly embrace。这里的死锁就没那么容易探测了

这里的解决方案是，如果你有多个锁，你需要对锁进行排序，所有的操作都必须以相同的顺序获取锁

所以对于一个系统设计者，你需要确定对于所有的锁对象的全局的顺序。例如在这里的例子中我们让 d1 一直在 d2 之前，这样我们在 rename 的时候，总是先获取排序靠前的目录的锁，再获取排序靠后的目录的锁。如果对于所有的锁有了一个全局的排序，这里的死锁就不会出现了

但是这样的话，如果一个模块 m1 中方法 g 调用了另一个模块 m2 中的方法 f，那么 m1 中的方法 g 需要知道 m2 的方法 f 使用了哪些锁。因为如果 m2 使用了一些锁，那么 m1 的方法 g 必须集合 f 和 g 中的锁，并形成一个全局的锁的排序

这样违背了代码抽象的原则。m1 理应完全不知道 m2 的实现。但是具体实现中，m2 内部的锁需要泄露给 m1，这样 m1 才能完成全局锁排序。所以在设计一些更大的系统时，锁使得代码的模块化更加的复杂了

  
  

## 锁与性能

如果只有一个 big kernel lock，那么操作系统只能被一个 CPU 运行，然而大概从 2000 年开始，CPU 的单线程性能达到了一个极限并且也没有再增加过。如果要利用好多核性能，我们需要拆分锁

如果你重新设计了加锁的规则，你需要确保不破坏内核一直尝试维护的数据不变性，你可能需要重写代码，重构部分内核或者程序。所以这里就有矛盾点了。我们想要获得更好的性能，那么我们需要有更多的锁，但是这又引入了大量的工作

  
  

## 自旋锁（Spin lock）的实现
```C
// Mutual exclusion lock.
struct spinlock {
  uint locked;       // Is the lock held?
    
  // For debugging:
  char *name;        // Name of lock.
  struct cpu *cpu;   // The cpu holding the lock.
};
```

### amoswap

锁的特性就是只有一个进程可以获取锁，在任何时间点都不能有超过一个锁的持有者。

实现锁的主要难点在于锁的 acquire 接口，在 acquire 里面有一个死循环，循环中判断锁对象的 locked 字段是否为 0，如果为 0 那表明当前锁没有持有者，对于当前的 acquire 的调用可以获取锁。之后我们通过设置锁对象的 locked 字段为1来获取锁。最后返回

但是完全有可能出现这种情况：两个进程同时卡在 acquire，同时看到锁的 locked 字段为 0，接着同时设置 locked = 1，然后同时获得了锁

最常见的解决方案是利用特殊的硬件指令，在 RISC-V 上这个指令是 amoswap（amo 是 Atomic Memory Operations 的缩写）

    amoswapamoswap r1, r2, (address)

这条指令会先锁定住 address，将 address 中的数据保存在一个临时变量中（tmp），之后将 r1 中的数据写入到地址中，之后再将保存在临时变量中的数据写入到 r2 中，最后再对于地址解锁。即最后 r1 维持不变，r2 保存了 address 处原来的值，地址 address 处的值变更为 r1

这里不能使用 sd 写 address。在硬件层面上，sd 会被分成几个子操作，在执行 sd 指令的过程中，处理器可能会被中断，导致指令执行被暂时挂起；在多处理器系统中，sd 指令执行后，新写入的值可能不会立即对所有处理器可见

xv6 中 acquire 源代码如下：
```C
void
acquire(struct spinlock *lk)
{
    push_off(); // disable interrupts to avoid deadlock.
    if(holding(lk))
        panic("acquire");
    
    // On RISC-V, sync_lock_test_and_set turns into an atomic swap:
    //   a5 = 1
    //   s1 = &lk->locked
    //   amoswap.w.aq a5, a5, (s1)
    while(__sync_lock_test_and_set(&lk->locked, 1) != 0)
        ;
    
    // Tell the C compiler and the processor to not move loads or stores
    // past this point, to ensure that the critical section's memory
    // references happen strictly after the lock is acquired.
    // On RISC-V, this emits a fence instruction.
    __sync_synchronize();
    
      // Record info about lock acquisition for holding() and debugging.
    lk->cpu = mycpu();
}
```

可以看到循环判断 locked 的部分的汇编代码
```C
while(__sync_lock_test_and_set(&lk->locked, 1) != 0)
        800062ba:	87ba                	mv	a5,a4
        800062bc:	0cf4a7af          	amoswap.w.aq	a5,a5,(s1)
        800062c0:	2781                	sext.w	a5,a5
        800062c2:	ffe5                	bnez	a5,800062ba <acquire+0x22>
``` 

### 关闭中断

这里还又一处细节：在 acquire 最开始通过 push\_off 关闭了中断

以 UART 为例，这个设备使用 uart\_tx\_lock 一把大锁。假设当 top 驱动向 uart 写入字符时，最终会调用 uartputc。uartputc 函数会 acquire 锁，当 UART 完成了字符传输之后会产生一个中断，之后会运行 uartintr 函数，这个函数也会获取同一把锁，但是这把锁正在被 uartputc 持有。如果只有一个 CPU 的话，那就形成了死锁

我们需要在 acquire 中关闭中断。中断会在 release 的结束位置再次打开，因为在这个位置才能再次安全的接收中断

### synchronize

第三个细节就是 memory ordering。编译器或者处理器可能会重排指令以获得更好的性能，但是对于并发执行，这将会是一个灾难。如果我们将 critical section 与加锁解锁放在不同的CPU执行，将会得到完全错误的结果。所以指令重新排序在并发场景是错误的。为了禁止，或者说为了告诉编译器和硬件不要这样做，我们需要使用 memory fence 或者叫做 synchronize 指令，来确定指令的移动范围。对于 synchronize 指令，任何在它之前的 load/store 指令，都不能移动到它之后。锁的 acquire 和 release 函数都包含了synchronize指令。

  
  

## 结束语

首先，锁确保了正确性，但是同时又会降低性能，这是个令人失望的现实，我们是因为并发运行代码才需要使用锁，而锁另一方面又限制了代码的并发运行

其次锁会增加编写程序的复杂性，在我们的一些实验中会看到锁，我们需要思考锁为什么在这，它需要保护什么。如果你在程序中使用了并发，那么一般都需要使用锁。如果你想避免锁带来的复杂性，可以遵循以下原则：不到万不得已不要共享数据。如果你不在多个进程之间共享数据，那么 race condition 就不可能发生，那么你也就不需要使用锁，程序也不会因此变得复杂。但是通常来说如果你有一些共享的数据结构，那么你就需要锁，你可以从 coarse-grained lock（直译是粗粒度锁，理解为大锁）开始，然后基于测试结果，向 fine-grained lock 演进

最后，使用 race detector 来找到 race condition，如果你将锁的 acquire 和 release 放置于错误的位置，那么就算使用了锁还是会有 race