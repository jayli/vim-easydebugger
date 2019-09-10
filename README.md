# Vim-Easydebugger

[中文](README.md) | [English](README-en.md)

![Vim](https://img.shields.io/badge/vim-awesome-brightgreen.svg) [![Gitter](https://img.shields.io/badge/gitter-join%20chat-yellowgreen.svg)](https://gitter.im/jayli/vim-easydebugger) [![Join the chat at https://gitter.im/jayli/vim-easydebugger](https://badges.gitter.im/jayli/vim-easydebugger.svg)](https://gitter.im/jayli/vim-easydebugger?utm_source=badge&utm_medium=badge&utm_campaign=pr-badge&utm_content=badge) ![](https://img.shields.io/badge/Linux-available-brightgreen.svg) ![](https://img.shields.io/badge/MacOS-available-brightgreen.svg) ![](https://img.shields.io/badge/:%20h-easycomplete-orange.svg) ![](https://img.shields.io/badge/license-MIT-blue.svg) 

VIM 的调试器插件（[演示](https://gw.alicdn.com/tfs/TB1cS7ofED1gK0jSZFGXXbd3FXa-1137-627.gif)，以 Python 语言为例） @author：[Jayli](http://jayli.github.io/)

![](https://gw.alicdn.com/tfs/TB1cS7ofED1gK0jSZFGXXbd3FXa-1137-627.gif)

### 一个精简的 VIM 调试器

VIM 从 8.1 版本开始支持“终端”特性（Terminal），并内置了基于`c`语言的 GDB 调试器，强大的 Terminal 特性让 Debugger 插件开发难度大大降低，不用依赖其他代理嫁接在 Debug 服务 （GDB Server） 和调试器（Inspector）之间，从而避免重写 Debugger 协议（[Debugger Protocol](https://chromedevtools.github.io/debugger-protocol-viewer/v8/)），同时基于 Terminal 的原生命令行支持，也大大简化了 VIM 视窗的管理。Vim-Easydebugger 就是基于 Terminal 特性实现的调试器，只依赖 VimL。需要支持的语言只须支持对应的运行环境即可：比如 JS 运行环境 [node](https://nodejs.org)、Go 调试器 [Delve](https://github.com/derekparker/delve)、Python 调试工具 [PDB](https://docs.python.org/3/library/pdb.html)。

开源社区已有的 VIM 调试器现状：

- [Vdebug](https://github.com/vim-vdebug/vdebug)：多语言支持，无需要求最新的 VIM 8.1。Vdebug 运行在 Python3 上，用户通常需要重新编译安装 VIM 并开启 Python3 支持；此外 Vdebug 更新过于缓慢，PHP 和 Python 支持很好，包括 Node 在内的多个语言的调试是不可用的。
- [Vim-vebugger](https://github.com/idanarye/vim-vebugger)：[作者](https://github.com/idanarye)比较勤快，代码更新率很高。但作为一个全新的调试器插件，Bug 实在太多，多平台、多语言、多终端的兼容基本没做，不支持 MacOS，我的 Pull Request 也因为作者缺少环境迟迟不能 Merge。此外，Vim-Debugger 的实现过于复杂，外部依赖太多，这也是它的健壮性不够的原因。终放弃。
- [Node-Vim-Debugger](https://github.com/sidorares/node-vim-debugger)：一个 NodeJS 调试器，基于 Debugger Protocol 实现，启动过程极为复杂，需要多道命令来辅助启动，中间的代理是基于 Node 实现，这个项目太长时间不更新，已经不支持最新的 Node Inspect 了，目前处于无人维护状态。
- [Vim-Godebug](https://github.com/jodosha/vim-godebug)：Go 语言的调试器，基于 [Neovim](https://github.com/jodosha/vim-godebug) 和 [Vim-go](https://github.com/jodosha/vim-godebug)，项目更新缓慢，环境依赖较为复杂，反正我是没搞定。
- [Fisa-Vim-Config](http://fisadev.github.io/fisa-vim-config/)：Github 上关注度最高的一个 VIM 配置，包含了 Python 的 Debugger，不支持 NodeJS，当前项目已经不维护了。

这些调试器都是基于 VIM 8 以下的版本开发，且普遍更新缓慢，缺少 VIM 8.x 的新特性支持，特别是 GDB 方面的更新不如 VIM 迅速。缺少向前兼容和充足的测试，我用的始终不顺手，直到 VIM 8.1 的发布...

### Vim-EasyDebugger 特性

Vim-EasyDebugger 即是基于 Terminal 实现的一个精简的调试器，目前支持 NodeJS、Python 和 Go 的断点调试，配置简单，目前支持的功能有：

1. 断点逐行跟踪
2. 变量监听
3. 支持 VIM 调试和 WebServer 连接外部调试器（外部调试连接只支持 NodeJS）两种方法

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

在 `~/.vimrc` 中添加快捷键配置：

	" Vim-EasyDebugger 快捷键配置
	" 开启 NodeJS 调试
	nmap <S-R>	<Plug>EasyDebuggerInspect
	nmap <S-W>	<Plug>EasyDebuggerWebInspect
	" 暂停程序
	nmap <F6>	<Plug>EasyDebuggerPause
	tmap <F6>	<Plug>EasyDebuggerPause
	" 跳出函数
	nmap <F7>	<Plug>EasyDebuggerStepOut
	tmap <F7>	<Plug>EasyDebuggerStepOut
	" 进入函数
	nmap <F8>   <Plug>EasyDebuggerStepIn
	tmap <F8>   <Plug>EasyDebuggerStepIn
	" 单步执行
	nmap <F9>	<Plug>EasyDebuggerNext
	tmap <F9>	<Plug>EasyDebuggerNext
	" Continue
	nmap <F10>	<Plug>EasyDebuggerContinue
	tmap <F10>	<Plug>EasyDebuggerContinue
	" 设置断点
	nmap <F12>	<Plug>EasyDebuggerSetBreakPoint

快捷键说明：

- <kbd>Shift-R</kbd> ：启动 VIM 调试器
- <kbd>Shift-W</kbd> ：启动 Chrome DevTools 调试服务（仅支持NodeJS）
- <kbd>F6</kbd> ：暂停执行，pause
- <kbd>F7</kbd> ：跳出函数，Python 中为`up`命令
- <kbd>F8</kbd> ：单步进入，stepin
- <kbd>F9</kbd> ：单步执行，next
- <kbd>F10</kbd> ：继续执行，continue
- <kbd>F12</kbd> ：给当前行设置/取消断点，break

命令列表：

- `InspectInit`：启动 VIM 调试器
- `WebInspectInit`：启动 Chrome DevTools 调试服务
- `InspectCont`：继续执行
- `InspectNext`：单步执行
- `InspectStep`：单步进入
- `InspectOut`：跳出函数
- `InspectPause`：暂停执行

### 使用

#### - VIM 调试模式

在 Normal 模式下按下 <kbd>Shift-R</kbd> 进入 VIM 调试模式，自动打开 Debugger 命令窗口。

	// 视口说明
	╔═══════════════════════════════╤═══════════════════════════════╗
	║                               │                               ║
	║                               │                               ║
	║                               │                               ║
	║          Source Code          │         Debug window          ║
	║                               │                               ║
	║                               │                               ║
	║                               │                               ║
	╟───────────────────────────────┼───────────────────────────────╢
	║                               │                               ║
	║        Callback Stacks        │          Local vars           ║
	║                               │                               ║
	╚═══════════════════════════════╧═══════════════════════════════╝

Debug Window 为 Terminal，可输入命令。命令参考语言对应的调试器。

#### - Python

![](https://gw.alicdn.com/tfs/TB1T8kofvb2gK0jSZK9XXaEgFXa-2272-1262.png)

Python 调试支持调用堆栈查看和本地变量监视。退出调试需要光标停留在 Debug Window 中执行`exit`。常用的快捷键有`F9`单步执行，`F12`设置断点，`F10`继续执行等。[参照视频Demo](https://gw.alicdn.com/tfs/TB1cS7ofED1gK0jSZFGXXbd3FXa-1137-627.gif)

Python PDB 常用指令：`next` 下一步，`continue` 继续执行，`w` 查看当前堆栈... 

#### - JavaScript

![](https://gw.alicdn.com/tfs/TB1s0QtfrY1gK0jSZTEXXXDQVXa-2288-1250.png)

JavaScript 暂未实现本地变量监视。启动调试后，程序自动执行 `node inspect {filename}` 并停留在当前代码第一行（Go 调试器执行`dlv debug {filename}`），代码窗口对应行高亮。敲击两次 <kbd>Ctrl-C</kbd> 终止调试。如果要查看当前变量，NodeJS 需要进入“[Read-Eval-Print-Loop](https://nodejs.org/dist/latest-v10.x/docs/api/debugger.html#debugger_information)”（repl）模式，在左侧终端内输入 `repl`，输入变量名字即可查看。需要退出 Repl 模式才能继续逐行跟踪，输入 <kbd>Ctrl-C</kbd> 退出 Repl 模式。Go 则直接输命令即可，比如`vars`输出当前包内的变量，`locals - {变量名}`查看变量的值。

<img src="https://gw.alicdn.com/tfs/TB19_bymHrpK1RjSZTEXXcWAVXa-554-364.png" width=300>

> 由于 Node Inspector 会将 JS 源码包一层外壳，因此调试器中所示行数通常比源文件多出一到两行，但行号跟源码是一一对应的，基本不影响调试

#### - Go

![](https://gw.alicdn.com/tfs/TB1BWUqfrr1gK0jSZR0XXbP8XXa-1137-629.gif)

Go 语言暂未实现本地变量监视。启动调试后自动执行`dlv debug {filename}`，并自动停留在 main() 函数处，更多指令参照 Go Delve [官网文档](https://github.com/derekparker/delve/tree/master/Documentation/cli)。敲击两次 <kbd>Ctrl-C</kbd> 终止调试。也可以执行`exit`退出调试。

Go 语言堆栈查看示例：

![](https://gw.alicdn.com/tfs/TB1HKcpfpP7gK0jSZFjXXc5aXXa-1132-628.gif)

#### - NodeJS 的 Chrome DevTools 调试模式

NodeJS 提供了基于 Chrome DevTools 的调试，我也封装了进来：

![](https://gw.alicdn.com/tfs/TB1ci.QegHqK1RjSZJnXXbNLpXa-1414-797.png)

在 normal 模式下按下 <kbd>Shift-W</kbd> 开启调试，这时启动了 Debug 服务，打开 Chrome DevTool 即可开始调试。关闭调试：<kbd>Ctrl-C</kbd> ，打开 Chrome DevTool 的方法：

- 方法A：在 Chrome 地址栏输入`about:inspect`，点击`Open dedicated DevTools for Node` 
- 方法B：在 Chrome 地址栏输入`chrome://flags/#enable-devtools-experiments`，（下图）将`devtools-experiments`开启，然后每次 <kbd>Command-Alt-I</kbd> 打开开发者工具，点击 <img src="https://gw.alicdn.com/tfs/TB1k0UZehTpK1RjSZFMXXbG_VXa-24-25.png" width=24 style="vertical-align:middle"> （VIM 中开启调试时才出现）

![](https://gw.alicdn.com/tfs/TB1uX3YekzoK1RjSZFlXXai4VXa-744-95.png)

### 关于 VIM Debugger Plugin 的一些思考


VIM 8.1 所支持的 Terminal 是这个大版本最主要的特性，我个人非常喜欢，他让我很大程度抛弃了对 Python 和其他辅助工具的依赖，用纯净的 VimL 就能完成 Debugger 插件的开发，相比过去开发体验还是很赞的。目前只支持 NodeJS 和 Go，后续陆续添加更多语言支持。

但是 Terminal 仍然不尽完善，比如 Terminal 的输出是碎片式的，另外性能上也有问题，比如 quickfix 和 localist 窗口性能极差，所以在 Terminal 和 VIM 的交互上有很多天然缺陷，因此我也没有实现 Go 和 Python 的多线程，只满足单线程的调试。

### For Help！？需要帮助

→ [在这里提 ISSUE](https://github.com/jayli/vim-easydebugger/issues)

> 更多好玩的 VIM 碎碎，参照[我的 VIM 配置](https://github.com/jayli/vim)

### ChangeLog

- v1.0：
	- 支持 Unix 和 MacOS，Windows 平台暂未支持
	- 支持语言种类：NodeJS
- v1.1：支持 Go、NodeJS 调试
- v1.2：支持 Quickfix 窗口显示回调堆栈
- v1.3: Quickfix 修改为 Localist，支持 python 以及本地变量查看

