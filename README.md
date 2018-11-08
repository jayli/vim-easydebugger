# Vim-Easydebugger

[中文](README-cn.md) | [English](README.md)

![Vim](https://img.shields.io/badge/vim-awesome-brightgreen.svg) [![Gitter](https://img.shields.io/badge/gitter-join%20chat-yellowgreen.svg)](https://gitter.im/jayli/vim-easydebugger) [![Join the chat at https://gitter.im/jayli/vim-easydebugger](https://badges.gitter.im/jayli/vim-easydebugger.svg)](https://gitter.im/jayli/vim-easydebugger?utm_source=badge&utm_medium=badge&utm_campaign=pr-badge&utm_content=badge) ![](https://img.shields.io/badge/Linux-available-brightgreen.svg) ![](https://img.shields.io/badge/MacOS-available-brightgreen.svg) ![](https://img.shields.io/badge/:%20h-easydebugger-orange.svg) ![](https://img.shields.io/badge/license-MIT-blue.svg) 

![](https://raw.githubusercontent.com/jayli/jayli.github.com/master/photo/assets/vim-easydebugger.gif?t=1)

## Introduction

[Vim-EasyDebugger](https://github.com/jayli/vim-easydebugger) is yet another debugger frontend plugin for Vim. It's based on VIM 8.1 and support multi-language. It has been tested with NodeJS and Go ([Node inspect](https://nodejs.org/dist/latest-v10.x/docs/api/debugger.html), and [Delve](https://github.com/derekparker/delve)). Some other debugger plugins are too difficult to configure and most of them are no longer maintained today. So I simplified the design for this plugin with only three windows, the terminal window, the source code and the backtraces stack. I did'nt use any DBGP protocol such as Xdebug because I think it's not easy to accomplish minimalist experience that I want. Anyway, Thanks to VIM 8.1, Terminal features is powerful enough for me and the development experience is cool.

[Vim-EasyDebugger](https://github.com/jayli/vim-easydebugger) has a nicer interface to be easily extended. You can add your favourite debugger toolkit.  By default EasyDebugger currently support:

- Tracking in the source code
- Debugger flow commands - step-in, step-over, step-out and continue...
- Breakpoints management
- Evaluating expressions in the current context, watch expression and variable values while debugging.
- Backtrace

## Installation

#### Requirements: 

- VIM 8.1 with terminal support. 
- Debugger such as [Node inspect](https://nodejs.org/dist/latest-v10.x/docs/api/debugger.html)，and [Delve](https://github.com/derekparker/delve) 

#### Installation:

With [Pathogen.vim](https://github.com/tpope/vim-pathogen), Execute the following commands:

	cd ~/.vim/bundle/
	git clone https://github.com/jayli/vim-easydebugger

With [Vundle.vim](https://github.com/VundleVim/Vundle.vim): add the following code into `.vimrc`. And run `:PluginInstall` in VIM

	Plugin 'jayli/vim-easydebugger'
	
## Configuration

Put these code in your `~/.vimrc`

	" Debugger startup
	nmap <S-R>   <Plug>EasyDebuggerInspect
	nmap <S-W>   <Plug>EasyDebuggerWebInspect
	" pause
	nmap <F7>    <Plug>EasyDebuggerPause
	tmap <F7>    <Plug>EasyDebuggerPause
	" stepinto
	nmap <F8>    <Plug>EasyDebuggerStepIn
	tmap <F8>    <Plug>EasyDebuggerStepIn
	" stepout
	nmap <S-F8>  <Plug>EasyDebuggerStepOut
	tmap <S-F8>  <Plug>EasyDebuggerStepOut
	" step by step
	nmap <F9>    <Plug>EasyDebuggerNext
	tmap <F9>    <Plug>EasyDebuggerNext
	" Continue
	nmap <F10>   <Plug>EasyDebuggerContinue
	tmap <F10>   <Plug>EasyDebuggerContinue
	" toggle line break points
	nmap <F12>   <Plug>EasyDebuggerSetBreakPoint

Key-Maps:

- <kbd>Shift-R</kbd> ：startup debugger
- <kbd>Shift-W</kbd> ：startup Chrome DevTools debug service
- <kbd>F7</kbd> ：pause
- <kbd>Shift-F7</kbd> ：stepout
- <kbd>F8</kbd> ：stepin
- <kbd>F9</kbd> ：stepover
- <kbd>F10</kbd> ：continue
- <kbd>F12</kbd> ：toggle line breakpoint

Commands：

- `InspectInit`: startup debugger
- `WebInspectInit`: startup Chrome DevTools debug service
- `InspectCont`: continue
- `InspectNext`: stepover
- `InspectStep`: stepin
- `InspectOut`: stepout
- `InspectPause`: pause

## Useage

### debug mode

Press <kbd>Shift-R</kbd> to startup debugger with `node inspect {filename}` (`dlv debug {filename}` for golang) running in terminal.

<img src="https://gw.alicdn.com/tfs/TB1Lq2umRLoK1RjSZFuXXXn0XXa-2022-1232.jpg" width=680>

Type `next` + <kbd>Enter</kbd> in Terminal means step over. Get more useage here: [node inspect document](https://nodejs.org/dist/latest-v10.x/docs/api/debugger.html) and [go delve document](https://github.com/derekparker/delve/tree/master/Documentation/cli). Quit debug with twice <kbd>Ctrl-C</kbd>, or input `exit` + <kbd>Enter</kbd> in Terminal.

Press <kbd>F12</kbd> to toggle break points:

![](https://raw.githubusercontent.com/jayli/jayli.github.com/master/photo/assets/vim-easydebugger-breakpoint.gif)

How to inspect local variables? 

- NodeJS: Type `repl` in terminal. Go go the REPL mode and then input variable name . Such as below.
- Golang: Type `locals -v {variable}`.

<img src="https://gw.alicdn.com/tfs/TB19_bymHrpK1RjSZTEXXcWAVXa-554-364.png" width=300>

### Chrome DevTools Debug for NodeJS

You can use chrome devtool for nodejs debug. Press <kbd>Shift-W</kbd> . Then connect it to chrome devtool [like this](https://gw.alicdn.com/tfs/TB1ci.QegHqK1RjSZJnXXbNLpXa-1414-797.png).

### TODO

Only three window is really not enough for user to inspect local vars value and function backtraces.... The following feature will be added soon:

- QuickFix Window：for backtrace. Done!
- File List Window：for a entire project with a lot of source files, I want a convenient changing buffer operation.
- Errlog：Errlog is necessary. `:echom` is good, but there is no more space available to show multiline message. Besides, I don't want to type `:message` everytime.
- GUI support: Easydebugger is now tested in cterm on Linux and MacOS. Gvim support is not ready.

## Licence

This plugin is released under the [MIT License](https://github.com/jayli/vim-easydebugger/blob/master/LICENSE).

Author: [Jayli](http://jayli.github.io/)


