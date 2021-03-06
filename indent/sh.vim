" Vim indent file
" Language:         Shell Script
" Author:           Clavelito <maromomo@hotmail.com>
" Last Change:      Tue, 06 Apr 2021 15:56:28 +0900
" Version:          5.29
" Description:      No warranty Please try at your own risk.
"                   If you do not want to indent case labels, set the next line.
"                   let g:sh_indent_case_labels = 0


if exists("b:did_indent")
  finish
endif
let b:did_indent = 1

setlocal indentexpr=GetShIndent()
setlocal indentkeys+=0=then,0=do,0=elif,0=fi,0=esac,0=done
setlocal indentkeys+=0=end,0),0=&&,0<Bar>
setlocal indentkeys-=:,0#

let b:undo_indent = 'setlocal indentexpr< indentkeys<'
      \.' | unlet! b:sh_indent_tabstop b:sh_indent_indentkeys b:sh_indent_synhi'

if !exists("g:sh_indent_case_labels")
  let g:sh_indent_case_labels = 1
endif

if exists("*GetShIndent")
  finish
endif

let s:cpo_save = &cpo
set cpo&vim

function GetShIndent()
  if exists("b:sh_indent_tabstop")
    let &tabstop = b:sh_indent_tabstop
    unlet b:sh_indent_tabstop
  endif
  if exists("b:sh_indent_indentkeys")
    let &indentkeys = b:sh_indent_indentkeys
    unlet b:sh_indent_indentkeys
  endif
  if s:IsFtZsh() && !exists("b:sh_indent_synhi") && exists("b:current_syntax")
    call s:SetZshSubstString()
  endif
  let lnum = prevnonblank(v:lnum - 1)
  if lnum == 0
    unlet! s:TbSum
    return 0
  endif
  let cline = getline(v:lnum)
  let line = getline(lnum)
  if (s:IsQuote(v:lnum, 1) || cline =~  '^["$`'. "']") && s:IsQuote(lnum, line)
    unlet! s:TbSum
    return s:KeepSpaceIndent(cline)
  elseif s:IsHereDoc(lnum, line)
    return s:HereDocIndent(cline)
  elseif cline =~# '^#'
    unlet! s:TbSum
    return 0
  endif
  unlet! s:TbSum
  let [line, lnum] = s:SkipCommentLine(lnum, line)
  let [pline, pnum] = s:SkipCommentLine(lnum)
  let ind = s:PrevLineIndent(cline, line, lnum, pline, pnum)
  let ind = s:CurrentLineIndent(cline, line, lnum, pline, pnum, ind)
  return ind
endfunction

