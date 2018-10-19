# Vim-Easydebugger

![Vim](https://img.shields.io/badge/vim-awesome-brightgreen.svg) [![Gitter](https://img.shields.io/badge/gitter-join%20chat-yellowgreen.svg)](https://gitter.im/jayli/vim-easycomplete) [![Join the chat at https://gitter.im/jayli/vim-easydebugger](https://badges.gitter.im/jayli/vim-easydebugger.svg)](https://gitter.im/jayli/vim-easydebugger?utm_source=badge&utm_medium=badge&utm_campaign=pr-badge&utm_content=badge) ![](https://img.shields.io/badge/Linux-available-brightgreen.svg) ![](https://img.shields.io/badge/MacOS-available-brightgreen.svg) ![](https://img.shields.io/badge/:%20h-easycomplete-orange.svg) ![](https://img.shields.io/badge/license-MIT-blue.svg)

VIM 的 NodeJS 调试器插件（[演示](https://gw.alicdn.com/tfs/TB1DQVHhwHqK1RjSZFPXXcwapXa-850-482.gif)） @author：[Jayli](http://jayli.github.io/)

![](https://raw.githubusercontent.com/jayli/jayli.github.com/master/photo/assets/vim-easydebugger.gif?t=1)

### 一个精简的 VIM 调试器

VIM 上一直缺少好用的断点跟踪调试插件，在命令行环境中 Debug 代码通常用打 Log 的方式。VIM 从 8.1 版本开始支持“终端”特性（Terminal），并内置了基于`c`语言的 GDB 调试器，强大的 Terminal 特性让 Debugger 插件开发难度大大降低，不用依赖其他代理嫁接在 Debug 服务 （GDB Server） 和调试器（Inspector）之间，从而避免重写 Debugger 协议（[Debugger Protocol](https://chromedevtools.github.io/debugger-protocol-viewer/v8/)），同时基于 Terminal 的原生命令行支持，也大大简化了 VIM 视窗的管理。Vim-Easydebugger 就是基于 Terminal 特性实现的 NodeJS 调试器，只依赖 JS 运行环境（[node](https://nodejs.org)）和 VimL，安装配置非常方便。

开源社区已有的 VIM 调试器现状：

- [Vdebug](https://github.com/vim-vdebug/vdebug)：多语言支持，无需要求最新的 VIM 8.1。Vdebug 运行在 Python3 上，用户通常需要重新编译安装 VIM 并开启 Python3 支持；此外 Vdebug 更新过于缓慢，PHP 和 Python 支持很好，包括 Node 在内的多个语言的调试是不可用的。
- [Vim-vebugger](https://github.com/idanarye/vim-vebugger)：[作者](https://github.com/idanarye)比较勤快，代码更新率很高。但作为一个全新的调试器插件，Bug 实在太多，多平台、多语言、多终端的兼容基本没做，不支持 MacOS，我的 Pull Request 也因为作者缺少环境迟迟不能 Merge。此外，Vim-Debugger 的实现过于复杂，外部依赖太多，这也是它的健壮性不够的原因。终放弃。
- [Node-Vim-Debugger](https://github.com/sidorares/node-vim-debugger)：一个 NodeJS 调试器，基于 Debugger Protocol 实现，启动过程极为复杂，需要多道命令来辅助启动，中间的代理是基于 Node 实现，这个项目太长时间不更新，已经不支持最新的 Node Inspect 了，目前处于无人维护状态。
- [Vim-Godebug](https://github.com/jodosha/vim-godebug)：Go 语言的调试器，基于 [Neovim](https://github.com/jodosha/vim-godebug) 和 [Vim-go](https://github.com/jodosha/vim-godebug)，项目更新缓慢，环境依赖较为复杂，反正我是没搞定。
- [Fisa-Vim-Config](http://fisadev.github.io/fisa-vim-config/)：Github 上关注度最高的一个 VIM 配置，包含了 Python 的 Debugger，不支持 NodeJS，当前项目已经不维护了。

这些调试器都是基于 VIM 8 以下的版本开发，且普遍更新缓慢，缺少 VIM 8.x 的新特性支持，特别是 GDB 方面的更新不如 VIM 迅速。存在大量 Hack 的实现方式，同时缺少向前兼容和充足的测试，所以鲁棒性始终是个问题，只能在特定环境中试运行。因此一直以来 VIM 的调试器插件都质量不佳，直到 VIM 8.1 的发布...

### Vim-EasyDebugger 特性

Vim-EasyDebugger 即是基于 Terminal 实现的一个精简的 NodeJS 调试器，剔除掉了复杂的配置，只基于 `node inspect` 实现基础功能，目前支持的功能有：

1. 断点逐行跟踪
2. 变量监听
3. 支持 VIM 调试和 Chrome DevTool 调试两种方法

更多调试用法请参照 [node inspect](https://nodejs.org/dist/latest-v10.x/docs/api/debugger.html)。

### 安装

Vim-EasyDebugger 依赖 VIM 8.1 及以上，如果是编译安装，需要开启 `+terminal` 选项，可以通过下面命令查看是否开启了 `+terminal` 选项：

	vim --version | grep terminal

Node 需要携带 `node inspect` 调试器（通常是 v8.x 及以上）。执行下面命令，如果输出 `Useage:...` 命令的用法，说明支持 Node Inspector：

	node inspect
	
> 注意旧版的 Node 的调试器的启动命令是 node debug，则需要升级 node 到新版。

安装该 VIM 插件，可选 Pathogen、Vundle 等很棒的插件管理器：

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

### 配置

在 `~/.vimrc` 中添加快捷键配置：

	" Vim-EasyDebugger 快捷键配置
	" 启动调试器的两个快捷键
	nmap <S-R>   <Plug>EasyDebuggerInspect
	nmap <S-W>   <Plug>EasyDebuggerWebInspect
	" 暂停程序
	nmap <F7>    <Plug>EasyDebuggerPause
	tmap <F7>    <Plug>EasyDebuggerPause
	" 进入函数
	nmap <F8>   <Plug>EasyDebuggerStepIn
	tmap <F8>   <Plug>EasyDebuggerStepIn
	" 跳出函数
	nmap <S-F8> <Plug>EasyDebuggerStepOut
	tmap <S-F8> <Plug>EasyDebuggerStepOut
	" 单步执行
	nmap <F9>    <Plug>EasyDebuggerNext
	tmap <F9>    <Plug>EasyDebuggerNext
	" Continue
	nmap <F10>   <Plug>EasyDebuggerContinue
	tmap <F10>   <Plug>EasyDebuggerContinue
	" 设置断点
	nmap <F12>   <Plug>EasyDebuggerSetBreakPoint
	
快捷键说明：

- <kbd>Shift-R</kbd> ：启动 VIM 调试器
- <kbd>Shift-W</kbd> ：启动 Chrome DevTools 调试服务
- <kbd>F7</kbd> ：进入函数
- <kbd>Shift-F7</kbd> ：跳出函数
- <kbd>F8</kbd> ：暂停执行
- <kbd>F9</kbd> ：单步执行
- <kbd>F10</kbd> ：继续执行
- <kbd>F12</kbd> ：给当前行设置断点 

### 使用

#### - VIM 调试模式

在 normal 模式下按下 <kbd>Shift-R</kbd> 会进入 VIM 调试模式，自动打开 Debugger 命令窗口，执行 `node inspect {filename}` 并停留在当前代码第一行，右侧代码窗口对应行高亮，这时可以逐行跟踪代码了。

![](https://gw.alicdn.com/tfs/TB1cvSZhmzqK1RjSZPxXXc4tVXa-2536-1396.jpg)

左侧终端窗口内等待输入调试器命令。比如输入 `next` + <kbd>Enter</kbd> 表示执行下一行代码。更多命令可参照[官网文档](https://nodejs.org/dist/latest-v10.x/docs/api/debugger.html)。同样可以使用快捷键来跟踪调试。敲击两次 <kbd>Ctrl-C</kbd> 终止调试。

如果要查看当前变量，需要进入“[Read-Eval-Print-Loop](https://nodejs.org/dist/latest-v10.x/docs/api/debugger.html#debugger_information)”（repl）模式，在左侧终端内输入 `repl`，输入变量名字即可查看。需要退出 Repl 模式才能继续逐行跟踪，输入 <kbd>Ctrl-C</kbd> 退出 Repl 模式。

<img src="https://gw.alicdn.com/tfs/TB1qfi7hmzqK1RjSZFjXXblCFXa-620-227.png" width=350>

在左侧终端内敲入`exit` + <kbd>Enter</kbd> 退出调试模式。

> 方便起见，Debugger 调试器启动总是会停留在首行。此外，由于 Node Inspector 会将 JS 源码包一层外壳，因此调试器中所示行数通常比源文件多出一到两行，但行号跟源码是一一对应的，基本不影响调试。

**断点调试**：Debuger 启动之后，在右侧源码窗口中，光标停留在需要打断点的行，按下 <kbd>F12</kbd>，打断点成功，取消断点也是 <kbd>F12</kbd>

![](https://gw.alicdn.com/tfs/TB1CgKpihnaK1RjSZFtXXbC2VXa-1944-926.jpg)

#### - Chrome DevTools 调试模式

![](https://gw.alicdn.com/tfs/TB1ci.QegHqK1RjSZJnXXbNLpXa-1414-797.png)

在 normal 模式下按下 <kbd>Shift-W</kbd> 开启调试，这时启动了 Debug 服务，打开 Chrome DevTool 即可开始调试。关闭调试：<kbd>Ctrl-C</kbd> ，打开 Chrome DevTool 的方法：

- 方法A：在 Chrome 地址栏输入`about:inspect`，点击`Open dedicated DevTools for Node` 
- 方法B：在 Chrome 地址栏输入`chrome://flags/#enable-devtools-experiments`，（下图）将`devtools-experiments`开启，然后每次 <kbd>Command-Alt-I</kbd> 打开开发者工具，点击 <img src="https://gw.alicdn.com/tfs/TB1k0UZehTpK1RjSZFMXXbG_VXa-24-25.png" width=24 style="vertical-align:middle"> （VIM 中开启调试时才出现）

![](https://gw.alicdn.com/tfs/TB1uX3YekzoK1RjSZFlXXai4VXa-744-95.png)

### 关于 VIM Debugger Plugin 的一些思考

VIM 的代码逐行调试能力一直被诟病，除了 VIM 8.1 原生支持的 GDB 之外还没有广泛流行的 Debugger 插件，包括对语言的支持也很吃力。主要原因是 VIM 在 8.0 以前，在视窗管理方面不够强大，尽管 Buffer 和 WinCmd 特性能够很好的接受定制，但涉及到视窗之间的命令传递，以及 Insert 和 Normal 模式之间的频繁切换的场景，缺少鼠标参与的情况下，需要极多的交互命令，命令的记忆成本较高，所以需要适当的简化 VIM Debugger 插件的设计，通常一个完整的调试器需要至少四个视窗，源码、Log、监视器、文件列表。所以简化交互的诉求，与基础功能完备之间往往难以两全。这也导致 VIM Debugger 开发难度大。我在实现 Vim-EasyDebugger 时干脆简化成两个视窗，以 node inspect 自有能力为主，外加一个代码跟踪视窗，跟踪 JavaScript 代码已经足够用了，较为复杂的代码跟踪则使用 VIM + Chrome DevTools 的方式，弥补 VIM 调试能力上的不足。

另外，VIM 8.1 所支持的 Terminal 是这个大版本最主要的特性，我个人非常喜欢，他让我很大程度抛弃了对 Python 和其他辅助工具的依赖，用纯净的 VimL 就能完成 Debugger 插件的开发，开发体验还是很赞的。后续会陆续补全其他语言的支持。

### For Help！？需要帮助

→ [在这里提 ISSUE](https://github.com/jayli/vim-easydebugger/issues)

> 更多好玩的 VIM 碎碎，参照[我的 VIM 配置](https://github.com/jayli/vim)

### ChangeLog

- v1.0：
	- 支持 Unix 和 MacOS，Windows 平台暂未支持
	- 支持语言种类：NodeJS

