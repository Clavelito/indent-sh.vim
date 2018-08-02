" after/syntax/sh.vim
" Last Change:   Thu, 02 Aug 2018 11:31:40 +0900

if exists("g:sh_indent_hide_after_syntax")
  finish
endif

syn cluster shFunctionList	add=shCommandSubBQ
syn match   shEscape		'\\\@<!\%(\\\\\)*\\.'	contained
syn match   shStringSpecial	"\\\@<!\%(\\\\\)*\\[\\"'`$()#]"