function s:PrevLineIndent(cline, line, lnum, pline, pnum)
  let ind = indent(a:lnum)
  let s:CsInd = 0
  if !s:IsHereDoc(a:lnum, 1) && s:IsHereDoc(a:pnum, 1)
    return s:ContinueLineIndent(a:line, a:lnum, s:hered)
  elseif s:IsInsideCaseLabel(a:pline, a:pnum, a:line, a:lnum)
  elseif s:IsDoThen(a:line, a:lnum) && a:line !~# '^\s*[})]'
        \ && !s:IsBackSlashOnly(a:pline, a:pnum)
        \ && s:SubstCount(a:lnum, 1) == s:SubstCount(v:lnum, 1)
    let ind = s:DoThenIndent(a:line, a:lnum, ind) + shiftwidth()
  else
    let ind = s:ControlStatementIndent(a:line, a:lnum, ind)
  endif
  if s:IsCase(a:pline, a:pnum)
        \ || s:IsCaseBreak(a:pline, a:pnum) && !s:IsEsac(a:line)
        \ || !s:CsInd && s:IsBackSlash(a:pline, a:pnum) && s:IsCaseLabel(a:lnum)
    let ind = s:CaseLabelIndent(a:line, a:lnum, ind)
  elseif a:line =~# ')\|`' && s:IsSubSt(a:lnum, 1) && !s:IsSubSt(v:lnum, 1)
        \ && !s:IsBackSlash(a:line, a:lnum)
    let ind = s:ContinueLineIndent(a:line, a:lnum, s:subst)
  elseif a:line =~# '"\|\%o47\|}' && s:IsQuote(a:pnum, a:pline)
    let ind = s:ContinueLineIndent(a:line, a:lnum, s:quote)
  elseif a:line =~# ')\|`' && s:IsSubSt(v:lnum, 1)
        \ && s:SubstCount(a:lnum, 1) > s:SubstCount(v:lnum, 1)
    let ind = s:InsideSubStIndent(a:lnum)
  elseif (s:IsBackSlash(a:line, a:lnum) && a:lnum == v:lnum - 1
        \ || s:IsBackSlash(a:line, a:lnum) && a:lnum != v:lnum - 1
        \ && s:IsContinue(a:line, a:lnum))
        \ && ((!s:IsBackSlash(a:pline, a:pnum) || a:pnum != a:lnum - 1)
        \ && !s:IsExprCont(a:pline, a:pnum)
        \ || s:IsContinue(a:pline, a:pnum) && s:IsBackSlashOnly(a:line, a:lnum))
    let ind = s:BaseLevelIndent(a:pline, a:pnum, a:lnum, ind, 1)
  elseif s:IsBackSlashOnly(a:line, a:lnum) && a:lnum != v:lnum - 1
    let ind = s:BaseLevelIndent(a:line, a:lnum, v:lnum, ind)
  elseif a:line =~# '\$(\|`' && s:IsSubSt(v:lnum, 1)
        \ && s:SubstCount(a:lnum, 1) < s:SubstCount(a:lnum, a:line)
    let ind = s:OpenSubStIndent(a:pline, a:pnum, a:lnum, ind)
  elseif s:IsBackSlashOnly(a:pline, a:pnum) && a:pnum == a:lnum - 1
        \ && (s:IsContinue(a:line, a:lnum) && !s:IsBackSlash(a:line, a:lnum)
        \ || s:IsTailBar(a:line, a:lnum))
    let ind = s:InsideContIndent(a:pline, a:pnum, ind)
  elseif !s:IsContinue(a:line, a:lnum) && !s:IsBackSlash(a:line, a:lnum)
        \ && (s:IsContinue(a:pline, a:pnum)
        \ || s:IsBackSlashOnly(a:pline, a:pnum))
    let ind = s:ContinueLineIndent(a:line, a:lnum, a:pline, a:pnum)
  endif
  if s:IsDoThen(a:line, a:lnum)
  elseif s:IsContinue(a:line, a:lnum) || s:IsHeadContinue(a:cline, v:lnum)
        \ || s:IsExprCont(a:line, a:lnum)
    call s:OvrdIndentKeys("*<CR>,*<NL>")
  else
    let BPos = s:IsCloseBrace(a:line, a:lnum)
    let PPos = s:IsCloseParen(a:line, a:lnum)
    if BPos && BPos >= PPos && !s:IsBackSlash(a:line, a:lnum)
      let ind = s:CloseTailBraceIndent(a:lnum, ind)
    elseif PPos && !s:CsInd && !s:IsBackSlash(a:line, a:lnum)
          \ && !s:IsCase(a:pline, a:pnum) && !s:IsCaseBreak(a:pline, a:pnum)
          \ && s:SubstCount(a:lnum, 1) == s:SubstCount(v:lnum, 1)
          \ && !s:IsCaseParen(a:lnum, PPos)
      let ind = s:CloseParenIndent(a:line, ind, a:lnum, PPos)
    endif
  endif
  if s:IsCaseBreak(a:line, a:lnum)
    let ind -= shiftwidth()
  elseif (s:IsContinue(a:pline, a:pnum) || s:IsHeadContinue(a:line, a:lnum))
        \ && (s:IsOpenBrace(a:line, a:lnum) || s:IsOpenParen(a:line, a:lnum))
    let ind = indent(s:SkipContinue(a:pline, a:pnum, a:lnum)) + shiftwidth()
  elseif !s:CsInd && (s:IsOpenBrace(a:line,a:lnum)
        \ || s:IsOpenParen(a:line, a:lnum) && !s:IsBackSlash(a:line, a:lnum))
    let ind += shiftwidth()
  endif
  return ind
endfunction

function s:CurrentLineIndent(cline, line, lnum, pline, pnum, ind)
  let ind = a:ind
  if !s:IsHeadContinue(a:cline, v:lnum)
        \ && a:lnum == v:lnum - 1 && ind == indent(a:lnum)
        \ && s:IsBackSlashOnly(a:line, a:lnum)
        \ && (s:IsHeadContinue(a:line, a:lnum) || s:IsContinue(a:pline, a:pnum))
        \ && ind - shiftwidth() == s:BaseLevelIndent(a:line,a:lnum,v:lnum, ind)
    let ind += shiftwidth()
  elseif s:IsHeadContinue(a:cline, v:lnum)
        \ && a:lnum == v:lnum - 1 && !s:IsHeadContinue(a:line, a:lnum)
        \ && s:IsBackSlashOnly(a:line, a:lnum)
        \ && ind - shiftwidth() > s:BaseLevelIndent(a:line, a:lnum, v:lnum, ind)
    let ind = indent(s:SkipContinue(a:line, a:lnum, v:lnum)) + shiftwidth()
  elseif (s:IsHeadContinue(a:cline, v:lnum) || s:IsContinue(a:line, a:lnum))
        \ && s:SubstCount(v:lnum, 1) == s:SubstCount(v:lnum, a:cline)
        \ && (s:IsOpenBrace(a:cline, v:lnum) || s:IsOpenParen(a:cline, v:lnum))
    let ind = indent(s:SkipContinue(a:line, a:lnum, v:lnum))
  elseif s:IsExprCont(a:line, a:lnum)
        \ && (s:IsOpenBrace(a:cline, v:lnum) || s:IsOpenParen(a:cline, v:lnum))
    let ind = indent(a:lnum)
  elseif a:cline =~# '^\s*)'
    let ind = s:CloseParenIndent(a:cline, ind)
  elseif s:IsInsideCaseLabel(a:line, a:lnum, a:cline, 0)
  elseif s:IsEsac(a:cline) && !s:IsCaseBreak(a:line, a:lnum)
    let ind -= g:sh_indent_case_labels ? shiftwidth() * 2 : shiftwidth()
  elseif s:IsEsac(a:cline) && g:sh_indent_case_labels
        \ || a:cline =~# '^\s*\%(fi\|done\)\>'. s:rear1
        \ || a:cline =~# '^\s*\%(else\|elif\)\>'. s:rear2
        \ || a:cline =~# '^\s*end\>'. s:rear1 && s:IsFtZsh()
        \ || a:cline =~# '^\s*\%(then\|do\)\>'. s:rear2 && s:CsInd > 0
        \ || a:cline =~# '^\s*}'
    let ind -= shiftwidth()
  elseif a:cline =~# '^\s*\%(then\|do\)\>'. s:rear2 && indent(a:lnum) == ind
        \ && a:line !~# '^\s*[})]'
    let ind = s:DoThenIndent(a:cline, v:lnum, ind)
  endif
  if a:cline =~# '^\s*[deft]' && ind < indent(v:lnum)
    call s:OvrdIndentKeys()
  endif
  unlet s:CsInd
  return ind
