---
title: xv6 实验日志 - Interrupts
id: aefc618e-be6e-4469-a622-ba092dee7825
date: 2024-08-19 10:52:05
auther: admin
cover: 
excerpt: Console 是如何显示 $ ls 的
permalink: /archives/xv6-interrupts
categories:
 - courses
tags: 
 - xv6
 - mit-6.s081
 - OS
---

虽然以中断为名，但这里并不涉及软件中断和计时器中断。这里只为搞清一件事情：xv6 Console 的 `$ ls` 是怎么出现的

我们从 xv6 的启动开始讲起

  

## 设置中断

在 kernel.ld 中定义了 \_entry 为入口点

\_entry 最后跳转到了 start（在 kernel/start.c 中）

start 将所有的中断都设置在Supervisor mode，然后设置SIE寄存器来接收External，软件和定时器中断，之后初始化定时器。通过设置 mepc 为 main，然后执行 mret，跳转到 main（kernel/main.c）中

main 中最先调用 consoleinit()，这个函数初始化了锁，调用 uartinit() 后设置了 consoleread/write，是方便后续系统调用读写时做分发

uartinit() 先关闭中断，设置了一堆寄存器，最后打开了中断。原则上UART就可以生成中断了，但是还没处理 PLIC（Platform Level Interrupt Control，处理器用于处理设备中断）

中断到达PLIC之后，PLIC会路由这些中断。PLIC会将中断路由到某一个CPU的核。如果所有的CPU核都正在处理中断，PLIC会保留中断直到有一个CPU核可以用来处理中断。所以PLIC需要保存一些内部数据来跟踪中断的状态。

这里的具体流程是：

1.  PLIC会通知当前有一个待处理的中断
    
2.  其中一个CPU核会Claim接收中断，这样PLIC就不会把中断发给其他的CPU处理
    
3.  CPU核处理完中断之后，CPU会通知PLIC
    
4.  PLIC将不再保存中断的信息
    

在 main() 函数的后面部分调用了 plicinit() 与 plicinithart()。plicinit() 使能 PLIC 接受 UART 与 VIRTIO 的中断。plicinithart() 则让每个 CPU 声明其可处理 UART 与 VIRTIO 的中断，并设置了优先级

在 main 最后的 scheduler 函数中会调用 intr\_on()。这个函数设置了 sstatus 的 SIE，打开中断标志位，这样 CPU 就有能力接受中断了

  

## UART 驱动

大部分驱动都分为两个部分，bottom/top

bottom 部分通常是 Interrupt handler。当一个中断送到了 CPU，并且 CPU 设置接收这个中断，CPU 会调用相应的 Interrupt handler。Interrupt handler 并不运行在任何特定进程的 context 中，它只是处理中断

top 部分，是用户进程，或者内核的其他部分调用的接口。对于 UART 来说，这里有 read/write 接口，这些接口可以被更高层级的代码调用

接下来会较为详细地说明这个步骤以便理解

  

## UART top

在 main 中的 userinit() 里面创建了一个新的进程，手写了 exec("/init") 的可执行二进制码保存到 initcode\[\] 中，再将其复制，映射到此进程用户页表地址为 0 的地方

即 schedule() 之后运行的第一个进程的代码在 user/init.c 里面

它首先创造了 Console 设备（文件），文件描述符为 0（stdin），又调用两个 dup(0) 打开了 stdout 和 stderr，这三个 fd 0，1，2 都代表 Console

init 又 exec 打开了 sh，开启了 Shell。Shell 调用了 getcmd()，用 fprintf 向 stderr 打印了 “$ "

尽管Console背后是UART设备，但是从应用程序来看，它就像是一个普通的文件。Shell程序只是向文件描述符2写了数据，它并不知道文件描述符2对应的是什么

实质上，无论是 printf 还是 fprintf，最终会触发 write 系统调用。通过前面的 Trap 实验我们知道，陷入内核之后会来到 sys\_write

sys\_write 对参数做了检查之后，调用了 filewrite()（kernel/file.c）

filewrite 会根据传参进来的文件判断其类型，再根据类型进行分发。fd 2 的文件的 type 属于 FD\_DEVICE，是 Console 设备。根据此前 consoleinit() 的设置，分发到了 consolewrite()（kernel/console.c）

consolewrite 的 either\_copyin 只是对 copyin 和 memmove 封装，可以接受用户或者内核的地址。通过其获取字符之后，调用了 uartputc()

uartputc 内有一个大小为 32 的 buffer，有两个表示读和写的指针（环形队列）。uartputc 会进入一个 while(1) 循环，如果环形队列满了，就 sleep 等待，直到有空闲之时，便向其内写入字符，调用 uartstart() 后返回

uartstart 就是通知设备执行操作。首先是检查当前设备是否空闲，如果空闲的话，我们会从buffer中读出数据，然后将数据写入到 THR（Transmission Holding Register）发送寄存器。这里相当于告诉设备，我这里有一个字节需要你来发送。一旦数据送到了设备，系统调用会返回（就是 trap 的流程），用户应用程序Shell就可以继续执行

与此同时，UART 设备会将数据送出。在某个时间点，我们会收到中断，因为我们之前设置了要处理 UART 设备中断。接下来我们看一下，当发生中断时，实际会发生什么

P.S. 我认为 THR 将字符发送出去之后，Console 就可以将这个字符显示出来了。之后 UART 触发中断应该是为了通知 CPU 可以发送下一个字符。但是，这只是猜测

  

## UART bottom

中断发生时，PLIC 将此中断发送给了一个特定的 CPU 核，那么会发生以下事情：

1.  首先，会清除 SIE 寄存器相应的 bit，这样可以阻止 CPU 核被其他中断打扰
    
2.  之后，会设置 SEPC 寄存器为当前的程序计数器
    
3.  存当前的 mode，最后跳转到 STVEC 所指处
    

trap.c 中，会通过 devintr() 判断时软件中断还是外部中断

devintr 首先会通过 SCAUSE寄 存器判断当前中断是否是来自于外设的中断。如果是的话，再调用 plic\_claim 函数来获取中断

plic\_claim 返回一个中断号。devintr 通过中断号发现是 UART 中断，于是调用 uartintr

uart 首先会调用 uartgetc() 查询 UART 是否有等待中的字符，有的话（比如来自键盘输入）就将其传入 consoleintr()，默认情况下最后还是写在 THR。没有的话就运行 uartstart()。在上面打印完 “$" 后发现 buffer 里面还有一个空格，于是把它也发送出去

正如 UART 驱动所写，bottom 是一个中断处理器，top 则是对外的接口。这样，驱动的top部分和bottom部分就解耦开了

  

## UART 读取键盘

键盘的读取也是通过 read。像上面一样，通过 sys\_read -> fileread -> consoleread

Console 也维护了一个 buffer，包含了128个字符。其他的基本一样。在这个场景下 Shell 变成了 consumser，而键盘是 producer

在 consoleread 函数中，buffer 为空时，进程会 sleep。所以 Shell 在打印完 “$ ” 之后，如果键盘没有输入，Shell 进程会 sleep，直到键盘有一个字符输入。所以在某个时间点，假设用户通过键盘输入了 “l”，这会导致 “l” 被发送到主板上的UART芯片，产生中断之后再被 PLIC 路由到某个 CPU 核，之后会触发 devintr 函数，devintr 可以发现这是一个 UART 中断，然后通过 uartgetc 函数获取到相应的字符，之后再将字符传递给 consoleintr 函数（就像上文说的）

默认情况下，字符会通过 consputc，输出到 console 上给用户查看。之后，字符被存放在buffer中。在遇到换行符的时候，唤醒之前 sleep 的进程，也就是 Shell，再从 buffer 中将数据读出

所以这里也是通过 buffer 将 consumer 和 producer 之间解耦，这样它们才能按照自己的速度，独立的并行运行。如果某一个运行的过快了，那么 buffer 要么是满的要么是空的，consumer 和 producer 其中一个会 sleep 并等待另一个追上来