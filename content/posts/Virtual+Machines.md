---
title: Virtual Machines
id: 7d7a9508-565b-42ef-8fa9-74223ab5b6cc
date: 2024-09-01 13:42:00
auther: admin
cover: 
excerpt: Trap-and-Emulate 风格的 VMM 与 VT-x
permalink: /archives/virtual-machines
categories:
 - notes
 - courses
tags: 
 - mit-6.s081
 - OS
---

## Host & Guest

虚拟机是对于计算机的模拟，顾名思义。QEMU 可以说是虚拟机的一个例子

在虚拟机架构的最底层，位于硬件之上存在一个 Virtual Machine Monitor（VMM），它取代了标准的操作系统内核。VMM 的工作是模拟多个计算机用来运行 Guest 操作系统。VMM 往上一层是 Guest 空间，对比一个操作系统的用户空间

在 Host 空间运行的是VMM，在 Guest 空间运行的是普通的操作系统。除此之外，在 Guest 空间又可以分为 Guest Supervisor Mode 和 Guest User Mode

我们的目的是让运行在 Guest 中的代码完全不能区分自己是运行在一个虚拟机还是物理机中，因为我们希望能在虚拟机中运行任何操作系统。这意味着对于任何操作系统的行为包括使用硬件的方式，虚拟机都必须提供提供对于硬件的完全相同的模拟，这样任何在真实硬件上能工作的代码，也同样能在虚拟机中工作；我们同样不希望 Guest 从虚拟机中逃逸

但是实际中出于性能的考虑，很难做到完全的模拟。出于效率的考虑，在 VMM 允许的前提下，Linux 某些时候知道自己正在与 VMM 交互，以获得对于设备的高速访问权限。不过实现虚拟机的大致策略还是完全准确的模拟物理服务器

  
  

## Trap-and-Emulate

### How to build VMM

一种构建 VMM 的方式是完全通过软件模拟（比如用数组模拟寄存器，用 C 代码模拟指令行为），但是很慢，因为你的 VMM 在解析每一条 Guest 指令的时候，都可能要转换成几十条实际的机器指令，这会导致运行速度慢几个数量级。

相应的，一种广泛使用的策略是在真实的 CPU 上运行 Guest 指令。但是前面说过，我们将 Guest kernel 按照一个 Linux 中的普通用户进程来运行，所以 Guest kernel 现在运行在 User mode，这样在运行 privileged 指令时又会出现问题。但是如果我们蠢到将 Guest kernel 运行在宿主机的 Supervisor mode。那么我们的 Guest kernel 不仅能够修改真实的 Page Table，同时也可以从虚拟机中逃逸，因为它现在可以控制 PTE（Page Table Entry）的内容，并且读写任意的内存内容

相应的，这里会使用一些技巧

### Trap

一旦 Guest 操作系统需要使用 privileged 指令，它会触发 trap 走到 VMM 中，之后我们就可以获得控制权。VMM 可以查看是什么指令引起的trap，并做适当的处理。假如 Guest 要写入 SATP，VMM 处理这个 trap，但它可以使用一些 trick，而不是真的改变真实寄存器

这里核心的点在于，我们自己写的可信赖的 VMM 运行在 Supervisor mode，而我们将不可信赖的 Guest kernel 运行在 User mode，通过一系列的处理使得 Guest kernel 看起来好像自己是运行在 Supervisor mode

### Emulate

刚刚所说的 trick 是 Emulate

VMM 会为每一个 Guest 维护一套虚拟状态信息。所以 VMM 里面会维护虚拟的 STVEC 寄存器，虚拟的 SEPC 寄存器以及其他所有的 privileged 寄存器。当 Guest 操作系统运行指令需要读取某个 privileged 寄存器时，首先会通过 trap 走到 VMM，VMM 会检查这条指令并发现这是一个比如说读取 SEPC 寄存器的指令，之后 VMM 会模拟这条指令，并将自己维护的虚拟 SEPC 寄存器，拷贝到 trapframe 的用户寄存器中（在 trap 的最后恢复寄存器时，会从 trapframe 中拷贝到真实寄存器，这里会将 a0 的值设置为虚拟的 SEPC 的值，作为函数返回值），再通过 sret 指令，使得 Guest 从 trap 中返回。最终，Guest 读到了 VMM 替自己保管的虚拟 SEPC 寄存器

VMM 不使用真实的 privileged 寄存器，还有其他原因。比如 Guest 系统调用时，Guest 的 SCAUSE 寄存器会表明这是一个系统调用，而对于 VMM 来说却是因为指令越权。通常情况下，VMM 需要看到真实寄存器的值，而 Guest 操作系统需要能看到符合自己视角的寄存器的值