endfunction

function s:ControlStatementIndent(line, lnum, ind, ...)
  let ind = a:ind
  let ptdic = s:PtDic()
  if s:IsFtZsh()
        \ && (a:line =~# '^\s*}\s*\%(elif\|else\|always\)\>'
        \ || s:IsOutside(a:line, a:lnum, '\%())\|\]\]\)\s*{'))
    let ind += shiftwidth()
  elseif max(map(keys(ptdic), 'a:line =~# v:val'))
    for key in keys(ptdic)
      let line = ""
      for str in split(a:line, key)
        let line .= str
        if str =~# key
              \ && (a:0 && !s:IsInside(a:lnum, line) && !s:IsSubSt(a:lnum, line)
              \ || !a:0 && !s:IsInside(a:lnum, line))
          let ind += ptdic[key]
        endif
      endfor
    endfor
  endif
  let s:CsInd = ind - a:ind
  return ind
endfunction

function s:SkipCommentLine(lnum, ...)
  let lnum = a:lnum
  if !a:0 && s:GetPrevNonBlank(lnum)
    let lnum = s:PLnum
    let line = getline(lnum)
  elseif !a:0
    let lnum = 0
    let line = ""
  else
    let line = a:1
  endif
  while lnum && line =~# '^\s*#' && s:IsComment(lnum, line)
        \ && s:GetPrevNonBlank(lnum)
    let lnum = s:PLnum
    let line = getline(lnum)
  endwhile
  unlet! s:PLnum
  return [line, lnum]
endfunction

function s:SkipContinue(line, lnum, onum, ...)
  let [line, lnum] = s:SkipCommentLine(a:lnum, a:line)
  let onum = a:onum
  while lnum && (s:IsBackSlash(line, lnum) || s:IsContinue(line, lnum))
    let pnum = lnum - 1
    while pnum && s:IsBackSlash(getline(pnum), pnum)
      let lnum = pnum
      let pnum -= 1
    endwhile
    if s:IsQuote(lnum, 1)
      let lnum = s:SkipItemLine(lnum, s:quote)
    endif
    let onum = lnum
    let [line, lnum] = s:SkipCommentLine(lnum)
  endwhile
  unlet! s:PLnum
  return a:0 ? [line, lnum, onum] : onum
endfunction

function s:SkipItemLine(lnum, item, ...)
  let lnum = a:lnum
  let root = s:IsSubSt(v:lnum, 1)
  while s:GetPrevNonBlank(lnum)
        \ && (s:MatchSyntaxItem(lnum, 1, a:item, root)
        \ || s:MatchSyntaxItem(s:PLnum, getline(s:PLnum), a:item, root))
    let lnum = s:PLnum
  endwhile
  if a:0 && s:GetPrevNonBlank(lnum)
    let lnum = s:SkipContinue(getline(s:PLnum), s:PLnum, lnum)
  endif
  unlet s:PLnum
  return lnum
endfunction

function s:InsideContIndent(line, lnum, ind)
  let line = a:line
  let lnum = a:lnum
  let ind = a:ind
  while lnum && s:IsBackSlashOnly(line, lnum)
    if s:IsHeadContinue(line, lnum)
      return indent(lnum)
    elseif s:IsQuote(lnum, 1)
      let lnum = s:SkipItemLine(lnum, s:quote)
    endif
    let ind = indent(lnum)
    let lnum -= 1
    let line = getline(lnum)
  endwhile
  return ind
endfunction

