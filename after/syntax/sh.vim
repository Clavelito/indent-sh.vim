" after/syntax/sh.vim
" Last Change:   Thu, 01 Mar 2018 21:55:06 +0900

if exists("g:sh_indent_hide_after_syntax")
  finish
endif

syn match   shStringSpecial	"\\\@<!\%(\\\\\)*\\[\\"'`$()#]"		contained
syn match   shSpecial		"\\\@<!\%(\\\\\)*\\[\\"'`$()#]"

if exists("b:is_bash") || exists("b:is_posix") || exists("b:is_kornshell") && exists("g:is_posix") && getline(1) !~# '\<ksh$'
 syn clear  shDerefPattern
 syn match  shDerefPattern	contained	"[^}]\+"	contains=shDeref,shDerefSimple,shDerefString,shCommandSub,shDerefEscape nextgroup=shDerefPattern
endif

syn match  shDerefOp		contained	":\=[-=?+]"	nextgroup=@shDerefPatternList

if exists("b:is_kornshell") || exists("b:is_bash") || exists("b:is_posix")
 syn region shCommandSub matchgroup=shCmdSubRegion start="\$((\@!" end=")"			contains=@shCommandSubList,shCommandSub,shComment
endif
syn region  shCommandSub	start="`" end="`"						contains=@shCommandSubList,shComment,shQuickComment
syn match   shQuickComment	contained	"\%(^\s*\|\s\)\zs#.\{-}\\\@<!\%(\\\\\)*\ze`"	contains=@shCommentGroup
