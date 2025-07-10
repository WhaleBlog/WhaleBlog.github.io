---
title: xv6 实验日志 - Trap
id: a4db0ff5-1f29-4950-8942-fd203ea161cf
date: 2024-08-14 20:28:07
auther: admin
cover: 
excerpt: 仅简述从用户模式陷入内核的过程
permalink: /archives/xv6-trap
categories:
 - courses
tags: 
 - xv6
 - mit-6.s081
 - OS
---

今天在看系统调用的时候发现自己把 xv6 的内存映射的约定给忘了。因为害怕后续做实验的时候会把前面花了不少时间才弄明白的机制遗忘，所以决定简单记录一下

今天看的是陷阱，目前只讨论从用户态陷入内核态的流程。我对源代码进行了注释，但是放在了 pgtbl 分支下，不方便以后做实验看，便就贴在这了

关于课程，有佬做了中文精翻：[Trap 机制](https://mit-public-courses-cn-translatio.gitbook.io/mit6-s081/lec06-isolation-and-system-call-entry-exit-robert/6.1-trap)，阅读体验极佳

## 0\. 一些前置知识

STVEC（Supervisor Trap Vector Base Address Register）寄存器，它指向了内核中处理 trap 的指令的起始地址

SEPC（Supervisor Exception Program Counter）寄存器，在trap的过程中保存程序计数器的值

SSRATCH（Supervisor Scratch Register）寄存器，有点像临时寄存器

SATP（Supervisor Address Translation and Protection）寄存器，它包含了指向page table的物理内存地址

ecall 指令会做如下 3 件事：

1.  从 user mode 切到 supervisor mode
    
2.  将程序计数器的值保存在了 SEPC
    
3.  跳转到 STVEC 寄存器指向的指令
    

sret 指令会做：

1.  程序会切换回 user mode
    
2.  SEPC 的值会被拷贝到 PC
    
3.  重新打开中断
    

supervisor mode 并不那么特权，在这个模式下只能做两件事情：

1.  访问控制寄存器
    
2.  对 PTE\_U = 0 的页进行操作（也就是说不能操作 PTE\_U = 1 的页，不能直接访问物理地址）
    

trampoline 在 用户空间与内核空间会被映射在相同的虚拟地址，说明书中给出的原因是：

> A major constraint on the design of xv6’s trap handling is the fact that the RISC-V hardware does not switch page tables when it forces a trap. This means that the trap handler address in stvec must have a valid mapping in the user page table, since that’s the page table in force when the trap handling code starts executing. Furthermore, xv6’s trap handling code needs to switch to the kernel page table; in order to be able to continue executing after that switch, the kernel page table must also have a mapping for the handler pointed to by stvec.

## 1\. Trap 流程

1.  执行 ecall 后会跳转到 uservec (trampoline.S)
    
2.  uservec 转而执行 usertrap()，在其中根据 scause 调用 syscall (trap.c)
    
3.  在 usertrap() 的最后调用 usertrapret()
    
4.  最后进入 userret (trampoline.S)，执行 sret 后结束
    

在 [xv6](https://pdos.csail.mit.edu/6.828/2020/xv6/book-riscv-rev1.pdf) 书中的第四章有更为详细的介绍

## 2\. 流程源代码与注释

另外，关于 trapframe 的结构请查看 proc.h 文件；有关访问控制寄存器的函数可在 riscv.h 中看到；有关内核页表以及用户页表的布局可以看 memlayout.h

### uservec

vec 是 vector（中断向量）的缩写。\*vec 指向了操作系统处理特定中断事件时所应该执行的代码的内存地址，故用 vec 命名。

    .globl trampoline
    trampoline:
    .align 4
    .globl uservec
    uservec:    
    	#
            # trap.c sets stvec to point here, so
            # traps from user space start here,
            # in supervisor mode, but with a
            # user page table.
            #
            # sscratch points to where the process's p->trapframe is
            # mapped into user space, at TRAPFRAME.
            #
            
    	# swap a0 and sscratch
            # so that a0 is TRAPFRAME
            csrrw a0, sscratch, a0
            # 交换 a0 与 sscratch 的值
    
            # save the user registers in TRAPFRAME
            sd ra, 40(a0)
            sd sp, 48(a0)
            sd gp, 56(a0)
            sd tp, 64(a0)
            sd t0, 72(a0)
            sd t1, 80(a0)
            sd t2, 88(a0)
            sd s0, 96(a0)
            sd s1, 104(a0)
            sd a1, 120(a0)
            sd a2, 128(a0)
            sd a3, 136(a0)
            sd a4, 144(a0)
            sd a5, 152(a0)
            sd a6, 160(a0)
            sd a7, 168(a0)
            sd s2, 176(a0)
            sd s3, 184(a0)
            sd s4, 192(a0)
            sd s5, 200(a0)
            sd s6, 208(a0)
            sd s7, 216(a0)
            sd s8, 224(a0)
            sd s9, 232(a0)
            sd s10, 240(a0)
            sd s11, 248(a0)
            sd t3, 256(a0)
            sd t4, 264(a0)
            sd t5, 272(a0)
            sd t6, 280(a0)
    
    	# save the user a0 in p->trapframe->a0
            csrr t0, sscratch
            sd t0, 112(a0)
            # 将 SSRATCH 的值复制到 t0 中，再将 t0 存 p->trapframe->a0
            # trapframe 的 a0 存的便是原来的 a0
    
            # restore kernel stack pointer from p->trapframe->kernel_sp
            ld sp, 8(a0)
            # trapframe 的 kernel_sp 复制到当前 sp，切到内核栈
    
            # make tp hold the current hartid, from p->trapframe->kernel_hartid
            ld tp, 32(a0)
    
            # load the address of usertrap(), p->trapframe->kernel_trap
            ld t0, 16(a0)
            # 后面会跳转到 t0 的地址，即 usertrap() 函数
    
            # restore kernel page table from p->trapframe->kernel_satp
            ld t1, 0(a0)
            csrw satp, t1
            sfence.vma zero, zero
            # 将 trapframe 的内核页表地址复制到 t1
            # 将 stap 设置为 t1，及从用户页表切换成了内核页表
            # 地址转换是由硬件完成的，为了保证 trampoline.S 的代码还能
            # 顺利执行，内核页表与用户页表需保证对这段代码有相同的映射
    
            # a0 is no longer valid, since the kernel page
            # table does not specially map p->tf.
            # 在用户页表中 trapframe 被映射到 trampoline 下方
            # 但内核页表中没这个规定
            # 也就是说，a0 中所存的用户空间的 trapframe 地址
            # 在切换成内核页表后就没用了
    
            # jump to usertrap(), which does not return
            jr t0

### usertrap
```C
void
usertrap(void)
{
    int which_dev = 0;
    
    // r_sstatus 返回 sstatus 的值，见 riscv.h
    if((r_sstatus() & SSTATUS_SPP) != 0)
        panic("usertrap: not from user mode");
    
    // send interrupts and exceptions to kerneltrap(),
    // since we're now in the kernel.
    w_stvec((uint64)kernelvec);
    // 后续系统调用之类的操作也会触发异常
    // 所以要更改异常处理函数
     
    struct proc *p = myproc();
      
    // save user program counter.
    p->trapframe->epc = r_sepc();
    // ecall 指令做了 3 件事:
    // 1. user mode -> supervisor mode
    // 2. 将 ecall 指令所处地址保存到 sepc
    // 3. 跳转到 stvec 所指位置，及 uservec
    // 所以，这里是将当前进程的 trapframe 的 epc 设置为返回地址 
      
    if(r_scause() == 8){
        // system call
    
        if(p->killed)
            exit(-1);
    
        // sepc points to the ecall instruction,
        // but we want to return to the next instruction.
        p->trapframe->epc += 4;
    
        // an interrupt will change sstatus &c registers,
        // so don't enable until done with those registers.
        intr_on();
    
        syscall();
        // syscall() 的返回值会存储在 trapframe 的 a0 中
    } else if((which_dev = devintr()) != 0){
        // ok
    } else {
        printf("usertrap(): unexpected scause %p pid=%d\n", r_scause(), p->pid);
        printf("            sepc=%p stval=%p\n", r_sepc(), r_stval());
        p->killed = 1;
      }
    
      if(p->killed)
          exit(-1);
    
      // give up the CPU if this is a timer interrupt.
      if(which_dev == 2)
          yield();
    
      usertrapret();
}
```

### usertrapret
```C
void
usertrapret(void)
{
    struct proc *p = myproc();
    
    // we're about to switch the destination of traps from
    // kerneltrap() to usertrap(), so turn off interrupts until
    // we're back in user space, where usertrap() is correct.
    intr_off();
    
    // send syscalls, interrupts, and exceptions to trampoline.S
    w_stvec(TRAMPOLINE + (uservec - trampoline));
    
    // set up trapframe values that uservec will need when
    // the process next re-enters the kernel.
    p->trapframe->kernel_satp = r_satp();         // kernel page table
    p->trapframe->kernel_sp = p->kstack + PGSIZE; // process's kernel stack
    p->trapframe->kernel_trap = (uint64)usertrap;
    p->trapframe->kernel_hartid = r_tp();         // hartid for cpuid()
    
    // set up the registers that trampoline.S's sret will use
      // to get to user space.
      
    // set S Previous Privilege mode to User.
    unsigned long x = r_sstatus();
    x &= ~SSTATUS_SPP; // clear SPP to 0 for user mode
    x |= SSTATUS_SPIE; // enable interrupts in user mode
    w_sstatus(x);
    
    // set S Exception Program Counter to the saved user pc.
    w_sepc(p->trapframe->epc);
    
    // tell trampoline.S the user page table to switch to.
    uint64 satp = MAKE_SATP(p->pagetable);
    
    // jump to trampoline.S at the top of memory, which 
    // switches to the user page table, restores user registers,
    // and switches to user mode with sret.
    uint64 fn = TRAMPOLINE + (userret - trampoline);
      ((void (*)(uint64,uint64))fn)(TRAPFRAME, satp);
}
```

### userret
```Risc-V
    .globl userret
    userret:
            # userret(TRAPFRAME, pagetable)
            # switch from kernel to user.
            # usertrapret() calls here.
            # a0: TRAPFRAME, in user page table.
            # a1: user page table, for satp.
    
            # switch to the user page table.
            csrw satp, a1
            sfence.vma zero, zero
    
            # put the saved user a0 in sscratch, so we
            # can swap it with our a0 (TRAPFRAME) in the last step.
            ld t0, 112(a0)
            csrw sscratch, t0
    
            # restore all but a0 from TRAPFRAME
            ld ra, 40(a0)
            ld sp, 48(a0)
            ld gp, 56(a0)
            ld tp, 64(a0)
            ld t0, 72(a0)
            ld t1, 80(a0)
            ld t2, 88(a0)
            ld s0, 96(a0)
            ld s1, 104(a0)
            ld a1, 120(a0)
            ld a2, 128(a0)
            ld a3, 136(a0)
            ld a4, 144(a0)
            ld a5, 152(a0)
            ld a6, 160(a0)
            ld a7, 168(a0)
            ld s2, 176(a0)
            ld s3, 184(a0)
            ld s4, 192(a0)
            ld s5, 200(a0)
            ld s6, 208(a0)
            ld s7, 216(a0)
            ld s8, 224(a0)
            ld s9, 232(a0)
            ld s10, 240(a0)
            ld s11, 248(a0)
            ld t3, 256(a0)
            ld t4, 264(a0)
            ld t5, 272(a0)
            ld t6, 280(a0)
    
    	# restore user a0, and save TRAPFRAME in sscratch
            csrrw a0, sscratch, a0
    	# 先将 trapframe 的 a0 保存到 sscratch 中
    	# 待 a0 寄存器写入后（此时存储的是第一个参数，即 trapframe 的地址）
    	# 交换二者的值，这样保证 sscratch 里存储了 trapframe
            
            # return to user mode and user pc.
            # usertrapret() set up sstatus and sepc.
            sret
```