function s:DoThenIndent(l, n, i)
  if a:l =~# '\<do\>'
    let pt1 = '\<\%(while\|until\)\>\%(.*\<do\>\)\@!'
    let pt2 = '^\s*\%(do\>\|\%(while\|until\|for\|select\)\>.*\<do\>\)'
  else
    let pt1 = '\<\%(if\|elif\)\>\%(.*\<then\>\)\@!'
    let pt2 = ""
  endif
  let lnum = a:n - 1
  let sum = 2
  while lnum && sum
    if indent(lnum) < a:i
      let line = getline(lnum)
      if line =~# '^\s*\%(#\|$\)\|^"\s*\%(;\|#\|$\)' || s:IsInside(lnum, 1)
        let sum += 1
      elseif strlen(pt2) && line =~# pt2
        break
      elseif s:IsOutside(line, lnum, pt1)
        return indent(lnum)
      endif
      let sum -= 1
    endif
    let lnum -= 1
  endwhile
  return a:i
endfunction

function s:CaseLabelIndent(line, lnum, ind)
  let ind = a:ind
  if !s:IsBackSlashOnly(a:line, a:lnum) && !s:IsEsac(a:line)
    let pos = s:IsOutside(a:line, a:lnum, s:noesc. ")")
    let ind += pos ? shiftwidth() : 0
    let line = repeat(" ", pos). strpart(a:line, pos)
    let ind = pos ? s:ControlStatementIndent(line, a:lnum, ind) : ind
  endif
  return ind
endfunction

function s:InsideSubStIndent(lnum)
  let lnum = a:lnum
  let depth = s:SubstCount(v:lnum, 1)
  while s:GetPrevNonBlank(lnum) && s:SubstCount(lnum, 1) > depth
    let lnum = s:PLnum
  endwhile
  unlet s:PLnum
  let ind = indent(lnum) + shiftwidth() * (depth - s:SubstCount(lnum, 1))
  return ind
endfunction

function s:BaseLevelIndent(pline, pnum, lnum, ind, ...)
  let onum = s:SkipContinue(a:pline, a:pnum, a:lnum)
  let ind = s:ControlStatementIndent(getline(onum), onum, indent(onum))
  if a:ind == ind && a:0
    let ind += shiftwidth()
  elseif a:0
    let ind = a:ind
  endif
  return ind
endfunction

function s:OpenSubStIndent(pline, pnum, lnum, ind)
  let ind = a:ind
  if s:BaseLevelIndent(a:pline, a:pnum, a:lnum, ind, 1) > ind
    let ind += shiftwidth() * (s:SubstCount(v:lnum,1) - s:SubstCount(a:lnum,1))
  endif
  return ind
endfunction

function s:ContinueLineIndent(line, lnum, ...)
  if a:0 == 1
    let onum = s:SkipItemLine(a:lnum, a:1, 1)
    let [line, lnum] = s:SkipCommentLine(onum)
  else
    let [line, lnum, onum] = s:SkipContinue(a:1, a:2, a:line, 1)
  endif
  let ind = indent(onum)
  let oline = getline(onum)
  let ocount = s:SubstCount(onum, 1)
  let vcount = s:SubstCount(v:lnum, 1)
  if ocount != vcount
    let ind += shiftwidth() * (vcount - ocount)
  endif
  if (s:IsCase(line, lnum) || s:IsCaseBreak(line, lnum) && !s:IsEsac(oline))
    if s:IsCaseBreak(a:line, a:lnum)
      let ind += shiftwidth()
    elseif s:IsOutside(oline, onum, s:noesc. ")") > ind
      let ind = s:CaseLabelIndent(oline, onum, ind)
    elseif s:IsOutside(a:line, a:lnum, s:noesc. ")")
      let ind = s:CaseLabelIndent(a:line, a:lnum, ind)
    elseif !s:IsBackSlash(a:line, a:lnum)
      let ind += shiftwidth()
    endif
  elseif oline =~# '^\t\+[ ]\+.*<<-' && !&expandtab && s:IsHereDoc(onum, oline)
    let ind -= ind % shiftwidth()
  elseif s:IsBackSlash(a:line, a:lnum)
    let ind += shiftwidth()
  elseif s:CsInd
    let ind += s:CsInd
  elseif !s:IsOutside(a:line, a:lnum, '\<\%(fi\|done\)\>')
    let ind = s:ControlStatementIndent(oline, onum, ind, 1)
  endif
  return ind
endfunction

function s:CloseParenIndent(line, ind, ...)
  let ind = a:ind
  let expr = 's:IsInside(line("."),col("."))||s:IsCaseParen(line("."),col("."))'
  let pos = getpos(".")
  let snum = v:lnum
  if a:0
    call cursor(a:1, a:2)
    let snum = a:1
  elseif a:line[col(".") - 1] ==# ")"
    call search('.\n\=)', "bW")
  else
    call cursor(0, 1)
  endif
  let s:root = s:IsSubSt(line("."), col("."))
  let lnum = searchpair(s:noesc. '\zs(', "", s:noesc. '\zs)', "bW", expr)
  unlet s:root
  if lnum > 0 && snum != lnum
    let sum = 0
    let lcol = col(".")
    while search(s:noesc. '(\%(\s*)\)\@!', "bW", lnum)
      if eval(expr)
        continue
      elseif col(".") == lcol - 1
        let lcol = 0
      else
        let lcol = col(".")
        let enum = searchpair(s:noesc.'\zs(', "", s:noesc.'\zs)',"W",expr,lnum)
        call cursor(lnum, lcol)
        let sum += lnum != enum ? 1 : 0
      endif
    endwhile
    let sum = s:IsCaseLabel(lnum) ? sum + 1 : sum
    let ind = indent(lnum) + sum * shiftwidth()
  endif
  call setpos(".", pos)
  return ind
