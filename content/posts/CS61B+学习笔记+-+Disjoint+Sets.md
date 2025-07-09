---
title: CS61B 学习笔记 - Disjoint Sets
id: dada0563-cdc7-489e-a00d-d8c23de8d69d
date: 2024-07-29 08:19:40
auther: admin
cover: 
excerpt: 并查集的实现
permalink: /archives/cs61b-DisjointSets
categories:
 - courses
 - notes
tags: 
 - cs61b
---

## 1\. Interface

对于 Disjoint Sets，我们定义如下接口：
```Java
public interface DisjointSets {
    /** connects two items P and Q */
    void connect(int p, int q);
    
    /** checks to see if two items are connected */
    boolean isConnected(int p, int q); 
}
```
    

`connect` 方法会将两个整数归为同一个集合，`isConnected` 则用来判断两个整数是否为同一集合

例如，我们有四个元素 A，B，C，D

![image (1).avif](/upload/image%20(1).avif)

在调用`connect(A, B)` 后：

![image (2).avif](/upload/image%20(2).avif)

`isConnected(A, B) -> true`

`isConnected(A, C) -> false`

然后调用`connect(A, D)`：

![image (3).avif](/upload/image%20(3).avif)

于是有：

`isConnected(A, D) -> true`

`isConnected(A, C) -> false`

## 2\. Implements

完整的实现请参照 [WeightedQuickUnionUF](https://algs4.cs.princeton.edu/15uf/WeightedQuickUnionUF.java.html)

### 2.1 isConnected

我们使用`parent`数组来表示这样的不相交集。准确来说，使用数组来表示几颗棵树，处在同一棵树的元素，即拥有相同根节点的元素，属于同一个集合

顾名思义，`parent` 数组中，数组下标对应位置存储的是该元素的父节点。例如`parent[0] = 3` ，则元素 0 的父节点是 3 。若存储为负数，则表示该节点是根节点

下图是用数组表示的一个例子：

![9.3.1.png](/upload/9.3.1.png)

归功于这种结构，我们可以很方便地判断两个元素是否同属于一个集合。新建一个公共方法`find(int p)`，它返回元素`p` 的根节点
```Java
public int find(int p) {
    validate(p);
    while (parent[p] >= 0)
        p = parent[p];
    return p;
}
```

于是`find(2) == 0` ，`find(4) == 0` ,故而`isConnected(2, 4) == true`
```Java
public boolean isConnected(int p, int q) {
    return find(p) == find(q);
}
```  

### 2.2 connect

还是这张图：

![9.3.1.png](/upload/9.3.1.png)

现在，如果我们调用`connect(2, 3)` ，很自然的想法是，将`parent[3]` 设置为`2` ，这样 3 就成为了 2 的子节点，同时，0，1，2，3，4，5 就被放到了同一集合中，符合我们的期望

但是以效率的角度来说，我们不希望形成的树是细长的，我们希望它是扁平而又茂密的

![image.avif](/upload/image.avif)

如上图一颗细长树，`find()`所需时间为 O(N)。当我们调用 `find(4)`时，我们要想上寻找 4 次才能找到 0

但是，在最理想情况，我们完全可以让 0 成为其他所有元素的父节点，这样调用`find()`时只需要寻找一次，时间压缩到了 O(logN)

所以说，比起将 3 放在 2 底下，更应该放在根节点 0 下

![9.3.2.png](/upload/9.3.2.png)

而这样的实现并不困难，我们可以先调用`find(2)`和`find(3)`，然后再对其根节点进行操作就行了

但是，为什么是 3 放在 0 下，而不是 0 放在 3 下呢？

我们希望树的层数尽可能少，前者可以任维持 3 层，而后者会涨至 4 层，所以如此

为了使层数最少，我们将更小的树放在更大的树之下。为此，我们需要维护一个`size` 数组，记录以下标为根节点的树所含元素数量。在上图中，`size[0] == 6`，`size[3] == 2` ，所以我们将 3 放在 0 下

于是我们给出`connect()`的实现：
```Java
public void union(int p, int q) {
    int rootP = find(p);
    int rootQ = find(q);
    if (rootP == rootQ) return;
    
    // make smaller root point to larger one
    if (size[rootP] < size[rootQ]) {
        parent[rootP] = rootQ;
        size[rootQ] += size[rootP];
    }
    else {
        parent[rootQ] = rootP;
        size[rootP] += size[rootQ];
    }
    count--;
}
```