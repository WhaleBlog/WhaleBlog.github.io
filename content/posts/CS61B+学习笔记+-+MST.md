---
title: CS61B 学习笔记 - MST
id: 43df8eaa-e48c-4561-a888-5d69db645369
date: 2024-07-30 14:57:27
auther: admin
cover: 
excerpt: 最小生成树与寻找算法
permalink: /archives/cs61b-MST
categories:
 - notes
 - courses
tags: 
 - cs61b
---

## 1\. Minimum Spanning Trees

> A minimum spanning tree (MST) is the lightest set of edges in a graph possible such that all the vertices are connected. Because it is a tree, it must be connected and acyclic. And it is called "spanning" since all vertices are included.

最小生成树：连接图中所有节点，并使得连接的边和最小的树。

  

## 2\. Cut Property

我们将一张图随便分为两个部分，一部分标为灰色，另一部分标为白色。

这张图里面一定存在一个最小生成树，这棵树将所有的灰球连接起来，同时将所有的白球连接起来，并且在灰色部分与白色部分的“桥梁”（那些一端是灰球，一端是白球的边）之中，一定有一个“桥梁”属于最小生成树。且这个“桥梁”一定是所有“桥梁”之中，最短的那一条。

这就是所谓的 cut property

![freecompress-cut property.png](/upload/freecompress-cut%20property.png)

> We can define a cut as an assignment of a graph’s nodes to two non-empty sets (i.e. we assign every node to either set number one or set number two).
> 
> We can define a crossing edge as an edge which connects a node from one set to a node from the other set.
> 
> With these two definitions, we can understand the Cut Property; given any cut, the minimum weight crossing edge is in the MST.

  

## 3\. Prim's Algorithm

根据 cut property，我们可以很容易想到一种找到 MST 的方法：

当我们选取了起始节点时，我们相当于图分成了两部分：起始节点与其他节点，然后我们连接最短的“桥梁”，这张图又形成了两部分：已经包含 2 个节点的树与其他节点，再利用 cut property，又是两个部分......这样不断重复使用 cut property，我们就能找到 MST

但是这个算法有两个问题：第一个问题是我们很可能会遇到连接成环的现象；第二个问题是我们每次连接都要检查其他所有其他的边，速度慢了

防止环的形成方法非常简单：利用 [Disjoint Sets](https://whalefall.site/archives/cs61b-DisjointSets)。当我们连接节点 A, B 时，我们将 A, B 放在同一个集合。再连接 B, C 时，我们调用`connect(B, C)`，这样 A, B, C 就处在同一个集合。我们虽然没有直接连接 A, C，但是二者既然在同一集合中，说明必有一条从 A 到 C 的路径。假如我们尝试连接 A, C，然后发现 A, C 本来就在同一个集合中，便可知道会形成环进而取消操作。

关于第二个问题，这里有一个非常类似于 Dijkstra 的 [Optimized Prim's Algorithm 演示](https://docs.qq.com/slide/DR3NrUkxmTFBhVXBB)

  

## 4\. Kruskal's Algorithm

另一个寻找图的 MST 的算法是 Kruskal 算法。Kruskal 算法不是像 Prim 算法那样通过遍历节点来构造 MST，而是通过遍历边来找到 MST 算法如下：

1.  将所有边按权重由小到大排序
    
2.  在保证不会形成环的前提下，按排好的顺序将边加入到正在构建的 MST 中
    
3.  重复第 2 步，直到 MST 有 V - 1 条边（节点数 - 1）
    

这个算法实质上也利用了 cut property，实质上和 Prim 一样。实践中选择任意一种即可