endfunction

function s:CloseTailBraceIndent(lnum, ind)
  if s:IsFtZsh()
    let item = [ s:noesc. "{",
          \ '^\s*}\|\%(^\s*\)\@<!.\ze'. s:noesc. "}",
          \ '\%(^\s*\)\@<!.\ze'. s:noesc. "}" ]
  else
    let item = [
          \ '\<\%(if\|elif\|while\|until\)\s\+\%(!\s\+\)\=\zs{'
          \. '\|\<function\s\+\S\+\s\+\zs{'
          \. '\|\%({\s\+\)\@<={\|\%(&&\|||\=\|)\)\s*\%(!\s\)\=\s*\zs{'
          \. '\|'. s:front. '\%(!\s\)\=\s*\zs{',
          \ '\%(^\|\%([;&)]\|}\@1<=\s\)\s*\%(done\|fi\)\=\|;[;&|]\s*esac\)\s*}',
          \ '\%(\%([;&)]\|}\@1<=\s\)\s*\%(done\|fi\)\=\|;[;&|]\s*esac\)\s*}'
          \. '\|^\s*\%(done\|fi\|esac\)\s\+}' ]
  endif
  return s:CloseTailIndent(a:lnum, a:ind, item)
endfunction

function s:CloseTailIndent(lnum, ind, item)
  let ind = a:ind
  let [pt1, pt2, pt3] = a:item
  let expr = 's:IsInside(line("."),col("."))||s:IsCaseLabel(line("."),col("."))'
  let pos = getpos(".")
  let lnum = 0
  call cursor(0, 1)
  while search(pt3, "bW", a:lnum)
    if eval(expr)
      continue
    else
      let lnum = -1
      break
    endif
  endwhile
  let pos2 = getpos(".")
  if lnum
    let lnum = searchpair(pt1, "", pt2, "bW", expr)
  endif
  if lnum > 0 && lnum != a:lnum && indent(lnum) < indent(a:lnum)
    call setpos(".", pos2)
    let ind = searchpair(pt1, "", pt2, "rmbW", expr, lnum)
    call setpos(".", pos2)
    let ind -= searchpair(pt1, "", pt2, "mbW", expr, lnum)
    let ind = s:IsCaseLabel(lnum) ? ind + 1 : ind
    let ind = indent(lnum) + ind * shiftwidth()
  endif
  call setpos(".", pos)
  return ind
endfunction

function s:IsCaseLabel(n, ...)
  let val = 0
  let pos = s:IsOutside(getline(a:n), a:n, s:noesc. ")")
  if a:0 && a:1 < pos
    let [line, lnum] = s:SkipCommentLine(a:n)
    let [line, lnum] = s:SkipContinue(line, lnum, a:n, 1)[0 : 1]
    let val = s:IsCase(line, lnum) || s:IsCaseBreak(line, lnum) ? 1 : 0
  elseif pos
    let val = s:IsCaseParen(a:n, pos)
  endif
  return a:0 ? val && a:1 < pos : val
endfunction

function s:SkipHereDocLine()
  let pos = getpos(".")
  while search('<\@1<!<<<\@!-\=', "bW") && s:IsHereDoc(line("."), 1)
  endwhile
  let lnum = line(".")
  call setpos(".", pos)
  return lnum
endfunction

function s:SpaceHereDoc(lnum)
  let pos = getpos(".")
  call cursor(a:lnum, 1)
  let sum = search('^\t*[ ]', "W")
        \ && s:IsHereDoc(line("."), 1)
        \ && s:SkipHereDocLine() == a:lnum ? 1 : 0
  call setpos(".", pos)
  return sum
endfunction

function s:TabHereDoc(lnum, tab)
  if exists("s:TbSum") && has_key(s:TbSum, v:lnum)
    let val = s:TbSum[v:lnum]
    let s:TbSum = { nextnonblank(v:lnum + 1) : val }
    return val
  endif
  let pos = getpos(".")
  call cursor(a:lnum, 1)
  let sum = matchend(getline(search('^\t*\S', "W")), '\t*', 0)
  while search('^\t\{-,'. sum. '}\S', "W")
        \ && s:IsHereDoc(line("."), 1)
        \ && s:SkipHereDocLine() == a:lnum
    let sum = matchend(getline("."), '\t*', 0)
  endwhile
  call setpos(".", pos)
  let s:TbSum = { nextnonblank(v:lnum + 1) :  a:tab - sum }
  return a:tab - sum
endfunction

