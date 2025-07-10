---
title: CS61B 学习笔记 - Basic Sort
id: b04034a0-ad94-4980-b457-8e9794c2093b
date: 2024-07-30 16:03:25
auther: admin
cover: 
excerpt: 插入排序 选择排序 堆排序 归并排序
permalink: /archives/cs61b-sort
categories:
 - notes
 - courses
tags: 
 - cs61b
 - Data Structure
---

## In-place Insertion Sort

我们从数组的左边开始，每次选择一个元素进行交换。然后，我们将这个元素交换到它尽可能靠前的位置。数组的前端逐渐变得有序，直到整个数组都被排序。

![insert sort.png](/upload/insert%20sort.png)

在逆序数量较少的数组中，插入排序可能是最快的算法。另外，一个不太明显的经验是，插入排序在小数组（小于 15）上非常快，比快速排序与归并排序还快

  

## Selection Sort

选择排序使用以下算法：找到最小的项。把这一项放到前面。重复直到所有项目都固定

在数组中 Θ(N2) 的复杂度真有人会用吗......

  

## Heapsort

### Naive Heapsort

我们可以另起一个[堆](https://whalefall.site/archives/cs61b-MinPQ)，将所有的元素放入到这个堆中，再一个一个把最大值取出来

整体的运行时间是 Θ(NlogN)，毕竟无论是插入元素还是去除最小值都是 O(logN)

但是，为了另起一堆，我们又多花了 Θ(N) 的空间

### In-place Heapsort

最大堆删除最大元素时，是将根元素与数组最末尾交换，然后`sink(1)` 并设置最末尾为 null

而我们完全可以将这最末位的空间利用起来，不通过设置 null 的方式删除原来堆中的最大值，而是就这样将其存在末尾（这也是为什么使用最大而不是最小堆）

我们最开始只要将数组“堆化”，然后以上述方法不断将最大值放在堆的最后，最终我们便得到一个排序好的数组

你可以在[这里](https://docs.qq.com/slide/DR01makx4aVBQTlpC)看到这个算法的演示

  

## Merge Sort

有两个排序好的数组，如何将其合成一个排序好的数组：答案很简单，遍历两个数组，取二者最小，时间复杂度为两数组长度之和

![freecompress-merge sort.png](/upload/freecompress-merge%20sort.png)

要排序长度为 N 的数组，我们可以将其分成两个长度为 N / 2 的数组并对二者归并排序。N / 2 的数组又可以分成两个 N / 4 的数组，N / 4 又可以分成两个 N / 8...... 直到分成两个长度为 1 的数组

![freecompress-merge sort layer.png](/upload/freecompress-merge%20sort%20layer.png)

这样我们可以得到一颗高度为 Θ(logN) 的树，树的每一层都要进行 Θ(N) 次操作，时间复杂度为 O(NlogN)