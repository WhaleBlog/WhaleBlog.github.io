---
title: xv6 实验日志 - Page Table
id: eb6af358-b102-4a4b-8490-dff1ac68f182
date: 2024-08-15 10:56:03
auther: admin
cover: 
excerpt: Sv39 分页机制和 xv6 内核页表与用户页表的 memlayout
permalink: /archives/xv6-pgtbl
categories:
 - courses
 - notes
tags: 
 - mit-6.s081
 - xv6
 - OS
---

## 页表

这张图片很好地说明了 xv6 页表机制

![page table.png](/upload/page%20table.png)

其中补充说明几点：

1.  虚拟地址由三部分所组成：EXT（无实际作用，忽略），三级页表的 index，以及物理页的偏移量 offset
    
2.  每个页表占据一个 PGSIZE 的空间 （4096 bytes），每个页表内有 512 个条目，称为 PTE。每个 PTE 有 64 位，由 PPN 与 Flag 所组成。
    
3.  对于第一，第二级页表的 PPN，其所指向的是下一级页表的物理地址（由 PPN << 12 可得）。第三级页表的 PPN 指向的是虚拟地址所映射的物理页的起始地址，加上 va 的 offset 便可得到实际的 pa
    
4.  satp 寄存器指向第一级页表的物理地址
    
5.  PTE 中的 flag 在图片的下方有详细的描述
    
6.  OS 对于地址的映射有绝对的控制权，可以任意地将某个虚拟页映射到某个物理页
    
7.  虚拟地址到物理地址转换的步骤是由硬件的 MMU 实现的，OS 负责处理页表。但在 xv6 中有 walk() 函数模拟这一点，因为 xv6 通过直接写物理地址来实现内核空间与用户空间的传参
    
```C
// Return the address of the PTE in page table pagetable
// that corresponds to virtual address va.  If alloc!=0,
// create any required page-table pages.
//
// The risc-v Sv39 scheme has three levels of page-table
// pages. A page-table page contains 512 64-bit PTEs.
// A 64-bit virtual address is split into five fields:
//   39..63 -- must be zero.
//   30..38 -- 9 bits of level-2 index.
//   21..29 -- 9 bits of level-1 index.
//   12..20 -- 9 bits of level-0 index.
//    0..11 -- 12 bits of byte offset within the page.
pte_t *
walk(pagetable_t pagetable, uint64 va, int alloc)
{
    if(va >= MAXVA)
        panic("walk");
    
    for(int level = 2; level > 0; level--) {
        pte_t *pte = &pagetable[PX(level, va)];
    // 根据 va 中的 index 确认 pte 的位置
        if(*pte & PTE_V) {
            pagetable = (pagetable_t)PTE2PA(*pte);
        } else {
            if(!alloc || (pagetable = (pde_t*)kalloc()) == 0)
                return 0;
            memset(pagetable, 0, PGSIZE);
            *pte = PA2PTE(pagetable) | PTE_V;
        }
    }
    return &pagetable[PX(0, va)];
}
```
  

## 内核页表

下面这张图描述了内核页表中 va 与 pa 的映射关系。右半部分的物理地址是由硬件设计者决定的，具体内容会写在主板手册上；而左半部分是由操作系统设计者定义的，因为老师们想让 xv6 尽可能的简单易懂，所以这里的虚拟地址到物理地址的映射，大部分是相等的。

地址 0x1000 是 boot ROM 的物理地址，当你对主板上电，主板做的第一件事情就是运行存储在 boot ROM 中的代码，当boot完成之后，会跳转到地址 0x80000000，操作系统需要确保那个地址有一些数据能够接着启动操作系统

![memory.png](/upload/memory.png)

可以通过 vm.c 中的 kvminit 与 memlayout.h 以及 kernel.ld 看到内核页表的映射：
```C
// Make a direct-map page table for the kernel.
pagetable_t
kvmmake(void)
{
    pagetable_t kpgtbl;
    
    kpgtbl = (pagetable_t) kalloc();
    memset(kpgtbl, 0, PGSIZE);
    
    // uart registers
    kvmmap(kpgtbl, UART0, UART0, PGSIZE, PTE_R | PTE_W);
    
    // virtio mmio disk interface
    kvmmap(kpgtbl, VIRTIO0, VIRTIO0, PGSIZE, PTE_R | PTE_W);
    
    // PLIC
    kvmmap(kpgtbl, PLIC, PLIC, 0x400000, PTE_R | PTE_W);
    
    // map kernel text executable and read-only.
    kvmmap(kpgtbl, KERNBASE, KERNBASE, (uint64)etext-KERNBASE, PTE_R | PTE_X);
    
    // map kernel data and the physical RAM we'll make use of.
    kvmmap(kpgtbl, (uint64)etext, (uint64)etext, PHYSTOP-(uint64)etext, PTE_R | PTE_W);
    // etext 指向 text 段的末尾，后面是 data 段，在 kernel.ld 定义
    
    // map the trampoline for trap entry/exit to
    // the highest virtual address in the kernel.
    kvmmap(kpgtbl, TRAMPOLINE, (uint64)trampoline, PGSIZE, PTE_R | PTE_X);
    
    // map kernel stacks
    proc_mapstacks(kpgtbl);
      
    return kpgtbl;
}
 
// Initialize the one kernel_pagetable
void
kvminit(void)
{
    kernel_pagetable = kvmmake();
}
```

其中 TRAMPOLINE 被映射了两次，分别在与物理地址相等的虚拟地址，以及在 va 的最高处。这说明页表的映射不必要是一一对应，多对多也可以

kernel stack 也会被映射两次，在 kvmmake 最后会调用 proc\_mapstacks，那里又会将本映射在 kernel data 段的内核栈又映射到 va 的高处。但实际使用的是后者的映射，毕竟有保护页保护

> 学生提问：对于不同的进程会有不同的kernel stack吗？
> 
> Frans：答案是的。每一个用户进程都有一个对应的kernel stack
```C
// Allocate a page for each process's kernel stack.
// Map it high in memory, followed by an invalid
// guard page.
void
proc_mapstacks(pagetable_t kpgtbl) {
    struct proc *p;
      
    for(p = proc; p < &proc[NPROC]; p++) {
        char *pa = kalloc();
        if(pa == 0)
            panic("kalloc");
        uint64 va = KSTACK((int) (p - proc));
        kvmmap(kpgtbl, va, (uint64)pa, PGSIZE, PTE_R | PTE_W);
    }
}
```

其中 KSTACK 宏在 memlayout.h 定义
```C
#define KSTACK(p) (TRAMPOLINE - (p)*2*PGSIZE - 3*PGSIZE)
```
  

## 用户页表

用户页表的定义就简单很多，毕竟不需要考虑设备

![user pgtbl.png](/upload/user%20pgtbl.png)

和内核页表的映射不一样的是，用户空间的代码是从地址 0 开始的，这在调试的时候可辅助确认是处于用户还是内核。

trampoline 都映射到了虚拟地址的顶部，毕竟在异常处理时会从用户页表切换到内核页表，必须保证此段代码在二者中具有相同的 va，不然就乱套了

trapframe 结构则放在了 trapoline 底下，详情请见 [xv6 实验日志 - Trap](https://whalefall.site/archives/xv6-trap)

MAXVA 在 riscv.h 中定义，很显然，与虚拟地址有意义的位数相关
```C
#define MAXVA (1L << (9 + 9 + 9 + 12 - 1))
```