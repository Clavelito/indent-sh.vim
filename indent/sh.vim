" Vim indent file
" Language:         Shell Script
" Author:           Clavelito <maromomo@hotmail.com>
" Last Change:      Sun, 10 Mar 2019 20:16:20 +0900
" Version:          5.7


if exists("b:did_indent")
  finish
endif
let b:did_indent = 1

setlocal indentexpr=GetShIndent()
setlocal indentkeys+=0=then,0=do,0=elif,0=fi,0=esac,0=done,0=end,0),0<!>,0(
setlocal indentkeys-=:,0#

let b:undo_indent = 'setlocal indentexpr< indentkeys<'

if !exists("g:sh_indent_case_labels")
  let g:sh_indent_case_labels = 1
endif

if exists("*GetShIndent")
  finish
endif

let s:cpo_save = &cpo
set cpo&vim

function GetShIndent()
  let lnum = prevnonblank(v:lnum - 1)
  let cline = getline(v:lnum)
  if lnum == 0 || cline =~# '^#'
    return 0
  endif
  if exists("b:sh_indent_tabstop")
    let &tabstop = b:sh_indent_tabstop
    unlet b:sh_indent_tabstop
  endif
  if exists("b:sh_indent_indentkeys")
    let &indentkeys = b:sh_indent_indentkeys
    unlet b:sh_indent_indentkeys
  endif
  let line = getline(lnum)
  if s:IsQuote(lnum, line, 1)
    unlet! s:TbSum
    return indent(v:lnum)
  elseif s:IsHereDoc(lnum, line)
    return s:HereDocIndent(cline)
  else
    unlet! s:TbSum
  endif
  let [line, lnum] = s:SkipCommentLine(lnum, line)
  let [pline, pnum] = s:SkipCommentLine(lnum)
  let ind = s:PrevLineIndent(line, lnum, pline, pnum)
  let ind = s:CurrentLineIndent(cline, line, lnum, ind)
  return ind
endfunction

function s:PrevLineIndent(line, lnum, pline, pnum)
  let ind = indent(a:lnum)
  if s:IsBackSlash(a:pline, a:pnum) && s:IsBackSlash(a:line, a:lnum)
        \ || (s:IsCase(a:pline, a:pnum) || s:IsCaseBreak(a:pline, a:pnum))
        \ && !s:IsEsac(a:line)
    let s:CsInd = 0
  else
    let ind = s:ControlStatementIndent(a:line, a:lnum, ind)
  endif
  if !s:IsHereDoc(a:lnum, 1) && s:IsHereDoc(a:pnum, 1)
    let ind = s:ContinueLineIndent(a:line, a:lnum, s:hered)
  elseif s:IsCase(a:pline, a:pnum) || s:IsCaseBreak(a:pline, a:pnum)
    let ind = s:CaseLabelIndent(a:line, a:lnum, ind)
  elseif a:line =~# ')\|`' && s:IsSubSt(a:lnum, 1) && !s:IsSubSt(v:lnum, 1)
        \ && !s:IsBackSlash(a:line, a:lnum)
    let ind = s:ContinueLineIndent(a:line, a:lnum, s:subst)
  elseif a:line =~# '"\|\%o47' && s:IsQuote(a:pnum, a:pline)
    let ind = s:ContinueLineIndent(a:line, a:lnum, s:quote)
  elseif a:line =~# ')\|`' && s:IsSubSt(v:lnum, 1)
        \ && s:SubstCount(a:lnum, 1) > s:SubstCount(v:lnum, 1)
    let ind = s:InsideSubStIndent(a:lnum)
  elseif (s:IsBackSlash(a:line, a:lnum) && a:lnum == v:lnum - 1
        \ || s:IsBackSlash(a:line, a:lnum) && a:lnum != v:lnum - 1
        \ && s:IsContinue(a:line, a:lnum))
        \ && (!s:IsBackSlash(a:pline, a:pnum) || a:pnum != a:lnum - 1)
    let ind = s:BaseLevelIndent(a:pline, a:pnum, a:lnum, ind, 1)
  elseif s:IsBackSlash(a:line, a:lnum) && a:lnum != v:lnum - 1
        \ && !s:IsContinue(a:line, a:lnum)
    let ind = s:BaseLevelIndent(a:line, a:lnum, v:lnum, ind)
  elseif a:line =~# '\$(\|`' && s:IsSubSt(v:lnum, 1)
        \ && s:SubstCount(a:lnum, 1) < s:SubstCount(a:lnum, a:line)
    let ind = s:OpenSubStIndent(a:pline, a:pnum, a:lnum, ind)
  elseif s:IsOpenBrace(a:line, a:lnum) || s:IsOpenParen(a:line, a:lnum)
    let ind = indent(s:SkipContinue(a:pline, a:pnum, a:lnum)) + shiftwidth()
  elseif !s:IsContinueNorm(a:line, a:lnum) && !s:IsBackSlash(a:line, a:lnum)
        \ && (s:IsContinue(a:pline, a:pnum) || s:IsBackSlash(a:pline, a:pnum))
    let ind = s:ContinueLineIndent(a:line, a:lnum, a:pline, a:pnum)
  endif
  if s:IsCloseBrace(a:line, a:lnum)
        \ && !s:IsBackSlash(a:line, a:lnum) && !s:IsContinue(a:line, a:lnum)
        \ && !s:IsOpenBrace(a:line, a:lnum) && !s:IsOpenParen(a:line, a:lnum)
    let ind = s:CloseTailBraceIndent(a:lnum, ind)
  elseif s:IsCloseDoubleParen(a:line, a:lnum) && &ft !=# 'zsh'
        \ && !s:IsBackSlash(a:line, a:lnum) && !s:IsContinue(a:line, a:lnum)
    let ind = s:CloseTailParenIndent(a:lnum, ind)
  endif
  if s:IsCaseBreak(a:line, a:lnum)
    let ind -= shiftwidth()
  elseif s:IsDoThen(a:line, a:lnum) && !s:CsInd
    let ind += shiftwidth()
  endif
  return ind
endfunction

function s:CurrentLineIndent(cline, line, lnum, ind)
  let ind = a:ind
  if s:IsEsac(a:cline) && !s:IsCaseBreak(a:line, a:lnum)
    let ind -= g:sh_indent_case_labels ? shiftwidth() * 2 : shiftwidth()
  elseif s:IsEsac(a:cline) && g:sh_indent_case_labels
        \ || a:cline =~# '^\s*\%(fi\|done\)\>'. s:rear1
        \ || a:cline =~# '^\s*\%(else\|elif\)\>'. s:rear2
        \ || a:cline =~# '^\s*end\>'. s:rear1 && &ft ==# 'zsh'
        \ || a:cline =~# '^\s*\%(then\|do\)\>'. s:rear2 && s:CsInd > 0
        \ || a:cline =~# '^\s*}'
    let ind -= shiftwidth()
  elseif a:cline =~# '^\s*)'
    let ind = s:CloseHeadParenIndent(a:cline, ind)
  elseif a:cline =~# '^\s*!$' && s:IsContinue(a:line, a:lnum)
    call s:OvrdIndentKeys("{,(")
  elseif (a:cline =~# '^\s*\%(!\s\+\)\={' && !s:IsCloseBrace(a:cline, v:lnum)
        \ || a:cline =~# '^\s*\%(!\s*\)\=(' && !s:IsCloseParen(a:cline, v:lnum))
        \ && s:IsContinue(a:line, a:lnum)
    call s:OvrdIndentKeys("},)")
    let ind = indent(s:SkipContinue(a:line, a:lnum, v:lnum))
  endif
  if a:cline =~# '^\s*[deft]' && ind < indent(v:lnum)
    call s:OvrdIndentKeys()
  endif
  unlet s:CsInd
  return ind
endfunction

function s:ControlStatementIndent(line, lnum, ind)
  let ind = a:ind
  let ptdic = s:PtDic()
  if a:line =~# '^\s*\%(then\|else\)\>\%(.*;\s*fi\>\)\@!'. s:rear2
        \ || a:line =~# '^\s*do\>\%(.*;\s*done\>\)\@!'. s:rear2
    let ind += shiftwidth()
  endif
  if a:line =~# '^\s*elif\>\%(.*;\s*fi\>\)\@!'
    let ind += shiftwidth()
  elseif max(map(keys(ptdic), 'a:line =~# v:val'))
    for key in keys(ptdic)
      let line = ""
      for str in split(a:line, key)
        let line .= str
        if str =~# key && !s:IsInside(a:lnum, line)
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
  while s:GetPrevNonBlank(lnum) && line =~# '^\s*#' && !s:IsHereDoc(s:PLnum, 1)
    let lnum = s:PLnum
    let line = getline(lnum)
  endwhile
  unlet s:PLnum
  return [line, lnum]
endfunction

function s:SkipContinue(line, lnum, onum, ...)
  let [line, lnum] = s:SkipCommentLine(a:lnum, a:line)
  let onum = a:onum
  while lnum && (s:IsContinue(line, lnum) || s:IsBackSlash(line, lnum))
    if s:IsQuote(lnum, 1)
      let lnum = s:SkipItemLine(lnum, s:quote)
    endif
    if s:IsSubSt(lnum, 1)
      let lnum = s:SkipItemLine(lnum, s:subst)
    endif
    let onum = lnum
    let lnum = s:GetPrevNonBlank(lnum)
    let line = getline(lnum)
    let [line, lnum] = s:SkipCommentLine(lnum, line)
  endwhile
  unlet! s:PLnum
  return a:0 ? [line, lnum, onum] : onum
endfunction

function s:SkipItemLine(lnum, item)
  let lnum = a:lnum
  let root = s:IsSubSt(v:lnum, 1)
  while s:GetPrevNonBlank(lnum)
        \ && (s:MatchSyntaxItem(lnum, 1, a:item, root)
        \ || s:MatchSyntaxItem(s:PLnum, getline(s:PLnum), a:item, root))
    let lnum = s:PLnum
  endwhile
  if s:GetPrevNonBlank(lnum)
    let lnum = s:SkipContinue(getline(s:PLnum), s:PLnum, lnum)
  endif
  unlet s:PLnum
  return lnum
endfunction

function s:CaseLabelIndent(line, lnum, ind)
  let ind = a:ind
  if !s:IsBackSlash(a:line, a:lnum) && !s:IsEsac(a:line)
    let ind += shiftwidth()
    let pos = s:IsOutside(a:line, a:lnum, s:noesc. ")")
    let line = strpart(a:line, pos)
    while pos
      let line = " ". line
      let pos -= 1
    endwhile
    let ind = s:ControlStatementIndent(line, a:lnum, ind)
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
    let onum = s:SkipItemLine(a:lnum, a:1)
    let [line, lnum] = s:SkipCommentLine(onum)
  else
    let [line, lnum, onum] = s:SkipContinue(a:1, a:2, a:line, 1)
  endif
  let ind = indent(onum)
  let oline = getline(onum)
  if s:SubstCount(onum, 1) < s:SubstCount(v:lnum, 1)
    let ind += shiftwidth() * (s:SubstCount(v:lnum, 1) - s:SubstCount(onum, 1))
  elseif (s:IsCase(line, lnum) || s:IsCaseBreak(line, lnum)) && !s:IsEsac(oline)
    let ind = s:CaseLabelIndent(a:line, a:lnum, ind)
  elseif !s:IsCase(line, lnum) && !s:IsCaseBreak(line, lnum)
        \ && s:IsBackSlash(a:line, a:lnum)
    let ind += shiftwidth()
  elseif oline =~# '^\s*\%(if\|elif\|while\|until\|foreach\)\>'
    let ind = s:ControlStatementIndent(oline, onum, ind)
  elseif s:CsInd
    let ind += s:CsInd
  endif
  return ind
endfunction

function s:CloseHeadParenIndent(line, ind)
  let ind = a:ind
  let expr = 's:IsInside(line("."),col("."))'
  let pos = getpos(".")
  if strpart(a:line, col(".") - 1, 1) ==# ")"
    call search('.\n\=)', "bW")
  else
    call cursor(0, 1)
  endif
  let s:root = s:IsSubSt(line("."), col("."))
  let lnum = searchpair(s:noesc. "(", "", s:noesc. ")", "bW", expr)
  unlet s:root
  if lnum > 0
    let sum = 0
    let lcol = col(".")
    while search(s:noesc. '(\%(\s*)\)\@!', "bW", lnum)
      if eval(expr)
        continue
      elseif col(".") == lcol - 1
        let lcol = 0
      else
        let lcol = col(".")
        let sum += 1
      endif
    endwhile
    let sum = s:IfStartInCaseLabel(lnum, sum)
    let ind = indent(lnum) + sum * shiftwidth()
  endif
  call setpos(".", pos)
  return ind
endfunction

function s:CloseTailBraceIndent(lnum, ind)
  let item = [
        \ '\<\%(if\|elif\|while\|until\)\s\+\%(!\s\+\)\=\zs{'
        \. '\|\%({\s\+\)\@<={\|\%(&&\|||\=\)\s*\%(!\s\)\=\s*\zs{'
        \. '\|'. s:front. '\%(!\s\)\=\s*\zs{',
        \ '\%(}\s\+\)\@<=}\|\%(^\|;\s*\%(done\|fi\|esac\)\=\)\s*\zs}',
        \ '\%(}\s\+\)\@<=}\|;\s*\%(done\|fi\|esac\)\=\s*\zs}' ]
  return s:CloseTailIndent(a:lnum, a:ind, item)
endfunction

function s:CloseTailParenIndent(lnum, ind)
  let item = [ '((', '))', '\%(^\s*\)\@<!))' ]
  return s:CloseTailIndent(a:lnum, a:ind, item)
endfunction

function s:CloseTailIndent(lnum, ind, item)
  let ind = a:ind
  let [pt1, pt2, pt3] = a:item
  let expr = 's:IsInside(line("."),col("."))'
  let pos = getpos(".")
  call cursor(0, 1)
  while search(pt3, "bW", a:lnum)
    if eval(expr)
      continue
    else
      break
    endif
  endwhile
  let lnum = searchpair(pt1, "", pt2, "nbW", expr)
  if lnum > 0 && lnum != a:lnum && indent(lnum) < indent(a:lnum)
    let ind = searchpair(pt1, "", pt2, "rmbW", expr, lnum) - 1
    let ind = s:IfStartInCaseLabel(lnum, ind)
    let ind = indent(lnum) + ind * shiftwidth() + s:CsInd
  endif
  call setpos(".", pos)
  return ind
endfunction

function s:IfStartInCaseLabel(lnum, sum)
  let [line, lnum] = s:SkipCommentLine(a:lnum)
  return s:IsCase(line, lnum) || s:IsCaseBreak(line, lnum) ? a:sum + 1 : a:sum
endfunction

function s:SkipHereDocLine()
  let pos = getpos(".")
  while search('<\@<!<<<\@!-\=', "bW") && s:IsHereDoc(line("."), 1)
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
    let ind = indent(v:lnum)
    unlet! s:TbSum
  endif
  if !&expandtab && oline =~# '<<-' && strlen(a:cline) && a:cline !~# '^\s\+$'
    let sttab = ind / &tabstop
    let tbind = a:cline =~# '^\t' ? matchend(a:cline, '\t*', 0) : 0
    let spind = s:IsHereDoc(v:lnum, 1)
          \ ? strdisplaywidth(matchstr(a:cline, '\s*', tbind), ind) : 0
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
    let ind = &autoindent ? indent(v:lnum) : ind
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
  let b:sh_indent_indentkeys = &indentkeys
  if a:0
    exec 'setlocal indentkeys+='. a:1
  else
    setlocal indentkeys+=a,b,c,d,<e>,f,g,h,i,j,k,l,m,n,<o>,p,q,r,s,t,u,v,w,x,y,z
    setlocal indentkeys+=A,B,C,D,E,F,G,H,I,J,K,L,M,N,<O>,P,Q,R,S,T,U,V,W,X,Y,Z
    setlocal indentkeys+=1,2,3,4,5,6,7,8,9,<0>,_,-,=,+,.,<Space>
  endif
endfunction

function s:IsOutside(l, n, pt)
  let pos = 0
  while pos > -1
    let pos = matchend(a:l, a:pt, pos)
    if pos > -1 && !s:IsInside(a:n, pos)
      return pos
    endif
  endwhile
  return 0
endfunction

function s:IsInside(n, p)
  return s:IsQuote(a:n, a:p) || s:IsComment(a:n, a:p) || s:IsHereDoc(a:n, a:p)
endfunction

function s:IsOpenBrace(l, n)
  let pt = '\%(^\|;\|&&\|||\=\)\s*\%(!\s\)\=\s*{\ze\s*\%(#.*\)\=$'
        \. '\|^\s*\%(\h\w*\|\S\+\)\s*()\s*{\ze\s*\%(#.*\)\=$'
        \. '\|^\s*function\s\+\S\+\%(\s*()\)\=\s*{\ze\s*\%(#.*\)\=$'
  return s:IsOutside(a:l, a:n, pt)
endfunction

function s:IsOpenParen(l, n)
  let pt = s:noesc. '(\ze\s*\%(#.*\)\=$'
  return s:IsOutside(a:l, a:n, pt)
endfunction

function s:IsCloseBrace(l, n)
  let pt = '\%(}\s\+\)\@<=}\|;\s*\%(done\|fi\|esac\)\=\s*\zs}'
  return s:IsOutside(a:l, a:n, pt)
endfunction

function s:IsCloseParen(l, n)
  return s:IsOutside(a:l, a:n, '\%(^\s*\)\@<!))\@!')
endfunction

function s:IsCloseDoubleParen(l, n)
  return s:IsOutside(a:l, a:n, '\%(^\s*\)\@<!))')
endfunction

function s:IsCase(l, n)
  let pt = s:front. '\<case\>\%(.*;;\s*\<esac\>\)\@!'
  return s:IsOutside(a:l, a:n, pt)
endfunction

function s:IsCaseBreak(l, n)
  let pt = ';[;&]\%(.*\<esac\>\)\@!'
  return s:IsOutside(a:l, a:n, pt)
endfunction

function s:IsEsac(l)
  return a:l =~# '^\s*esac\>'. s:rear1
endfunction

function s:IsBackSlash(l, n)
  return a:l =~# s:noesc. '\\$' && !s:IsComment(a:n, a:l)
endfunction

function s:IsContinueNorm(l, n)
  let pt = '.\ze\%(&&\|||\)\s*\%(#.*\|\\\)\=$'
  return s:IsOutside(a:l, a:n, pt)
endfunction

function s:IsContinue(l, n)
  let pt1 = '.\ze\%(&&\|||\=\)\s*\%(#.*\|\\\)\=$'
  let pt2 = '^\s*\%(if\|elif\|while\|until\)\>\s*\%(#.*\|\\\)\=$'
  return s:IsOutside(a:l, a:n, pt1) || a:l =~# pt2
endfunction

function s:IsDoThen(l, n)
  let pt = '\%('. s:front. '\<\%(if\|elif\)\>.*\)\@<!'
        \. ';\s*then\>\%(.*;\s*fi\>\)\@!'
        \. '\|\%('. s:front. '\<\%(while\|until\|for\|select\)\>.*\)\@<!'
        \. ';\s*do\>\%(.*;\s*done\>\)\@!'
  return s:IsOutside(a:l, a:n, pt)
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

function s:IsQuote(n, p, ...)
  return s:MatchSyntaxItem(a:n, a:p, a:0 ? s:noret : s:quote,
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
        \ s:front. '\<if\>\%(.*;\s*fi\>\)\@!\zs'
        \ : shiftwidth(),
        \ s:front. '\<\%(while\|until\|for\|select\)\>\%(.*;\s*done\>\)\@!\zs'
        \ : shiftwidth(),
        \ s:front. '\<case\>\%(.*;;\s*esac\>\)\@!\zs'
        \ : (g:sh_indent_case_labels ? shiftwidth() : 0),
        \ s:front. '\<foreach\>\%(.*;\s*end\>\)\@!\zs'
        \ : (&ft ==# 'zsh' ? shiftwidth() : 0),
        \ '\%(\<then\>.*\|\<else\>.*\)\@<!;\s*fi\>\%(\s*[)}]\)\@!\zs'
        \ : shiftwidth() * -1,
        \ '\%(\<do\>.*\)\@<!;\s*done\>\%(\s*[)}]\)\@!\zs'
        \ : shiftwidth() * -1,
        \ '\%(\<case\>.*\)\@<!;;\s*esac\>\%(\s*[)}]\)\@!\zs'
        \ : (g:sh_indent_case_labels ? shiftwidth() * -2 : shiftwidth() * -1)
        \ }
endfunction

let s:front = '\%(\%(^\|;\)\s*\%(then\s\|do\s\|else\s\)\=\|)\|(\|`\)\s*'
let s:rear1 = '\%(\\\=$\|\s\|;\|&\||\|<\|>\|)\|}\|`\)'
let s:rear2 = '\%(\\\=$\|\s\|(\)'
let s:noesc = '\\\@<!\%(\\\\\)*'

let s:noret = '\c'. 'string$\|\%(test.*\)\@<!.....quote$'
let s:quote = '\c'. 'string$\|...quote$'
let s:hered = '\c'. 'heredoc$'
let s:comnt = '\c'. 'comment$'
let s:subst = '\c'. 'subst$\|commandsub'

let &cpo = s:cpo_save
unlet s:cpo_save

" vim: set sts=2 sw=2 expandtab:
