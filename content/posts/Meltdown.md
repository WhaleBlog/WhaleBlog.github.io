---
title: Meltdown
id: 4f16cb69-9b8a-4b37-a8f8-051ec37a5296
date: 2024-08-31 21:07:01
auther: admin
cover: 
excerpt: 一种利用了 CPU 预测执行的攻击手段
permalink: /archives/meltdown
categories:
 - notes
 - courses
tags: 
 - mit-6.s081
 - OS
---

Meltdown 是一种利用了 CPU 预测执行的攻击手段。如它的名字一样，它”溶解“了用户空间与内核空间的隔离性。详细内容可以访问 [https://meltdownattack.com](https://meltdownattack.com) 查看

在这个网站里面还记录了另一个漏洞 Spectre。Intel 的芯片被指出均存在 Meltdown 漏洞, 而 Spectre 漏洞则是危害着所有架构的芯片, 无一幸免。这两个可谓目前为止体系结构历史上影响最大的漏洞了

在有关这个漏洞发布时（2018），大部分操作系统都会将内核内存完整映射到用户空间程序，因为这使得当发生系统调用时，你不用切换 Page Table，也不必清空各种缓存。所以所有的内核 PTE 都会出现在用户程序的 Page Table 中，但是因为这些 PTE 的 PTE\_U 比特位没有被设置，用户代码并不能实际的使用内核内存地址

但是 Meltdown 找到了一种方法，可以在没有权限的情况下读取特定地址的比特位。接下来会讲攻击者利用的两个技巧，一个是预测执行，一个是 CPU 缓存

> 学生提问：所以为了能够攻击，需要先知道内核的虚拟内存地址？
> 
> Robert 教授：是的。或许找到内存地址本身就很难，但是你需要假设攻击者有无限的时间和耐心，如果他们在找某个数据，他们或许愿意花费几个月的时间来窃取这个数据。有可能这是某人用来登录银行账号或者邮件用的密码。这意味着攻击者可能需要尝试每一个内核内存地址，以查找任何有价值的数据。
> 
> 在这个攻守双方的游戏中，我们需要假设攻击者最后可以胜出并拿到内核的虚拟内存地址。所以我们会假设攻击者要么已经知道了一个内核虚拟地址，要么愿意尝试每一个内核虚拟内存地址。

  
  

## Speculative execution

预测执行是一种用来提升 CPU 性能的技术。假设我们运行如下代码：

    r0 = <something>
    r1 = valid
    if (r1 == 1) {
      r2 = *r0
      r3 = r2 + 1
    } else {
      r3 = 0
    }
    /* r0, r1, r2, r3 are registers, valid is in RAM */

任何一个需要从内存中读取数据的 load 指令都会花费 2GHZ CPU 的数百个 CPU cycle，在 r1 获取 valid 值时亦是如此

现在的 CPU 都使用了叫做 branch prediction 的功能

CPU 在知道第 3 行代码是否为 true 之前，它会选择某一个 branch 并开始执行。或许 branch 选错了，但是 CPU 现在还不知道

或许在第 2 行的 load 结束前，也就是在知道valid变量的值之前，CPU会开始执行第 4 行的指令

为了能回滚误判的预测执行，CPU 需要将寄存器值保存在别处。虽然代码中第 4 行，第5行将值保存在了 r2，r3，但是实际上是保存在了临时寄存器中。如果 CPU 赌对了，那么这些临时寄存器就成了真实寄存器，如果赌错了，CPU 会抛弃临时寄存器，这样代码第 4，5 行就像从来没有发生过一样

对于我们来说，更有趣的一个问题是，**如果r0中的指针不是一个有效的指针，会发生什么**？如果 r0 中的指针不是一个有效的地址，并且我们在超前执行代码第4行，**机器不会产生 Fault**。因为它不能确定代码第 4 行是否是一个正确的代码分支，因为有可能 CPU 赌错了。所以**直到 CPU 知道了 valid 变量的内容，否则 CPU 不能在代码第 4 行生成 Page Fault**。也就是说，如果 CPU 发现代码第 4 行中 r0 内的地址是无效的，且 valid 变量为 1，这时机器才会生成 Page Fault。所以是否要产生 Page Fault 的决定，可能会推迟数百个 CPU cycle，直到 valid 变量的值被确定

当我们确定一条指令是否正确的超前执行了而不是被抛弃了这个时间点，对应的技术术语是 Retired。一条指令 Retired 需要满足两个条件：首先它自己要结束执行，其次，所有之前的指令也需要 Retired

如果 r0 中的内存地址是无效的，且在 Page Table 中完全没有映射关系，那么我也不知道会发生什么。如果 r0 中的内存地址在 Page Table 中存在映射关系，只是现在权限不够，那么 **Intel 的 CPU 会加载内存地址对应的数据，并存储在 r2 寄存器的临时版本中**

> 学生提问：我对CPU的第二个预测，也就是从r0中保存的内存地址加载数据有一些困惑，这是不是意味着r0对应的数据先被加载到了r2，然后再检查PTE的标志位？
> 
> Robert 教授：完全正确。在预测的阶段，不论r0指向了什么地址，只要它指向了任何东西，内存中的数据会被加载到r2中。之后，当load指令Retired时才会检查权限。如果我们并没有权限做操作，所有的后续指令的效果会被取消，也就是对于寄存器的所有修改会回滚。同时，Page Fault会被触发，同时寄存器的状态就像是预测执行的指令没有执行过一样
> 
> 学生提问：难道不能限制CPU在Speculative execution的时候，先检查权限，再执行load指令吗
> 
> Robert教授：Intel芯片并不是这样工作的。Meltdown Attack 并不会在 AMD CPU 上生效。普遍接受的观点是，AMD CPU 在 Speculative execution 时，如果没有权限读取内存地址，是不会将内存地址中的数据读出
> 
> 学生提问：我们应该为预测执行指令检查权限标志位吗？Intel的回答是不，为什么要检查呢？
> 
> Robert 教授：如果更早的做权限检查，会在CPU核和L1 cache之间增加几个数字电路门，而CPU核和L1 cache之间路径的性能对于机器来说重要的，如果你能在这节省一些数字电路门的话，这可以使得你的CPU节省几个cycle来从L1 cache获取数据，进而更快的运行程序

  
  

## CPU caches

当 CPU 需要执行 load/store 指令时，CPU 会与内存系统通信。内存系统一些 cache 其中包含了数据的缓存。首先是 L1 data cache，它或许有 64KB，虽然不太大，但是它特别的快。L1 cache 的缓存由虚拟地址索引，如果 L1 中没有找到，我们就需要物理内存地址，这里需要 TLB。我们假设 TLB 中包含了虚拟内存地址对应的物理内存 Page 地址，我们就可以获取到所需要的物理内存地址。通常来说会有一个更大的 cache（L2 cache），它是由物理内存地址索引。如果 L2 中也没有，就要跑到内存中找，这会花费很长的时间。当我们最终获得了数据时，我们可以将从 RAM 读取到的数据加入到 L1 和 L2 cache 中，最终将数据返回给 CPU

L1 命中的话可能只要几个 CPU cycle，L2 命中的话，可能要几十个 CPU cycle，如果都没有命中最后需要从内存中读取那么会需要几百个 CPU cycle

  
  

## Flush and Reload

Meltdown 的实现还需要一种技术，我们需要知道一段代码是否动过一个特定的内存，Flush and Reload 就可以做到这一点。简单来说就是先清空 cache，保证这段特定的内存没有被 cache；然后执行特定的代码；接着读取这段内存，如果速度很快的话，就说明这段内存被重新 cache 了，即刚刚运行的代码动过这段内存

关于清空 cache，Intel 提供了一条指令，叫做 clflush，它接收一个内存地址作为参数，并确保该内存地址不在任何 cache 中。这直接实现了我们的目的。即使没有这条指令，我们可以 load 64KB 随机数据将原本的 cache 冲走

对读取速度的测量，我们可以使用 rdtsc。Intel CPU 会提供指令来向你返回 CPU cycle 的数量。执行 rdtsc 指令，它会返回 CPU 启动之后总共经过了多少个 CPU cycle

  
  

## Meltdown Attack

在有以上前置知识之后，可以来看看 Meltdown 了

    char buf[8192]
    
    // Flush. Make sure buf[0] and buf[4096] are not cached
    clflush buf[0]
    clflush buf[4096]
    
    <some expensive inst like div, sqrt>
    
    r1 = <a kernel virtual addr>
    r2 = *r1
    r2 = r2 & 1
    r2 = r2 * 4096
    r3 = buf[r2]
    
    <handle page fault from "r2 = *r1">
    
    // Reload. Test time
    a = rdstc
    r0 = buf[0]
    b = rdstc
    r1 = buf[4096]
    c = rdstc
    if b - a < c - b
      low bit is probably a 0

首先我们 clflush 保证 buf\[0\] 和 buf\[4096\] 不在 cache 中。之所以差这么大，是为了防止 load 的时候，硬件会从内存中再加载相邻的几个数据到 cache 中，我们不希望在加载 buf\[a\] 时把 buf\[b\] 也带上了

接下来会调用一些非常耗时的指令。这些耗时的指令同样会被预测执行，即在结果出来之前，会提前执行后面的内容。这样，在 `r2 = *r1` 实际产生 Page Fault 前，还要等待这些耗时指令 Retired。这样可以争取时间，我们需要保证在 load buf\[r2\] 被预测执行

`r3 = buf[r2]` 虽然不会对寄存器产生直接影响，但是这会导致 buf\[r2\] 被 cache

Page Fault 最终还是会发生，但是现代的 OS 又给予了用户程序操作内存的接口。我们可以用 sigaction 注册一个 Page Fault Handler，并且在Page Fault 之后重新获得控制

之后我们重新 load buf\[0\] 与 buf\[4096\]，比较二者的 load 时间。若是 buf\[0\] 的读取时间短，则说明很大可能当时 r3 load 的是 buf\[0\]，也就是说，那个内核虚拟地址所在的 bit 是 0，反之为 1

我们通过这种方式读取内核空间的数据

  

这种攻击可以用与这些场合：第一种是云计算：如果你使用了云服务商，它会在同一个计算机上运行多个用户的业务，那么你或许就可以窥探其他运行在同一个机器上的用户软件的内存；另一个可能有用的场景是，当你的浏览器在访问 web 时，你的浏览器其实运行了很多不被信任的代码，或许是以插件的形式，或是以 javascript 的形式。这些代码会被加载到浏览器，然后被编译并被运行

很多操作系统在论文发表之后数周内就推出的一个快速修复，叫做 KAISER，现在在 Linux 中被称为 KPTI 的技术（Kernel page-table isolation）。这里的想法很简单，也就是不将内核内存映射到用户的 Page Table 中。这样一来就会有 Page Table 的切换，并且因为现在的用户页表并没有包含对 r1 存储的内核虚拟地址的翻译，r2 无法读取，Meltdown Attack 也就不能工作了，缺点是系统调用的代价更高了

除此之外，还有一个合理的硬件修复：CPU 完全可以在获取数据的时候检查权限标志位，如果检查不能通过，CPU 不会返回数据到 CPU 核中