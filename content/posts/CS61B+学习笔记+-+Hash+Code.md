---
title: CS61B 学习笔记 - Hash Code
id: af832531-c586-447f-a965-1cb94afaa03f
date: 2024-07-30 09:13:29
auther: admin
cover: 
excerpt: Valid, Good Hashcodes
permalink: /archives/cs61b-hashCode
categories:
 - notes
 - courses
tags: 
 - cs61b
---

## Valid Hashcodes

有效的哈希码必须拥有一下两个属性：

1.  **确定性（Deterministic）**：如果两个对象A和B彼此相等（`A.equals(B) == true`），则它们的hashCode()函数返回相同的哈希码。这也意味着哈希函数不能依赖于在`equals()`方法中没有反映的对象属性。
    
    比如我们有一个类`Dog`，其`equals`方法是：
    
        @Override
        public boolean equals(Object other) {
            if (other == this) return true;
            if (other == null) return false;
            if (other.getClass() != this.getClass()) return false;
            Dog that = (Dog) other;
            return this.breed == that.breed;
        }
    
    那么我们的`hashCode()`就不能依赖`breed`之外的属性了
    
    另外，这也要求，**当我们重写**`hashCode()`**时，我们也必须同时重写**`equals()`，因为这是我们认为两个对象相等的唯一依据。
    
2.  **一致性（Consistent）**：hashCode()函数在同一个对象实例上每次调用时都返回相同的整数。这意味着hashCode()函数必须独立于时间/秒表、随机数生成器或任何在同一个对象实例上多次调用hashCode()函数时不会给出一致哈希码的方法。
    
    请注意，没有要求说不相等的对象应该有不同的哈希函数值，那怕每次只返回 -1，那也是一个有效的哈希码。
    

  

## Good Hashcodes

1.  hashCode()函数必须是有效的。
    
2.  hashCode()函数的值应该尽可能均匀地分布在整个整数集合上。
    
3.  hashCode()函数的计算应该相对快速（理想情况下是O(1)的常量时间数学运算）。