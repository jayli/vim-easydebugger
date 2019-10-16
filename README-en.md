<img src="https://gw.alicdn.com/tfs/TB1ro1dghD1gK0jSZFyXXciOVXa-1401-1280.png" width=400 />

[中文](README.md) | [English](README-en.md)

![Vim](https://img.shields.io/badge/vim-awesome-brightgreen.svg) [![Gitter](https://img.shields.io/badge/gitter-join%20chat-yellowgreen.svg)](https://gitter.im/jayli/vim-easydebugger) [![Join the chat at https://gitter.im/jayli/vim-easydebugger](https://badges.gitter.im/jayli/vim-easydebugger.svg)](https://gitter.im/jayli/vim-easydebugger?utm_source=badge&utm_medium=badge&utm_campaign=pr-badge&utm_content=badge) ![](https://img.shields.io/badge/Linux-available-brightgreen.svg) ![](https://img.shields.io/badge/MacOS-available-brightgreen.svg) ![](https://img.shields.io/badge/:%20h-easydebugger-orange.svg) ![](https://img.shields.io/badge/license-MIT-blue.svg) 

![](https://raw.githubusercontent.com/jayli/jayli.github.com/master/photo/assets/python_demo.gif?t=3)

## Introduction

[Vim-EasyDebugger](https://github.com/jayli/vim-easydebugger) is yet another debugger frontend plugin for Vim. It's based on VIM 8.1 and support multi-language. It has been tested with NodeJS, Python, Go ([Node inspect](https://nodejs.org/dist/latest-v10.x/docs/api/debugger.html), and [Delve](https://github.com/derekparker/delve)). Some other debugger plugins are too difficult to configure and most of them are no longer maintained today. So I redesign it. I did'nt want to use any DBGP protocol such as Xdebug because I think it's not easy to accomplish minimalist experience that I want. Anyway, Thanks to VIM 8.1, Terminal features is powerful enough for me and the development experience is cool.

[Vim-EasyDebugger](https://github.com/jayli/vim-easydebugger) has a nicer interface to be easily extended. You can add your favourite debugger toolkit.  By default EasyDebugger currently support:

- Tracking in the source code
- Debugger flow commands - step-in, step-over, step-out and continue...
- Breakpoints management
- Evaluating expressions in the current context, watch expression and variable values while debugging.
- Backtrace and localvars

## Installation

#### Requirements:

- VIM 8.1 with terminal support.
- Debugger such as [Node inspect](https://nodejs.org/dist/latest-v10.x/docs/api/debugger.html), [Delve](https://github.com/derekparker/delve), and [PDB](https://docs.python.org/3/library/pdb.html)

#### Installation:

With [Pathogen.vim](https://github.com/tpope/vim-pathogen), Execute the following commands:

	cd ~/.vim/bundle/
	git clone https://github.com/jayli/vim-easydebugger

With [Vundle.vim](https://github.com/VundleVim/Vundle.vim): add the following code into `.vimrc`. And run `:PluginInstall` in VIM

	Plugin 'jayli/vim-easydebugger'

## Configuration

Commands：

- `InspectInit`/`Debugger`: startup debugger
- `WebInspectInit`: startup Chrome DevTools debug service
- `InspectCont`: continue
- `InspectNext`: stepover
- `InspectStep`: stepin
- `InspectOut`: stepout
- `InspectPause`: pause
- `InspectExit`/`ExitDebugger`: exit 
- `LocalvarWindow`：open localvar window
- `StackWindow`：open stack window
- `BreakPointSetting`: set or delete break point

My key maps in `~/.vimrc`

	" Debugger startup
	nmap <S-R>	<Plug>EasyDebuggerInspect
	nmap <S-W>	<Plug>EasyDebuggerWebInspect
	nmap <S-E>	<Plug>EasyDebuggerExit
	" pause
	nmap <F6>	<Plug>EasyDebuggerPause
	tmap <F6>	<Plug>EasyDebuggerPause
	" stepout
	nmap <F7>	<Plug>EasyDebuggerStepOut
	tmap <F7>	<Plug>EasyDebuggerStepOut
	" stepinto
	nmap <F8>   <Plug>EasyDebuggerStepIn
	tmap <F8>   <Plug>EasyDebuggerStepIn
	" next
	nmap <F9>	<Plug>EasyDebuggerNext
	tmap <F9>	<Plug>EasyDebuggerNext
	" Continue
	nmap <F10>	<Plug>EasyDebuggerContinue
	tmap <F10>	<Plug>EasyDebuggerContinue
	" break or delete break
	nmap <F12>	<Plug>EasyDebuggerSetBreakPoint

define openning localvar window: `<Plug>EasyDebuggerLocalvarWindow`，define openning call stack window: `<Plug>EasyDebuggerStackWindow`

Key-Maps:

- <kbd>Shift-R</kbd> ：startup debugger
- <kbd>Shift-E</kbd> ：quit debugger
- <kbd>Shift-W</kbd> ：startup Chrome DevTools debug service
- <kbd>F6</kbd> ：pause
- <kbd>F7</kbd> ：stepout
- <kbd>F8</kbd> ：stepin
- <kbd>F9</kbd> ：stepover
- <kbd>F10</kbd> ：continue
- <kbd>F12</kbd> ：toggle line breakpoint


## Useage

### How to..

<img src="https://gw.alicdn.com/tfs/TB1pCvLjhD1gK0jSZFKXXcJrVXa-1844-1014.png" width=660>

### debug mode

Press <kbd>Shift-R</kbd> (or `:Debugger`) to startup debugger with `node inspect` (`dlv debug` for golang, `python3 -m pdb` for python3) running in terminal. If you want to start with another file. You can set `debugger_entry` in top of your source code like this:

For Python:

	# debugger_entry = ../index.py

For Go and JavaScript

	// debugger_entry = ../index.go

Debug mode windows:

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

Type `next` + <kbd>Enter</kbd> in Terminal means step over. If you want to quit debug, input `exit` + <kbd>Enter</kbd> in terminal, or `:exit` (or <kbd>Shift-E</kbd>) in source code window. You can input `Ctrl-w N`（Ctrl-w, Shift-N）in terminal window if you want to get more output log. Type `i` to go back for interactive terminal.

Press <kbd>F12</kbd> (or `:BreakPointSetting`) to toggle break points.

Open call stack window or localvars window:

<img src="https://gw.alicdn.com/tfs/TB1TYkFjeL2gK0jSZPhXXahvXXa-714-491.gif" width=550>

Set break point:

<img src="https://gw.alicdn.com/tfs/TB1WFALjoT1gK0jSZFrXXcNCXXa-682-560.gif" width=550>

How to inspect local variables?

- NodeJS: Type `repl` in terminal. Go go the REPL mode and then input variable name . Such as below.
- Golang: Type `print {variable}` or `locals -v {variable}`.
- Python: Type `pp {variable}`

<img src="https://gw.alicdn.com/tfs/TB19_bymHrpK1RjSZTEXXcWAVXa-554-364.png" width=300>

### Chrome DevTools Debug for NodeJS

You can use chrome devtool for nodejs debug. Press <kbd>Shift-W</kbd> . Then connect it to chrome devtool [like this](https://gw.alicdn.com/tfs/TB1ci.QegHqK1RjSZJnXXbNLpXa-1414-797.png).

-----------------

## Licence

This plugin is released under the [MIT License](https://github.com/jayli/vim-easydebugger/blob/master/LICENSE).

Author: [Jayli](http://jayli.github.io/)

