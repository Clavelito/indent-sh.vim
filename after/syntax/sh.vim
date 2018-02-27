" after/syntax/sh.vim
" Last Change:   Tue, 27 Feb 2018 17:44:07 +0900

if exists("g:sh_indent_hide_after_syntax")
  finish
endif

syn cluster shNoQuoteList	contains=shDerefSimple,shDeref,shDoubleQuote,shSingleQuote,shExDoubleQuote,shExSingleQuote,shSpecial,shStringSpecial,shCommandSub
syn cluster shEscSnglQuoteIn	contains=ALLBUT,shCaseSingleQuote,shTestSingleQuote,shSingleQuote,shStringSpecial,shSpecial,shDerefString,shComment,shQuickComment,shHereDoc
syn cluster shBraceExpIn	contains=ALLBUT,shDeref.*,.*Quote,.*Comment,shHereDoc
syn cluster shCurlyList		add=shCurlyEscape,shTwinDot,shExSingleQuote,shDoubleQuote,shSingleQuote	remove=shDerefSpecial
syn cluster shEchoList		remove=shExpr
syn cluster shTestList		remove=shExpr
if exists("b:is_kornshell") || exists("b:is_bash")
 syn cluster shCaseList		add=shDblParen,shParen
endif

syn region  shNoQuote		contained	start="\S" skip="\\\@<!\%(\\\\\)*\\." end='\ze\s'	contains=@shNoQuoteList containedin=shDblBrace
syn region  shTestDoubleQuote	contained	start='"'  skip='\\\@<!\%(\\\\\)*\\"' end='"'		contains=shDeref,shDerefSimple
syn region  shDoubleQuote	matchgroup=shQuote start=+"+ end=+"+					contains=@shDblQuoteList,shStringSpecial,@Spell

syn match   shEscape		'\\\@<!\%(\\\\\)*\\.'			contained
syn clear   shStringSpecial
syn match   shStringSpecial	"[^[:print:] \t]"			contained
syn match   shStringSpecial	"\\\@<!\%(\\\\\)*\\[\\"`$()#]"		contained
syn clear   shSpecial
if exists("b:is_bash")
 syn match   shSpecial		"\\\@<!\%(\\\\\)*\\\%(\o\o\o\|x\x\x\|c[^"]\|[abefnrtv]\)"	contained
endif
syn match   shSpecial		"\\\@<!\%(\\\\\)*\\[\\"`$()#]"
syn match   shEscSnglQuote	"\\\@<!\%(\\\\\)*\\'"			containedin=@shEscSnglQuoteIn
hi def link shEscSnglQuote	shSpecial

syn region  shCurlyIn		matchgroup=Delimiter start="{" end="}"	contained		contains=@shCurlyList oneline
syn match   shBraceExpansion	+\\\@<!\%(\\\\\)*{\%(\%(\\.\|".\{-}\\\@<!\%(\\\\\)*"\|'[^']*'\|{[^{} \t]\+}\|[^{} \t]\)\{-},\|\%({[^{} \t]\+}\|[^{} \t]\)\+[.][.]\)+ contains=shCurlyIn containedin=@shBraceExpIn transparent
syn match   shCurlyEscape	"\\\@<!\%(\\\\\)*\\."			contained
syn match   shTwinDot		"[.][.]"				contained
hi def link shCurlyEscape	shString
hi def link shTwinDot		shComma
hi def link shComma		shOperator

if exists("b:is_bash")
 syn clear  shDerefOff
 syn region shDerefOff		contained	start=':[-+?=]\@!' end='\ze:' end='\ze}' contains=shDeref,shDerefSimple,shArithmetic nextgroup=shDerefLen,shDeref,shDerefSimple
 syn match  shDerefLen		contained	":[^}]\+"				 contains=shDeref,shDerefSimple,shArithmetic
 syn clear  shDerefPattern
 syn match  shDerefPattern	contained	"\_[^}]\+"	contains=shDeref,shDerefSimple,shDerefString,shCommandSub,shDerefEscape nextgroup=shDerefPattern
 syn match  shDerefOp		contained	":\=[-+=?]"	nextgroup=@shDerefPatternList	skipempty
 syn match  shDerefPPS		contained	'/[/#%]\='	nextgroup=shDerefPPSleft	skipempty
 syn region shDerefPPSleft	contained	start='.'	matchgroup=shDerefOp end='/' end='\ze}' contains=@shCommandSubList nextgroup=shDerefPPSright skipempty
elseif exists("b:is_posix")
 syn match  shDerefOp		contained	"##\="		nextgroup=@shDerefPatternList
 syn match  shDerefOp		contained	"%%\="		nextgroup=@shDerefPatternList
 syn clear  shDerefPattern
 syn match  shDerefPattern	contained	"[^}]\+"	contains=shDeref,shDerefSimple,shDerefString,shCommandSub,shDerefEscape nextgroup=shDerefPattern
elseif exists("b:is_kornshell") && exists("g:is_posix") && getline(1) !~# '\<ksh$'
 syn clear  shDerefPattern
 syn match  shDerefPattern	contained	"[^}]\+"	contains=shDeref,shDerefSimple,shDerefString,shCommandSub,shDerefEscape nextgroup=shDerefPattern
endif

if exists("b:is_kornshell") || exists("b:is_bash") || exists("b:is_posix")
 syn region shCommandSub matchgroup=shCmdSubRegion start="\$((\@!" end=")"			contains=@shCommandSubList,shCommandSub,shComment
endif
syn region  shCommandSub	start="`" end="`"						contains=@shCommandSubList,shComment,shQuickComment
syn match   shQuickComment	contained	"\%(^\s*\|\s\)\zs#.\{-}\\\@<!\%(\\\\\)*\ze`"	contains=@shCommentGroup

if exists("g:sh_fold_enabled") && (g:sh_fold_enabled == 2 || g:sh_fold_enabled == 3)
 syn region shHereDoc matchgroup=shHereDoc99 start="<<\s*\\\n\s*\\\z([^\\ \t;&|>]\+\)" matchgroup=shHereDoc99 end="^\z1$" fold
else
 syn region shHereDoc matchgroup=shHereDoc99 start="<<\s*\\\n\s*\\\z([^\\ \t;&|>]\+\)" matchgroup=shHereDoc99 end="^\z1$"
endif
hi def link shHereDoc99		shRedir