function s:HereDocIndent(cline)
  let onum = s:SkipHereDocLine()
  let oline = getline(onum)
  if !&expandtab && oline =~# '<<-'
    let ind = indent(onum)
  else
    let ind = s:KeepSpaceIndent(a:cline)
    unlet! s:TbSum
  endif
  if !&expandtab && oline =~# '<<-' && strlen(a:cline) && a:cline !~# '^\s\+$'
    let sttab = ind / &tabstop + (ind % &tabstop ? 1 : 0)
    let tbind = a:cline =~# '^\t' ? matchend(a:cline, '\t*', 0) : 0
    let spind = s:IsHereDoc(v:lnum, 1)
          \ ? strdisplaywidth(matchstr(a:cline, '\s*', tbind)) : 0
    if s:SpaceHereDoc(onum) || !s:IsHereDoc(v:lnum, 1)
      let tbind = sttab
      unlet! s:TbSum
    else
      let tbind += s:TabHereDoc(onum, sttab)
    endif
    if spind >= &tabstop
      let b:sh_indent_tabstop = &tabstop
      let &tabstop = spind + 1
    endif
    let ind = tbind * &tabstop + spind
  elseif !&expandtab && oline =~# '<<-'
    let sttab = ind / &tabstop + (ind % &tabstop ? 1 : 0)
    let ind = &autoindent ? indent(v:lnum) : sttab * &tabstop
    unlet! s:TbSum
  elseif &expandtab && oline =~# '<<-' && a:cline =~# '^\t'
    let tbind = matchend(a:cline, '\t*', 0)
    let ind = ind - tbind * &tabstop
  endif
  return ind
endfunction

function s:GetPrevNonBlank(lnum)
  let s:PLnum = prevnonblank(a:lnum - 1)
  return s:PLnum
endfunction

function s:OvrdIndentKeys(...)
  if !exists("b:sh_indent_indentkeys")
    let b:sh_indent_indentkeys = &indentkeys
  endif
  if a:0
    exec 'setlocal indentkeys+='. a:1
  else
    setlocal indentkeys+=a,b,c,d,<e>,f,g,h,i,j,k,l,m,n,<o>,p,q,r,s,t,u,v,w,x,y,z
    setlocal indentkeys+=A,B,C,D,E,F,G,H,I,J,K,L,M,N,<O>,P,Q,R,S,T,U,V,W,X,Y,Z
    setlocal indentkeys+=1,2,3,4,5,6,7,8,9,<0>,_,-,=,+,.
  endif
endfunction

function s:IsInsideCaseLabel(line, lnum, cline, clnum)
  return s:IsCase(a:line, a:lnum)
        \ || s:IsCaseBreak(a:line, a:lnum) && !s:IsEsac(a:cline)
        \ || a:clnum && s:IsBackSlash(a:line, a:lnum) && a:lnum == a:clnum - 1
        \ && s:IsBackSlash(a:cline, a:clnum)
        \ || !a:clnum && s:IsBackSlash(a:line, a:lnum) && a:lnum == v:lnum - 1
endfunction

function s:IsOutside(l, n, pt, ...)
  let pos = 0
  let sum = 0
  while pos > -1
    let pos = matchend(a:l, a:pt, pos)
    if pos > -1 && !s:IsInside(a:n, pos)
      if a:0
        let sum = pos
      else
        return pos
      endif
    endif
  endwhile
  return sum
endfunction

function s:IsInside(n, p)
  return s:IsQuote(a:n, a:p) || s:IsComment(a:n, a:p) || s:IsHereDoc(a:n, a:p)
endfunction

function s:IsFtZsh()
  return &ft ==# 'zsh'
endfunction

function s:IsOpenBrace(l, n)
  let pt = '\%(^\|;\|&&\|||\=\)[^])#]*\%((\s*)\s*\)\=\%(\$\@1<!\&'.s:noesc.'\){\ze\s*\%(#.*\)\=$'
  return s:IsOutside(a:l, a:n, pt)
endfunction

function s:IsOpenParen(l, n)
  if a:l !~# '()\@!'
    return 0
  endif
  let pt1 = s:noesc. '('
  let coln = s:IsOutside(a:l, a:n, pt1)
  if !coln || coln && a:l =~# '^\s*((\@!\|\<case\>' && s:IsCaseParen(a:n, coln)
    return 0
  endif
  let snum = s:SubstCount(a:n, coln)
  if snum > s:SubstCount(a:n, 1)
    return 0
  endif
  let expr = 's:IsInside(a:n,col("."))'
  let pos = getpos(".")
  call cursor(a:n, coln)
  let s:root = s:IsSubSt(a:n, col("."))
  let lnum = searchpair(s:noesc. '\zs(', "", s:noesc. '\zs)', "W", expr, a:n)
  unlet s:root
  if lnum != a:n
    call setpos(".", pos)
    return 1
  endif
  while search(s:noesc. '\zs(', "W", a:n)
    if eval(expr) || snum < s:SubstCount(a:n, col("."))
      continue
    else
      let snum = s:SubstCount(a:n, col("."))
      let s:root = s:IsSubSt(a:n, col("."))
      let lnum = searchpair(s:noesc.'\zs(', "", s:noesc.'\zs)', "W", expr, a:n)
      unlet s:root
      if lnum != a:n
        call setpos(".", pos)
        return 1
      endif
    endif
  endwhile
  call setpos(".", pos)
  return 0