在这种虚拟机的实现中，Guest 整个运行在用户空间，任何时候它想要执行需要 privilege 权限的指令时，会通过 trap 走到 VMM，VMM 可以模拟这些指令。这种实现风格叫做 Trap and Emulate

除了保存控制寄存器，VMM 还需要保存 Guest 当前的 mode（这个可以通过 sret 知道），还需要跟踪当前模拟那个 CPU 保存 hartid

继续上文返回的过程。当 Guest 执行 sret 从 Supervisor mode 进入到 User mode，VMM 会更新虚拟状态信息中的 mode 为 User mode，会将真实的 SEPC 设置成自己保存在虚拟状态信息中的虚拟 SEPC（之后 Guest 还要再硬件上执行），同时，还需要切换 Page table

综上所述，Guest 中的用户代码，如果是普通的指令，就直接在硬件上执行。当 Guest 中的用户代码需要执行系统调用时，会通过执行 ECALL 指令走到 VMM 中，VMM 可以发现当前在虚拟状态信息中记录的 mode 是 User mode，并且发现当前执行的指令是 ECALL，之后 VMM 会更新虚拟状态信息以模拟一个真实的系统调用的 trap 状态：设置虚拟的 SEPC 为 ECALL 指令所在的程序地址（这是为 Guest 的 sret 准备）；将虚拟的 mode 更新成 Supervisor；将虚拟的 SCAUSE 设置为系统调用；将真实的 SEPC 设置成虚拟的 STVEC 寄存器。之后调用 sret 指令跳转到 Guest操作系统的 trap handler，也就是 STVEC 指向的地址

### Page Table

我们不想让 VMM 只是简单的替 Guest 设置真实的 SATP 寄存器，因为这样的话 Guest 就可以访问任意的内存地址，而不只是 VMM 分配给它的内存地址，但是我们的确又需要做点什么，因为我们需要让 Guest 觉得 Page Table 被更新了

真实的过程是，我们不能直接使用 Guest 操作系统的 Page Table，VMM 会生成一个新的 Page Table 来模拟 Guest 操作系统想要的 Page Table

所以现在的 Page Table 翻译过程略微有点不一样，首先是 Guest kernel 包含了Page Table，但是这里是将 Guest 中的虚拟内存地址（gva）映射到了 Guest 的物理内存地址（gpa）。而 Guest 的物理地址是一个假象，VMM 不会真放在宿主机物理内存为 0 的起始点，甚至不会是连续的空间。相应的，VMM会为每个虚拟机维护一个映射表，将Guest物理内存地址映射到真实的物理内存地址（hpa）。这个映射表与 Page Table 类似，对于每个 VMM 分配给 Guest 的物理页，都有一条记录表明真实的物理页是什么

当 Guest 向 SATP 寄存器写了一个新的 Page Table 时，在对应的 trap handler 中，VMM 会创建一个 Shadow Page Table，Shadow Page Table 的地址将会是 VMM 向真实 SATP 寄存器写入的值，它将 gva 映射到了 hpa。Shadow Page Table 是这么构建的：

1.  从 Guest Page Table 中取出每一条记录，查看 gpa
    
2.  使用 VMM 中的映射关系，将 gpa 翻译成 hpa
    
3.  再将 gva 和 hpa 存放于 Shadow Page Table
    

在创建完之后，VMM 会将 Shadow Page Table 设置到真实的 SATP 寄存器中，再返回到 Guest 内核中

所以，Guest kernel 认为自己使用的是一个正常的 Page Table，但是实际的硬件使用的是 Shadow Page Table。这种方式可以阻止 Guest 从被允许使用的内存中逃逸。Shadow Page Table 只能包含 VMM 分配给虚拟机的主机物理内存地址。Guest 不能向 Page Table 写入任何 VMM 未分配给 Guest 的内存地址

但是若果是直接修改自己页表的 Entry，RISC-V 并不承诺可以立即观察到对于 PTE 的修改，在修改那一瞬间，你完全是不知道 PTE 被修改了。这需要 Guest 在修改后执行 sfence.vma 指令使硬件注意到修改。这个特权指令会触发 trap，然后 VMM 会检查修改的合法性

### Devices

对于虚拟机外部设备的模拟，人们通常拥有 3 种方案：

