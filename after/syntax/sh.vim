" after/syntax/sh.vim
" Last Change:   Thu, 02 Aug 2018 13:01:28 +0900

if exists("g:sh_indent_hide_after_syntax")
  finish
endif

syn cluster shFunctionList	add=shCommandSubBQ
syn match   shEscape		'\\\@<!\%(\\\\\)*\\.'