endfunction

function s:IsCloseBrace(l, n)
  if s:IsFtZsh()
    let pt = '\%(^\s*\)\@<!.\ze'. s:noesc. "}"
  else
    let pt = '\%(\%([;&)]\|}\@1<=\s\)\s*\%(done\|fi\)\=\|;[;&|]\s*esac\)\s*\ze}'
          \. '\|^\s*\%(done\|fi\|esac\)\s\+\ze}'
  endif
  return s:IsOutside(a:l, a:n, pt, 1)
endfunction

function s:IsCloseParen(l, n)
  return s:IsOutside(a:l, a:n, s:noesc. '(\@1<!))\@!', 1)
endfunction

function s:IsCase(l, n)
  let head = s:front
  let tail = '\<case\>\%(.*;[;&|]\s*\<esac\>\)\@!'
  let pos = s:IsOutside(a:l, a:n, s:noesc. ')\ze\s*'. tail)
  if pos
    let pos2 = getpos(".")
    call cursor(a:n, pos)
    if s:IsCaseParen(a:n, pos)
      let head = s:noesc. ')\s*'
    endif
    call setpos(".", pos2)
  elseif s:IsOutside(a:l, a:n, s:noesc. '[;&|]\ze\s*'. tail)
    return 1
  endif
  return s:IsOutside(a:l, a:n, head. tail)
endfunction

function s:IsCaseBreak(l, n)
  let pt = ';[;&|]\%(.*\<esac\>\)\@!'
  return s:IsOutside(a:l, a:n, pt)
endfunction

function s:IsEsac(l)
  return a:l =~# '^\s*esac\>'. s:rear1
endfunction

function s:IsExprCont(l, n)
  let pt = s:front. '\<\%(if\|elif\|while\|until\)\ze\%(\s*\\\=\|\s\+#.*\)$'
  return s:IsOutside(a:l, a:n, pt)
endfunction

function s:IsBackSlash(l, n)
  return a:l =~# s:noesc. '\\$' && !s:IsComment(a:n, a:l)
endfunction

function s:IsBackSlashOnly(l, n)
  let pt = '\%(\%(\%(&&\|||\|\%([;|]\@1<!\&'. s:noesc. '\)|&\=\)\s*\)\@<!'
        \. '\&\%(^\s*\%(if\|elif\|while\|until\)\>\s*\)\@<!\&'. s:noesc. '\)\\$'
  return a:l =~# pt && !s:IsInside(a:n, a:l)
endfunction

function s:IsTailBar(l, n)
  let pt = '\%([;|]\@1<!\&'. s:noesc. '\)|&\=\ze\s*\%(#.*\|\\\)\=$'
  return s:IsOutside(a:l, a:n, pt)
endfunction

function s:IsHeadContinue(l, n)
  let pt = '^\s*\%(&&\|||\=\)'
  return s:IsOutside(a:l, a:n, pt)
endfunction

function s:IsContinue(l, n)
  let pt = '.\ze\%(&&\|||\|\%([;|]\@1<!\&'.s:noesc.'\)|&\=\)\s*\%(#.*\|\\\)\=$'
  return s:IsOutside(a:l, a:n, pt)
endfunction

function s:IsDoThen(l, n)
  let pt = '\%('. s:front. '\<\%(if\|elif\)\>.*\)\@<!'
        \. '\%(;\|\]\]\|))\=\|}\)\s*then\>\%(.*[;&)}]\s*fi\>\)\@!'
        \. '\|\%('. s:front. '\<\%(while\|until\|for\|select\)\>.*\)\@<!'
        \. '\%(;\|\]\]\|))\=\|}\)\s*do\>\%(.*[;&)}]\s*done\>\)\@!'
  return s:IsOutside(a:l, a:n, pt)
endfunction

function s:IsCaseParen(n, p)
  let pt = '\%(\<case\s.\{-}\sin\>\%(\s*$\|\s\|(\)\|;[;&|]'
        \. '\%(\s*esac\>\|\s*\%(#.*\)\=\n\%(\_^\s*\%(#.*\)\=\n\)*'
        \. '\_^\s*esac\>\)\@!\)\%(\s*\%(#.*\)\=\n\%(\_^\s*\%(#.*\)\=\n\)*\)\='
  if getline(a:n)[a:p - 1] ==# ")"
    let pt .= '\%("\%(\\\@1<!\%(\\\\\)*\\"\|\_[^"]\)\{-}"\|'. "'\\_[^']*'"
          \. '\|\\\@1<!\%(\\\\\)*\\.\|\_[^)]\)\+)'
  else
    let pt .= '\_[^()]*(\|\<case\s.\{-}\sin('
  endif
  let pos = getpos(".")
  let lnum = search(pt, "cbeW")
  let cnum = col(".")
  if !(a:n == lnum && a:p == cnum)
    call setpos(".", pos)
    return 0
  endif
  let lnum = search(pt, "bW")
  let cnum = col(".")
  call setpos(".", pos)
  return lnum && !s:IsInside(lnum, cnum)