第一种是对真实设备的模拟。以磁盘为例，Guest 并不是拥有一个真正的磁盘设备，只是 VMM 使得与 Guest 交互的磁盘看起来好像真的存在一样。VMM 会将设备 Memory Map 控制寄存器本来映射在特定位置的页设置成无效，当 Guest 希望与设备进行交互的时候就会触发 trap，VMM 就可以模拟设备的行为

显然易见，这种实现的方式极其低效，因为 VMM trap 的开销极高。但是如果你的目标就是能启动操作系统并使得它们完全不知道自己运行在虚拟机上，你只能使用这种策略

第二种策略是提供虚拟设备，而不是模拟一个真实的设备。策略二并没有卑微地模仿真实的设备，某些设计人员提出了一种设备驱动，这种设备驱动并不对接任何真实的硬件设备，而是只对接由VMM实现的虚拟设备。在内存中会有一个命令队列，Guest 操作系统将读写设备的命令写到队列中，之后 VMM 会从内存中读取这些命令，但是并不会将它们应用到磁盘中，而是将它们应用到一个文件，这个文件模拟了一个虚拟磁盘。这种驱动设计的并不需要很多trap，并且这种驱动与对应的虚拟设备是解耦的，并不需要立即的交互

第三个策略是对于真实设备的 pass-through，这里典型的例子就是网卡。你可以配置你的网卡，使得它表现的就像多个独立的子网卡，每个 Guest 操作系统拥有其中一个子网卡。经过 VMM 的配置，Guest 操作系统可以直接与它在网卡上那一部分子网卡进行交互，并且效率非常的高

  
  

## 对虚拟机的硬件支持

这里的硬件支持特指 Intel 的 VT-x

硬件里有一套完全独立，专门为 Guest mode（这里的 Guest mode 是硬件的称呼）下使用的虚拟控制寄存器。在 Guest mode 下可以直接读写控制寄存器，但是读写的是寄存器保存在硬件中的拷贝，而不是真实的寄存器。这样 Guest 中的软件可以直接执行 privileged 指令来修改保存在硬件中的虚拟寄存器，而不是通过 trap 走到 VMM 来修改保存在软件中的虚拟寄存器

硬件的 Guest mode 也被称为 non-root mode，对应的使用真实寄存器的 Host mode，也被称为 root mode，这些是为了防止虚拟机逃逸的措施

现在当VMM想要创建一个新的虚拟机时，VMM需要配置硬件。在VMM的内存中，通过一个结构体与 VT-x 硬件进行交互。这个结构体称为 VMCS（注，Intel的术语，全称是Virtual Machine Control Structure）。当 VMM 要创建一个新的虚拟机时，它会先在内存中创建这样一个结构体，并填入一些配置信息和所有寄存器的初始值，之后 VMM 会告诉 VT-x 硬件说我想要运行一个新的虚拟机，并且虚拟机的初始状态存在于 VMCS 中

通过硬件的支持，Guest 现在可以在不触发 trap 的前提下，直接执行普通的 privileged 指令。但是还是有一些原因需要让代码执行从 Guest 进入到 VMM 中，其中一个原因是调用 VMCALL 指令，另一个原因是设备中断，例如定时器中断会使得代码执行从 non-root 模式通过 trap 走到 VMM

但是我们也不能让 Guest 任意的修改它的 Page Table，我们需要控制其能访问的内存。所以 VT-x 的方案中，还存在另一个重要的寄存器：EPT（Extended Page Table）。EPT 会指向一个 Page Table。当VMM启动一个 Guest kernel 时，VMM 会为 Guest kernel 设置好 EPT，并告诉硬件这个 EPT 是为了即将运行的虚拟机准备的

之后，当计算机上的 MMU 在翻译 Guest 的虚拟内存地址时，它会先根据 Guest 设置好的 Page Table，将 Guest 虚拟地址（gva）翻译到 Guest 物理地址（gha）。之后再通过 EPT，将 Guest 物理地址（gha）翻译成主机物理地址（hpa）。硬件会为每一个 Guest 的每一个内存地址都自动完成这里的两次翻译。EPT 使得 VMM 可以控制 Guest 可以使用哪些内存地址。Guest 可以非常高效的设置任何想要的 Page Table，但是 Guest 能够使用的内存地址仍然被 EPT 所限制，而 EPT 由VMM所配置

另外，每一个 CPU 核都有一套独立的 VT-x 硬件。所以每一个 CPU 核都有属于自己的 32个通用寄存器，属于自己的真实的控制寄存器，属于自己的用在 Guest mode 下的虚拟控制寄存器，属于自己的 EPT

我们也可以利用这个机制去运行一些不被信任的代码（比如浏览器插件和 js）