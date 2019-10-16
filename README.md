<img src="https://gw.alicdn.com/tfs/TB1ro1dghD1gK0jSZFyXXciOVXa-1401-1280.png" width=400 />

[中文](README.md) | [English](README-en.md)

![Vim](https://img.shields.io/badge/vim-awesome-brightgreen.svg) [![Gitter](https://img.shields.io/badge/gitter-join%20chat-yellowgreen.svg)](https://gitter.im/jayli/vim-easydebugger) [![Join the chat at https://gitter.im/jayli/vim-easydebugger](https://badges.gitter.im/jayli/vim-easydebugger.svg)](https://gitter.im/jayli/vim-easydebugger?utm_source=badge&utm_medium=badge&utm_campaign=pr-badge&utm_content=badge) ![](https://img.shields.io/badge/Linux-available-brightgreen.svg) ![](https://img.shields.io/badge/MacOS-available-brightgreen.svg) ![](https://img.shields.io/badge/:%20h-easydebugger-orange.svg) ![](https://img.shields.io/badge/license-MIT-blue.svg) 

VIM 的调试器插件（[演示](https://raw.githubusercontent.com/jayli/jayli.github.com/master/photo/assets/python_demo.gif)，以 Python 语言为例） @author：[Jayli](http://jayli.github.io/)

![](https://raw.githubusercontent.com/jayli/jayli.github.com/master/photo/assets/python_demo.gif?t=3)

### 又一个 VIM 调试器？

基于 VimL 和 Terminal 实现的一个极简的 Debugger，支持 VIM 8.1 及以上版本。支持三个语言（js、python、go），需要 JS 运行环境 [node](https://nodejs.org)、Go 调试器 [Delve](https://github.com/derekparker/delve)、Python 调试工具 [PDB](https://docs.python.org/3/library/pdb.html)。

参考这些调试器的实现：

<table>
<tr>
<td>名称</td><td>语言支持</td><td>VIM版本</td><td>更新速度</td><td>纯VimL实现</td><td>配置难度</td>
</tr>
<tr>
<td>vdebug</td><td>多语言<br>不支持 Node、Go</td><td>8.1</td><td>慢</td><td>依赖Python3</td><td>中等</td>
</tr>
<tr>
<td>vim-vebugger</td><td>多语言支持</td><td>VIM 8.1<br>不支持MacOS</td><td>快</td><td>依赖Python3</td><td>中等</td>
</tr>
<tr>
<td>Node-Vim-Debugger</td><td>仅支持Node</td><td>不支持<br>Node Inspect</td><td>废弃</td><td>是</td><td>简单</td>
</tr>
<tr>
<td>Vim-Godebug</td><td>仅支持Go</td><td>8.1</td><td>中等</td><td>依赖Python3</td><td>复杂</td>
</tr>
<tr>
<td>Fisa-Vim-Config</td><td>支持Python<br>不支持Node</td><td>8.1</td><td>已经废弃</td><td>基于Python</td><td>简单</td>
</tr>
</table>

我的需求：支持Go、Js、Python，引擎部分只基于 VimL，容易扩展新的语言，需要有命令输入窗。

**实现原理**

![](https://gw.alicdn.com/tfs/TB1pCvLjhD1gK0jSZFKXXcJrVXa-1844-1014.png)

### 安装

### 环境依赖

> 在 VIM 8.1.4、Node v10.15.3、Go go1.12.9 darwin/amd64、Python 3.7.0 下测试通过

**Vim 版本**：Vim-EasyDebugger 依赖 VIM 8.1 及以上，如果是编译安装，需要开启 `+terminal` 选项，可以通过下面命令查看是否开启了 `+terminal` 选项：

    vim --version | grep terminal

**NodeJS 调试器**：[Node Inspect](https://nodejs.org/dist/latest-v10.x/docs/api/debugger.html)

NodeJS 调试基于 `node inspect`（通常 v8.x 及以上的 node 都自带了）。执行下面命令，如果输出 `Useage:...` 命令的用法，说明支持 Node Inspector：

    node inspect

> 注意旧版的 Node 的调试器的启动命令是 node debug，则需要升级 node 到新版，且要确保 Node 在 v10.x 及以上版本

**Go 调试器**：[Delve](https://github.com/derekparker/delve)

Go 语言的调试基于 Delve，[参考官方文档安装](https://github.com/derekparker/delve)。

**Python 调试器**：[PDB](https://docs.python.org/3/library/pdb.html)

Python 语言基于 Python(3) 自带的 PDB，命令行启动`python3 -m -pdb file.py`，可[参考官方文档](https://docs.python.org/3/library/pdb.html)。

### 安装

可选 Pathogen、Vundle 等很棒的插件管理器：

> Vim-EasyDebugger 兼容 Linux 和 MacOS，暂不支持 CygWin

#### - 基于 [Pathogen.vim](https://github.com/tpope/vim-pathogen) 安装（VIM7 & 8）

进入到 VIM 安装目录中，在 `bundle` 里安装

    cd ~/.vim/bundle/
    git clone https://github.com/jayli/vim-easydebugger

#### - 基于 [Vundle.vim](https://github.com/VundleVim/Vundle.vim) 安装（VIM7 & 8）

在`.vimrc`中添加下面代码，进入`vim`后执行`:PluginInstall`

    " EasyDebugger 插件
    Plugin 'jayli/vim-easydebugger'

#### - 也可以直接基于 VIM8 安装

    git clone https://github.com/jayli/vim-easydebugger.git \
        ~/.vim/pack/dist/start/vim-easydebugger
Done!

### 快捷键配置

我常用的快捷键：

    " Vim-EasyDebugger 快捷键配置
    " 启动 NodeJS/Python/Go 调试
    nmap <S-R>  <Plug>EasyDebuggerInspect
    " 启动 NodeJS 的 Web 调试模式
    nmap <S-W>  <Plug>EasyDebuggerWebInspect
    " 关闭调试
    nmap <S-E>  <Plug>EasyDebuggerExit
    " 暂停程序
    nmap <F6>   <Plug>EasyDebuggerPause
    tmap <F6>   <Plug>EasyDebuggerPause
    " 跳出函数
    nmap <F7>   <Plug>EasyDebuggerStepOut
    tmap <F7>   <Plug>EasyDebuggerStepOut
    " 进入函数
    nmap <F8>   <Plug>EasyDebuggerStepIn
    tmap <F8>   <Plug>EasyDebuggerStepIn
    " 单步执行
    nmap <F9>   <Plug>EasyDebuggerNext
    tmap <F9>   <Plug>EasyDebuggerNext
    " Continue
    nmap <F10>  <Plug>EasyDebuggerContinue
    tmap <F10>  <Plug>EasyDebuggerContinue
    " 设置断点
    nmap <F12>  <Plug>EasyDebuggerSetBreakPoint

定义打开本地变量窗口`<Plug>EasyDebuggerLocalvarWindow`，定义打开调用堆栈窗口`<Plug>EasyDebuggerStackWindow`

快捷键说明：

- <kbd>Shift-R</kbd> ：启动 VIM 调试器
- <kbd>Shift-W</kbd> ：启动 Chrome DevTools 调试服务（仅支持NodeJS）
- <kbd>Shift-E</kbd> ：关闭 VIM 调试器
- <kbd>F6</kbd> ：暂停执行，pause
- <kbd>F7</kbd> ：跳出函数，Python 中为`up`命令
- <kbd>F8</kbd> ：单步进入，stepin
- <kbd>F9</kbd> ：单步执行，next
- <kbd>F10</kbd> ：继续执行，continue
- <kbd>F12</kbd> ：给当前行设置/取消断点，break

命令列表：

- `InspectInit`、`Debugger`：启动 VIM 调试器
- `WebInspectInit`：启动 Chrome DevTools 调试服务
- `InspectCont`：继续执行
- `InspectNext`：单步执行
- `InspectStep`：单步进入
- `InspectOut`：跳出函数
- `InspectPause`：暂停执行
- `InspectExit`、`ExitDebugger`：退出调试
- `LocalvarWindow`：打开本地变量窗口
- `StackWindow`：打开调用堆栈窗口

### 使用

#### - VIM 调试模式

在 Normal 模式下按下 <kbd>Shift-R</kbd> 进入 VIM 调试模式，自动打开 Debugger 命令窗口。默认情况下，调试窗口中启动诸如 `python -m pdb {filename}` 的命令，其中`{filename}`为当前所在文件，如果调试运行文件的入口不是当前文件，需要在当前代码前部注释中添加`debugger_entry = {filepath}`，以 Python 为例：

    # debugger_entry = ../index.py

*退出调试模式*：
- 当光标在 Terminal 时，可以使用 `Ctrl-D` 或者 `exit + 回车` 退出。
- 在源码窗口`:exit`退出调试。或者 `Shift-E` 退出，退出vim命令首先会退出debug

Terminal 窗口如何滚动：进入 Terminal-Normal 模式即可，光标在 Terminal 时通过 `Ctrl-w N`（Ctrl-w，Shift-N）进入，`i` 或者 `a` 再次进入 Terminal 交互模式。

界面说明:

    ╔═══════════════════════════════╤═══════════════════════════════╗
    ║                               │                               ║
    ║                               │                               ║
    ║                               │                               ║
    ║        Source Window          │         Debug Window          ║
    ║    g:debugger.original_winid  │     g:debugger.term_winid     ║
    ║                               │                               ║
    ║                               │                               ║
    ║                               │                               ║
    ╟───────────────────────────────┼───────────────────────────────╢
    ║                               │                               ║
    ║          Call Stack           │        Local Variables        ║
    ║    g:debugger.stacks_winid    │   g:debugger.localvars_winid  ║
    ║                               │                               ║
    ╚═══════════════════════════════╧═══════════════════════════════╝

Debug Window 为 Terminal，可输入命令。命令参考语言对应的调试器。

#### - Python

![](https://gw.alicdn.com/tfs/TB1FyLLfVY7gK0jSZKzXXaikpXa-1990-1152.png)

Python 调试支持调用堆栈查看和本地变量监视。常用的快捷键有`F9`单步执行，`F12`设置断点，`F10`继续执行，`Shift-E`退出调试等。

Python PDB 常用指令：`next` 下一步，`continue` 继续执行，`w` 查看当前堆栈，`exit`退出调试...

#### - JavaScript

![](https://gw.alicdn.com/tfs/TB1BlHNf.T1gK0jSZFrXXcNCXXa-1994-1156.png)

JavaScript 暂未实现本地变量监视。启动调试后，程序自动执行 `node inspect {filename}` 并停留在当前代码第一行（Go 调试器执行`dlv debug {filename}`），代码窗口对应行高亮。敲击两次 <kbd>Ctrl-C</kbd> 终止调试。如果要查看当前变量，NodeJS 需要进入“[Read-Eval-Print-Loop](https://nodejs.org/dist/latest-v10.x/docs/api/debugger.html#debugger_information)”（repl）模式，在左侧终端内输入 `repl`，输入变量名字即可查看。需要退出 Repl 模式才能继续逐行跟踪，输入 <kbd>Ctrl-C</kbd> 退出 Repl 模式。Go 则直接输命令即可，比如`vars`输出当前包内的变量，`locals - {变量名}`查看变量的值。

<img src="https://gw.alicdn.com/tfs/TB19_bymHrpK1RjSZTEXXcWAVXa-554-364.png" width=300>

> 由于 Node Inspector 会将 JS 源码包一层外壳，因此调试器中所示行数通常比源文件多出一到两行，但行号跟源码是一一对应的，基本不影响调试

#### - Go

Go 语言暂未实现本地变量监视。启动调试后自动执行`dlv debug {filename}`，并自动停留在 main() 函数处，更多指令参照 Go Delve [官网文档](https://github.com/derekparker/delve/tree/master/Documentation/cli)。敲击两次 <kbd>Ctrl-C</kbd> 终止调试。也可以执行`exit`退出调试。

#### - NodeJS 的 Chrome DevTools 调试模式

NodeJS 提供了基于 Chrome DevTools 的调试，我也封装了进来：

![](https://gw.alicdn.com/tfs/TB1ci.QegHqK1RjSZJnXXbNLpXa-1414-797.png)

在 normal 模式下按下 <kbd>Shift-W</kbd> 开启调试，这时启动了 Debug 服务，打开 Chrome DevTool 即可开始调试。关闭调试：<kbd>Ctrl-C</kbd> ，打开 Chrome DevTool 的方法：

- 方法A：在 Chrome 地址栏输入`about:inspect`，点击`Open dedicated DevTools for Node` 
- 方法B：在 Chrome 地址栏输入`chrome://flags/#enable-devtools-experiments`，（下图）将`devtools-experiments`开启，然后每次 <kbd>Command-Alt-I</kbd> 打开开发者工具，点击 <img src="https://gw.alicdn.com/tfs/TB1k0UZehTpK1RjSZFMXXbG_VXa-24-25.png" width=24 style="vertical-align:middle"> （VIM 中开启调试时才出现）

![](https://gw.alicdn.com/tfs/TB1uX3YekzoK1RjSZFlXXai4VXa-744-95.png)

### 后记

VIM 8.1 支持 Terminal 是这个大版本最主要的特性，我个人非常喜欢，他让我很大程度抛弃了对 Python 和其他辅助工具的依赖，用纯净的 VimL 就能完成 Debugger 插件的开发，相比过去开发体验还是很赞的。目前只支持 NodeJS 和 Go，后续陆续添加更多语言支持。

但是 Terminal 仍然不尽完善，比如 Terminal 的输出是碎片式的，另外性能上也有问题，比如 quickfix 和 localist 窗口性能极差，最后我换成了普通的 buffer 来管理辅助窗口，另外我也没有实现 Go 和 Python 的多线程，只满足单线程的调试。

### For Help！？需要帮助

→ [在这里提 ISSUE](https://github.com/jayli/vim-easydebugger/issues)

> 更多好玩的 VIM 碎碎，参照[我的 VIM 配置](https://github.com/jayli/vim)

### ChangeLog

- v1.0：
    - 支持 Unix 和 MacOS，Windows 平台暂未支持
    - 支持语言种类：NodeJS
- v1.1：支持 Go、NodeJS 调试
- v1.2：支持 Quickfix 窗口显示回调堆栈
- v1.3: 放弃 Quickfix 和 Localist，支持 python 以及本地变量查看，已经大量 bugfix
