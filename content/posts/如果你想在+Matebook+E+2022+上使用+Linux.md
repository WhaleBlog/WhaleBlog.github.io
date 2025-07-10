---
title: 在 Matebook E 2022 上安装 Kubuntu18.04
id: 30733420-f9f3-4389-b936-1a8125e945a6
date: 2024-07-06 16:26:00
auther: admin
cover:
permalink: /archives/Linux-on-Matebook-E-2022
categories:
  - notes
tags:
  - linux
---

## 0\. 在开始之前

**P.S. 这篇博客的内容已过时**

这篇博客不牵涉启动盘的制作，磁盘分区以及系统安装的过程（这些内容你大可以 STFW，网络上有很多更加成熟的教程），目的更多在于方便本人重装之后能够快速上手，故而本文的内容比较杂，包括针对该设备的系统设置，常用工具的安装以及简单的美化

在 Matebook E 2022 这台设备上安装 Linux 时会遇到显卡驱动的问题，可以看看这个帖子：[Huawei Matebook e 2022 款 Iris Xe 显卡问题](https://bbs.archlinuxcn.org/viewtopic.php?id=12223)。对于我这台机子，在不开安全模式的情况下，屏幕的左右两侧会像地质断层一样上下割裂错位。我尝试了 Arch Linux 和 Ubuntu 24 到 19 的版本，皆会出现上述的情况。~~只有 Kubuntu 18.04 这个版本才能正常显示~~

~~好吧，如果你只是想用这台机器装一个可以使用的 Linux 系统的话，目前我已知最简单的方式，安装 [Kubuntu 18.04](https://mirrors.nju.edu.cn/ubuntu-cdimage/kubuntu/releases/18.04/) 吧~~

后面有佬做到了在这台设备上[安装 Arch Linux](https://www.cnblogs.com/Vanilla-chan/p/18365339/Huawei-Matebook-e-2022-install-archlinux-double-system)，并且详细讲述了后续的安装流程，我跟着他的说明成功安装。所以，如果是要在日常中使用的话，就没有必要将时间花在这篇老古董身上了

## 1\. 系统设置

Hardware -> Display and Monitor -> 将窗口拉大后可以看到 Scale Display -> 滑动 Scale 调整至 1.7 或 1.8

Power Management -> Energy Saving -> 自行设置（设备默认省电方案可能会导致系统卡死的情况出现）

如果不小心删除了底部面板：右键桌面 -> Add Panel -> Kubuntu Default Panel

### 1.1 声卡问题

刚安装好系统后是没有声音的。可以按照这篇博客做：[UBUNTU 声卡提示 Dummy Output 或伪输出解决办法](https://zhuanlan.zhihu.com/p/122887848)

多重启几次之后才会有效

## 2\. 常用工具的安装

### 2.1 换源

    cd /etc/apt
    sudo cp sources.list sources.list.bak
    sudo vi sources.list

[清华源 for Ubuntu 18.04](https://mirrors.tuna.tsinghua.edu.cn/help/ubuntu/)

    # 默认注释了源码镜像以提高 apt update 速度，如有需要可自行取消注释
    deb https://mirrors.tuna.tsinghua.edu.cn/ubuntu/ bionic main restricted universe multiverse
    # deb-src https://mirrors.tuna.tsinghua.edu.cn/ubuntu/ bionic main restricted universe multiverse
    deb https://mirrors.tuna.tsinghua.edu.cn/ubuntu/ bionic-updates main restricted universe multiverse
    # deb-src https://mirrors.tuna.tsinghua.edu.cn/ubuntu/ bionic-updates main restricted universe multiverse
    deb https://mirrors.tuna.tsinghua.edu.cn/ubuntu/ bionic-backports main restricted universe multiverse
    # deb-src https://mirrors.tuna.tsinghua.edu.cn/ubuntu/ bionic-backports main restricted universe multiverse
    ​
    # 以下安全更新软件源包含了官方源与镜像站配置，如有需要可自行修改注释切换
    deb http://security.ubuntu.com/ubuntu/ bionic-security main restricted universe multiverse
    # deb-src http://security.ubuntu.com/ubuntu/ bionic-security main restricted universe multiverse
    ​
    # 预发布软件源，不建议启用
    # deb https://mirrors.tuna.tsinghua.edu.cn/ubuntu/ bionic-proposed main restricted universe multiverse
    # # deb-src https://mirrors.tuna.tsinghua.edu.cn/ubuntu/ bionic-proposed main restricted universe multiverse

然后输入

    sudo apt update
    sudo apt upgrade

### 2.2 中文输入法

在系统设置内进入区域设置，选择语言，将“简体中文”移至 Preferred Language，重启后系统语言变为中文

接着参考 [kubuntu18.04 安装搜狗输入法](https://blog.csdn.net/Graceying/article/details/118117245)

### 2.3 科学上网工具

参考这两篇博客：

[Ubuntu 使用 Clash For Linux 客户端教程](https://opclash.com/article/302.html)

如果 MMDB 无法下载，可以从 Clash for Windows 里面拿，然后拷贝到 ~/.config/clash 里面

[Linux 系统使用 ShadowSocksR 客户端教程](https://opclash.com/article/139.html)

### 2.4 基础工具

包括美化部分，我为我自己的配置建立了 git 仓库：

[https://github.com/WhaleFall-UESTC/Config](https://github.com/WhaleFall-UESTC/Config)

    sudo apt-get install build-essential
    sudo apt-get install man
    sudo apt-get install gcc-doc
    sudo apt-get install gdb
    sudo apt-get install git
    sudo apt-get insatll vim
    sudo apt-get insatll tmux
    sudo apt-get insatll ccache
    sudo apt-get insatll make
    sudo apt-get insatll curl
    sudo apt-get insatll neofetch
    sudo snap install code --classic

    git config --global user.name "xxxxxxxx"
    git config --global user.email "xxxxxxxxx@xx.xxx"
    git config --global core.editor vim
    git config --global color.ui true

[这里](https://missing.csail.mit.edu/2020/files/vimrc)是 [MIT Missing Semester](https://missing.csail.mit.edu/2020/editors/) 里面提供的 .vimrc

tmux.conf 可以参考 [MAKE TMUX PRETTY AND USABLE - A GUIDE TO CUSTOM­IZING YOUR TMUX.CONF](https://hamvocke.com/blog/a-guide-to-customizing-your-tmux-conf/)

fd 下载 [https://github.com/sharkdp/fd/releases](https://github.com/sharkdp/fd/releases) 里面对应版本即可

## 3\. 简单的美化

系统设置 -> 工作空间主题 -> Get New Look，然后按照评分排序，选一个喜欢的下载

终端美化参考这两篇博客：

[Ubuntu 美化与终端配置](https://blog.imfing.com/2020/06/ubuntu-18-04-theme-terminal-setup/)

[ubuntu 终端美化之 zsh/oh-my-zsh](https://blog.csdn.net/ruipeng_liu/article/details/129701000)

    # 安装 zsh
    sudo apt install zsh
    # 确认 zsh 成功安装
    which zsh
    # 设置为默认 Shell
    chsh -s /usr/bin/zsh

    # 克隆项目到“~/”位置
    git clone https://github.com/robbyrussell/oh-my-zsh.git ~/.oh-my-zsh
    # 将配置文件复制到指定位置
    cp ~/.oh-my-zsh/templates/zshrc.zsh-template ~/.zshrc

    # 下载主题 Powerlevel10k
    git clone --depth=1 https://github.com/romkatv/powerlevel10k.git ${ZSH_CUSTOM:-~/.oh-my-zsh/custom}/themes/powerlevel10k
    # 下载插件
    git clone https://github.com/zsh-users/zsh-autosuggestions ${ZSH_CUSTOM:-~/.oh-my-zsh/custom}/plugins/zsh-autosuggestions
    git clone https://github.com/zsh-users/zsh-syntax-highlighting.git ${ZSH_CUSTOM:-~/.oh-my-zsh/custom}/plugins/zsh-syntax-highlighting

接着在 ~/.zshrc 中设置 ZSH_THEME="powerlevel10k/powerlevel10k"，plugins=(git zsh-autosuggestions zsh-syntax-highlighting)，重启终端后即可查看到效果。

还需要在 Konsole 内部将默认的 Shell 从 /bin/bash 改为 /usr/bin/zsh，并将透明度修改为 75%
