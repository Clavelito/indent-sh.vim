" after/syntax/sh.vim
" Last Change:   Sat, 03 Mar 2018 17:40:12 +0900

if exists("g:sh_indent_hide_after_syntax")
  finish
endif

syn match   shStringSpecial	"\\\@<!\%(\\\\\)*\\[\\"'`$()#]"		contained
syn match   shSpecial		"\\\@<!\%(\\\\\)*\\[\\"'`$()#]"

if exists("b:is_bash") || exists("b:is_posix")
 syn clear  shDerefPattern
 syn match  shDerefPattern	contained	"[^}]\+"	contains=shDeref,shDerefSimple,shDerefString,shCommandSub,shDerefEscape nextgroup=shDerefPattern
endif
if exists("b:is_bash")
 syn match  shDerefOp		contained	":\=[-=?+]"	nextgroup=@shDerefPatternList
endif
