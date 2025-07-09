---
title: CS61B 学习笔记 - Shortest Paths
id: d561a044-9efa-43a6-a01c-8831ed85369e
date: 2024-07-30 12:30:43
auther: admin
cover: 
excerpt: Dijkstra 与 A*
permalink: /archives/cs61b-shortest-paths
categories:
 - notes
 - courses
tags: 
 - cs61b
---

## Dijkstra's Algorithm

还是贴伪代码

    def dijkstras(source):
        # 初始化最小优先队列，存储节点与该节点到起点的最短距离
        # 设置起点距离为 0，其他节点距离无限
        PQ.add(source, 0) 
        For all other vertices, v, PQ.add(v, infinity)
        while PQ is not empty:
            # 出队剩余未操作节点中距离最短的节点
            p = PQ.removeSmallest()
            relax(all edges from p)
    
    def relax(edge p,q):
       if q is visited (i.e., q is not in PQ):
           return
        
       # 若是新路径的距离更短，更新
       if distTo[p] + weight(edge) < distTo[q]:
           distTo[q] = distTo[p] + w
           edgeTo[q] = p
           PQ.changePriority(q, distTo[q])
    

在图中存在负边的情况下，Dijkstra 算法不能保证正确。这可能有用……但这并不能保证有效。

  

## A\*

Dijkstra 算法其实像是以起点为中心，向四面八方进行地毯式搜索。但假如我只是搜索武汉到北京的最短路径，我有必要搜索到西藏地区吗？

当然不会，因为我们知道我们应该向北搜索，而不是转向西南方向。为什么？因为武汉以北的城市会距离北京越来越近，而西南方向的城市会越来越远。

让我们稍微修改一下Dijkstra算法。在Dijkstra的算法中，我们使用 bestKnownDistToV 作为算法中的优先级（也就是说，PQ 选择最小节点的标准是选择已知距离出发点最近的节点）。这一次，我们将使用 bestKnownDistToV + estimateFromVToGoal 作为我们的启发式，换言之，我们先对路上的所有城市到目标的距离经行一个估计，然后以**节点到出发点的距离 + 节点到目标距离的估计值**作为选择标准。

可以通过[这个幻灯片](https://docs.qq.com/slide/DR0dQRXpPeE5vbm9k)查看 A\* 的运行，注意下方 Fringe 的动态，h(v, goal) 是 estimateFromVToGoal

我们的启发式`heuristic(v, target)`必须满足两个条件：

1.  `heuristic(v, target)` 必须小于等于 v 到 target 的真实距离
    
2.  对于 v 的每个邻居 w:
    
        heuristic(v, target) <= dist(v, w) + heuristic(w, target)
        
    
    我们姑且把`heuristic(v, target)`认为是 v 到 target 的估计距离吧，上面这句话的意思便是，**v到target的估计距离 不得大于 v到w的距离 与 w到target的估计距离 之和**