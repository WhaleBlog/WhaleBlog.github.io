---
title: CS61B 学习笔记 - BST & B-Trees
id: 40abbbe7-dda6-43b3-8458-34678b0ad569
date: 2024-07-30 07:55:29
auther: admin
cover: 
excerpt: 二叉搜索树的操作与B树原理的简要介绍
permalink: /archives/cs61b-BST-BTrees
categories:
 - notes
 - courses
tags: 
 - cs61b
 - data structure
---

我们都知道，二分搜索，比起一个一个查找，有着非常优秀的运行时间。但是对于一个单向链表，这种算法似乎就束手无策了。

![link list.png](/upload/link%20list.png)

但是，如果我们换种思路，从最开始如何形成这个“链表”，也就是数据结构下手的话......二分查找不就没有问题了吗？

![binary tree.png](/upload/binary%20tree.png)

  

## 1\. BST Definitions

### Tree

由节点和连接这些节点的边组成，任意两个节点之间只有一条路径

### Binary Tree

除了上述要求外，还满足二叉属性约束。即，每个节点有0、1或2个子节点

### Binary Search Tree

除了上述所有要求外，还满足以下性质：

对于树中的每个节点X：

左子树中的每个键都小于X的键

右子树中的每个键都大于X的键

  

## 2\. BST Operations

### find

得益于二叉搜索树的特性，我们可以很简单地使用二分查找
```Java
static BST find(BST T, Key sk) {
    if (T == null)
        return null;
    if (sk.equals(T.key))
        return T;
    else if (sk ≺ T.key)
        return find(T.left, sk);
    else
        return find(T.right, sk);
}
```   

### insert

只需注意在插入时也保持左边小，右边大的特性就行
```Java
static BST insert(BST T, Key ik) {
    if (T == null)
        return new BST(ik);
    if (ik ≺ T.key)
        T.left = insert(T.left, ik);
    else if (ik ≻ T.key)
        T.right = insert(T.right, ik);
    return T;
}
```   

### delete

删除操作的话则需更具被删除节点的子节点数分情况讨论：

0 个子节点：直接删除，相信 Java 的垃圾收集

1 个子节点：直接将子节点替上

2 个子节点：不替上任意一个子节点，相反，为这两个字节点重新寻找一个满足 BST 特性的父节点。比如，被删除节点的左子树最右边的节点（比左子树其他的节点都要大，且小于右节点所有节点），右子树最左边的节点（比右子树其他节点都要小，且大于左子树所有节点）

比如当我们要删除 dog 时，我们应当用 cat 或 elf 替换

![BST delete.png](/upload/BST%20delete.png)

  

## 3\. BST Performance

BST的高度和平均深度是决定性能的重要属性。高度指的是最深的叶子的深度，是树的属性；而深度指的是特定节点到根的距离，是特定于节点的属性。树的平均深度是每个节点深度的平均值。

高度和平均深度决定了BST操作的运行时间。高度决定了查找节点的最坏情况运行时间，而平均深度决定了搜索操作的平均情况运行时间。

插入节点的顺序对BST的高度和平均深度有很大的影响。例如，考虑插入节点1、2、3、4、5、6、7。这导致了一个细长的BST，高度为6，平均深度为3。如果我们按照4、2、1、3、6、5、7的顺序插入相同的节点，我们得到的高度是2，平均深度是1.43。

![insert order diff.png](/upload/insert%20order%20diff.png)

我们自然希望树是茂密的而非细长的，但是我们往往无法决定插入的顺序。因此，我们需要找到一种方法去维持 BST 的 "bushiness"

  

## 4\. B-Trees

这里是一个 [B树的实现](https://algs4.cs.princeton.edu/code/edu/princeton/cs/algs4/BTree.java)

在这里可以将 [B树操作可视化](https://www.cs.usfca.edu/~galles/visualization/BTree.html)

### Avoiding Imbalance

如果可以尽可能保证树的高度不变，我们自然可以保证树的茂密。一种想法是，我们可以“过度填充”叶节点：不是将插入节点放在叶节点之下，而是和它“挤”在一起。

![overstuffing.png](/upload/overstuffing.png)

但是，若是让叶节点无限拓张，我们等于又回到了线性问题。

### Moving Items Up

所以，当叶节点挤到一定数量后，我们可以考虑将其上移。比如，当叶节点数量超过 3 时，我们使其中一个节点上移。然后，我们再插入 18，19：

![moving up.png](/upload/moving%20up.png)

好吧，这样我们放弃了二叉搜索属性，但是取而代之，我们将 15-17 这个过度填充节点的子节点重新分为了 3 类：(−∞, 15), \[15, 17\], (18, +∞)，这样我们可以保持和 BST 类似的操作。

插入节点可能会导致连锁反应，比如下图插入 25，26 后：

![chain react.png](/upload/chain%20react.png)

### Invariants

由于b树的构造方式，它们有两个不变的特性:

1.  所有的叶子到根的距离相同。
    
2.  具有k项的非叶节点必须恰好有k + 1个子节点。
    

这两个不变量保证了茂密树具有 logN 高度