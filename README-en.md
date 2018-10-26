# Vim-Easydebugger

[中文](README.md) | [English](README-en.md)

![Vim](https://img.shields.io/badge/vim-awesome-brightgreen.svg) [![Gitter](https://img.shields.io/badge/gitter-join%20chat-yellowgreen.svg)](https://gitter.im/jayli/vim-easycomplete) [![Join the chat at https://gitter.im/jayli/vim-easydebugger](https://badges.gitter.im/jayli/vim-easydebugger.svg)](https://gitter.im/jayli/vim-easydebugger?utm_source=badge&utm_medium=badge&utm_campaign=pr-badge&utm_content=badge) ![](https://img.shields.io/badge/Linux-available-brightgreen.svg) ![](https://img.shields.io/badge/MacOS-available-brightgreen.svg) ![](https://img.shields.io/badge/:%20h-easycomplete-orange.svg) ![](https://img.shields.io/badge/license-MIT-blue.svg)

EasyDebugger is yet another debugger frontend plugin for Vim. It's based on VIM 8.1. EasyDebugger support multi-language, and has been tested with NodeJS and Go([Node inspect](https://nodejs.org/dist/latest-v10.x/docs/api/debugger.html)，and [Delve](https://github.com/derekparker/delve)). Some other debugger plugins are somehow complicated and not easy to config. So I give a simplified design for this plugin with only two windows, the terminal window and the source code. I did'nt use any DBGP protocol such as Xdebug. I think it not easy to accomplish minimalist experience that I want. Of course, Terminal features is powerful enough for me.

VIM-EasyDebugger has a nicer interface to be easily extended. You can add your favourite debugger toolkit.  By default EasyDebugger currently support:

- Tracking in the source code
- Debugger flow commands - step-in, set-over, set-out and continue
- Breakpoints management
- Evaluating expressions in the current context, watch expression and variable values while debugging.

![](https://raw.githubusercontent.com/jayli/jayli.github.com/master/photo/assets/vim-easydebugger.gif?t=3)

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


	nmap <S-R>   <Plug>EasyDebuggerInspect
	nmap <S-W>   <Plug>EasyDebuggerWebInspect
	" pause
	nmap <F7>    <Plug>EasyDebuggerPause
	tmap <F7>    <Plug>EasyDebuggerPause
	" stepinto
	nmap <F8>   <Plug>EasyDebuggerStepIn
	tmap <F8>   <Plug>EasyDebuggerStepIn
	" stepout
	nmap <S-F8> <Plug>EasyDebuggerStepOut
	tmap <S-F8> <Plug>EasyDebuggerStepOut
	" step by step
	nmap <F9>    <Plug>EasyDebuggerNext
	tmap <F9>    <Plug>EasyDebuggerNext
	" Continue
	nmap <F10>   <Plug>EasyDebuggerContinue
	tmap <F10>   <Plug>EasyDebuggerContinue
	" set break points
	nmap <F12>   <Plug>EasyDebuggerSetBreakPoint

keys:

快捷键说明：

- <kbd>Shift-R</kbd> ：startup debugger
- <kbd>Shift-W</kbd> ：startup Chrome DevTools debug service
- <kbd>F7</kbd> ：stop
- <kbd>Shift-F7</kbd> ：stepout
- <kbd>F8</kbd> ：stepin
- <kbd>F9</kbd> ：stepover
- <kbd>F10</kbd> ：continue
- <kbd>F12</kbd> ：set break point

## Useage

#### debug mode

Press <kbd>Shift-R</kbd> to startup debugger with `node inspect {filename}` (`dlv debug {filename}` for golang) running in terminal.

![](https://gw.alicdn.com/tfs/TB1V9P0kHPpK1RjSZFFXXa5PpXa-2084-1240.jpg)

Type `next` + <kbd>Enter</kbd> in Terminal means step over. Learn more command from [node inspect](https://nodejs.org/dist/latest-v10.x/docs/api/debugger.html) and [go delve](https://github.com/derekparker/delve/tree/master/Documentation/cli). Quit debug with twice <kbd>Ctrl-C</kbd>, or input `exit` + <kbd>Enter</kbd> in Terminal.

<kbd>F12</kbd> to set break points:

![](https://gw.alicdn.com/tfs/TB1jqjWkNTpK1RjSZFGXXcHqFXa-900-500.gif)

## ChangeLog

- v1.0：
	- 支持 Unix 和 MacOS，Windows 平台暂未支持
	- 支持语言种类：NodeJS
- v1.1：支持 Go、NodeJS 调试 