endfunction

function s:KeepSpaceIndent(line)
  if !&expandtab && strlen(a:line) > 0 && a:line =~ '^\t*[ ]'
    let pos = matchend(a:line, '^\t*')
    let len = strdisplaywidth(matchstr(a:line, '[ ]\s*'), pos * &tabstop)
    if len >= &tabstop
      let b:sh_indent_tabstop = &tabstop
      let &tabstop = len + 1
    endif
    return pos * &tabstop + len
  endif
  return indent(v:lnum)
endfunction

function s:NumOrStr(p)
  return type(a:p) == 0 ? a:p : strlen(a:p)
endfunction

function s:MatchSyntaxItem(n, p, i, s, ...)
  return match(map(synstack(a:n, s:NumOrStr(a:p)),
        \ 'synIDattr(v:val, "name")'), a:i, a:s, a:0 ? a:1 : 1) + 1
endfunction

function s:SubstCount(n, p)
  return count(map(synstack(a:n, s:NumOrStr(a:p)),
        \ 'synIDattr(v:val, "name") =~? s:subst'), 1)
endfunction

function s:IsQuote(n, p)
  return s:MatchSyntaxItem(a:n, a:p, s:quote,
        \ exists("s:root") ? s:root : s:IsSubSt(a:n, a:p))
endfunction

function s:IsHereDoc(n, p)
  return s:MatchSyntaxItem(a:n, a:p, s:hered, 0)
endfunction

function s:IsComment(n, p)
  return s:MatchSyntaxItem(a:n, a:p, s:comnt, 0)
endfunction

function s:IsSubSt(n, p)
  return s:MatchSyntaxItem(a:n, a:p, s:subst, 0, s:SubstCount(a:n, a:p))
endfunction

function s:PtDic()
  return {
        \ '\%(;\|\]\]\|))\=\|}\)\s*\%(do\|then\)'. s:rear2. '\zs'
        \ : shiftwidth(),
        \ '^\s*\%(do\|then\|else\)'. s:rear2. '\zs'
        \ : shiftwidth(),
        \ s:front. '\<\%(if\|elif\|while\|until\)\zs\%(\s*\\\=\|\s\+#.*\)$'
        \ : shiftwidth(),
        \ s:front. '\<\%(if\|elif\|while\|until\)\s\+[^#\\[:blank:]]\%(.*\%(;\|\]\]\|))\=\|}\)\s*\%(do\|then\)\>\)\@!\zs'
        \ : shiftwidth(),
        \ s:front. '\<\%(for\|select\)\s\+\h\w*\s\+in\%(\s\%(.*;\s*\%(do\|then\)\>\)\@!\|\\$\)\zs'
        \ : shiftwidth(),
        \ s:front. '\<\%(for\|select\)\s\+\h\w*\s\+do\zs\s*\%(\s#.*\)\=$'
        \ : shiftwidth(),
        \ '\<case\s.*\sin\zs\%(\s\+#.*\|\s*\)$'
        \ : (g:sh_indent_case_labels ? shiftwidth() : 0),
        \ s:front. '\<foreach\>\%(.*[;)}]\s*\%(end\|done\)\>\)\@!'.s:rear2.'\zs'
        \ : (s:IsFtZsh() ? shiftwidth() : 0),
        \ '[;&)}]\s*\%(fi\|done\)\>\%(\s*[)}]\)\@!\zs'
        \ : shiftwidth() * -1,
        \ '\%(\<case\s.*\sin\>.*\)\@<!;[;&|]\s*esac\>\%(\s*[)}]\)\@!\zs'
        \ : (g:sh_indent_case_labels ? shiftwidth() * -2: shiftwidth() * -1)
        \ }
endfunction

function s:SetZshSubstString()
  syn cluster zshSubst       add=zshSubstString
  syn region  zshSubstString matchgroup=zshSubstDelim start='\${' end='}'
        \ contains=@zshSubst,zshBrackets,zshQuoted,zshString fold
  hi def link zshSubstString zshSubst
  let b:sh_indent_synhi = 1
endfunction

let s:rear1 = '\%(\\\=$\|\s\|;\|&\||\|<\|>\|)\|}\|`\)'
let s:rear2 = '\%(\\\=$\|\s\|(\)'
let s:noesc = '\\\@1<!\%(\\\\\)*'
let s:front = '\%(^\|'. s:noesc. ';\)\s*\%(then\s\|do\s\|else\s\)\='
let s:front = '\%('. s:front.  '\|'. s:noesc. '\%((\|`\|{\s\)\)\s*'

let s:quote = '\c'. 'string$\|...quote$\|^shderef$'
let s:hered = '\c'. 'heredoc$'
let s:comnt = '\c'. 'comment$'
let s:subst = '\c'. '^zsh\%(old\)\=subst$\|commandsub'

let &cpo = s:cpo_save
unlet s:cpo_save

" vim: set sts=2 sw=2 expandtab:
