" after/syntax/sh.vim
" Last Change:   Wed, 01 Aug 2018 09:32:18 +0900

if exists("g:sh_indent_hide_after_syntax")
  finish
endif

syn cluster shFunctionList	add=shCommandSubBQ
syn match   shEscape		'\\\@<!\%(\\\\\)*\\.'	contained
