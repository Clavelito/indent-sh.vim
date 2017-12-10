" after/syntax/sh.vim
" Last Change:   Wed, 06 Dec 2017 13:34:49 +0900

if exists("g:sh_indent_hide_after_syntax")
  finish
endif

syn cluster shNoQuoteList	contains=shDerefSimple,shDeref,shDoubleQuote,shSingleQuote,shExDoubleQuote,shExSingleQuote,shSpecial,shStringSpecial,shCommandSub
syn cluster shEchoList		remove=shExpr
syn cluster shTestList		remove=shExpr

syn region  shNoQuote		contained	start="\S" skip="\\\@1<!\zs\\\%(\\\\\)*." end='\ze\s'	contains=@shNoQuoteList containedin=shDblBrace
syn region  shTestDoubleQuote	contained	start='"'  skip='\\\@1<!\zs\\\%(\\\\\)*"' end='"'		contains=shDeref,shDerefSimple,shDerefSpecial
syn region  shDoubleQuote	matchgroup=shQuote start=+"+ end=+"+	contains=@shDblQuoteList,shStringSpecial,@Spell

syn match   shStringSpecial	"\\\@1<!\zs\\\%(\\\\\)*[\\"'`$()#]"	contained
syn clear shSpecial
if exists("b:is_bash")
 syn match   shSpecial	"\\\@1<!\zs\\\%(\\\\\)*\%(\o\o\o\|x\x\x\|c[^"]\|[abefnrtv]\)"	contained
endif
syn match   shSpecial	"\\\@1<!\zs\\\%(\\\\\)*[\\"'`$()#]"

if exists("b:is_kornshell") || exists("b:is_bash")
 syn cluster shCaseList	add=shDblParen,shParen
endif
if exists("b:is_bash") || exists("b:is_kornshell") && exists("g:is_posix") && getline(1) !~# '\<ksh$'
 syn clear  shDerefPattern
 syn match  shDerefPattern	contained	"[^}]\+"	contains=shDeref,shDerefSimple,shDerefPattern,shDerefString,shCommandSub,shDerefEscape nextgroup=shDerefPattern
elseif exists("b:is_posix")
 syn match  shDerefOp		contained	"##\="		nextgroup=@shDerefPatternList
 syn match  shDerefOp		contained	"%%\="		nextgroup=@shDerefPatternList
 syn match  shDerefPattern	contained	"[^}]\+"	contains=shDeref,shDerefSimple,shDerefPattern,shDerefString,shCommandSub,shDerefEscape nextgroup=shDerefPattern
endif

if exists("b:is_kornshell") || exists("b:is_bash") || exists("b:is_posix")
 syn region shCommandSub matchgroup=shCmdSubRegion start="\$((\@!" end=")"	contains=@shCommandSubList,shCommandSub,shComment
endif
syn region  shCommandSub	start="`" end="`"				contains=@shCommandSubList,shComment,shQuickComment
syn match   shQuickComment	contained	"\%(^\s*\|\s\)\zs#.\{-}\\\@<!\%(\\\\\)*\ze`"	contains=@shCommentGroup

if exists("g:sh_fold_enabled") && (g:sh_fold_enabled == 2 || g:sh_fold_enabled == 3)
 syn region shHereDoc matchgroup=shHereDoc99 start="<<\s*\\\n\s*\\\z([^\\ \t;&|>]\+\)" matchgroup=shHereDoc99 end="^\z1$" fold
else
 syn region shHereDoc matchgroup=shHereDoc99 start="<<\s*\\\n\s*\\\z([^\\ \t;&|>]\+\)" matchgroup=shHereDoc99 end="^\z1$"
endif
hi def link shHereDoc99		shRedir
