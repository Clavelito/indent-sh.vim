" after/syntax/sh.vim
" Last Change:   Tue, 05 Dec 2017 23:16:59 +0900

if exists("g:sh_indent_hide_after_syntax")
  finish
endif

syn cluster shNoQuoteList	contains=shDerefSimple,shDeref,shDoubleQuote,shSingleQuote,shExDoubleQuote,shExSingleQuote,shSpecial,shStringSpecial,shCommandSub
syn cluster shEchoList		remove=shExpr

syn region  shNoQuote		contained	start="\S" skip="\\\@<!\%(\\\\\)*\\." end='\ze\s'	contains=@shNoQuoteList
syn region  shTestDoubleQuote	contained	start='"'  skip='\\\@<!\%(\\\\\)*\\"' end='"'		contains=shDeref,shDerefSimple,shDerefSpecial
syn region  shDoubleQuote	matchgroup=shQuote start=+"+ end=+"+	contains=@shDblQuoteList,shStringSpecial,@Spell

syn match   shStringSpecial	"\\\@<!\zs\%(\\\\\)*\\[\\"'`$()#]"	contained
syn clear shSpecial
if exists("b:is_bash")
 syn match   shSpecial	"\\\@<!\(\\\\\)*\zs\%(\\\o\o\o\|\\x\x\x\|\\c[^"]\|\\[abefnrtv]\)"	contained
endif
syn match   shSpecial	"\\\@<!\zs\%(\\\\\)*\\[\\"'`$()#]"

if exists("b:is_kornshell") || exists("b:is_bash")
 syn cluster shCaseList	add=shDblParen,shParen
endif

if exists("b:is_kornshell") || exists("b:is_bash") || exists("b:is_posix")
 syn region shCommandSub matchgroup=shCmdSubRegion start="\$((\@!" end=")"	contains=@shCommandSubList,shCommandSub,shComment
endif
syn region  shCommandSub	start="`" end="`"				contains=@shCommandSubList,shComment,shQuickComment
syn match   shQuickComment	contained	"\%(^\s*\|\s\)\zs#.\{-}\\\@<!\%(\\\\\)*\ze`"	contains=@shCommentGroup
