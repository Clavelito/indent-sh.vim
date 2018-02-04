" Vim indent file
" Language:         Shell Script
" Maintainer:       Clavelito <maromomo@hotmail.com>
" Last Change:      Sun, 04 Feb 2018 18:06:57 +0900
" Version:          4.61
"
" Description:
"                   let g:sh_indent_case_labels = 0
"                            case $a in
"                            label)
"
"                   let g:sh_indent_case_labels = 1
"                            case $a in
"                                label)
"                                                    (default: 1)
"
"                   let g:sh_indent_and_or_or = 0
"                            foo &&
"                            bar
"
"                   let g:sh_indent_and_or_or = 1
"                            foo &&
"                                bar
"                                                    (default: 1)
"
"                   let g:sh_indent_tail_bar = 0
"                            echo foo |
"                            tr 'f' 'c'
"
"                   let g:sh_indent_tail_bar = 1
"                            echo foo |
"                                tr 'f' 'c'
"                                                    (default: 1)


if exists("b:did_indent") || !exists("g:syntax_on")
  finish
endif
let b:did_indent = 1

setlocal indentexpr=GetShIndent()
setlocal indentkeys=0},0{,0),0(,!^F,o,O
setlocal indentkeys+=0=then,0=do,0=else,0=elif,0=fi,0=esac,0=done,0=;;,0=;&

let b:undo_indent = 'setlocal indentexpr< indentkeys<'

if exists("*GetShIndent")
  finish
endif

let s:cpo_save = &cpo
set cpo&vim

let s:back_quote = 'CommandSub'
let s:sh_comment = 'Comment\|Todo'
let s:test_d_or_s_quote = 'TestDoubleQuote\|TestSingleQuote'
let s:d_or_s_quote = 'DoubleQuote\|SingleQuote\|DblQuote\|SnglQuote'
let s:sh_quote = 'shQuote'
let s:sh_here_doc = 'HereDoc'
let s:sh_here_doc_eof = 'HereDoc\d\d\|shRedir\d\d'
let s:sh_echo = 'Echo'

if !exists("g:sh_indent_case_labels")
  let g:sh_indent_case_labels = 1
endif
if !exists("g:sh_indent_and_or_or")
  let g:sh_indent_and_or_or = 1
endif
if !exists("g:sh_indent_tail_bar")
  let g:sh_indent_tail_bar = 1
endif

function GetShIndent()
  let lnum = prevnonblank(v:lnum - 1)
  if lnum == 0
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

  let cline = getline(v:lnum)
  let line = getline(lnum)

  if cline =~# '^#'
    return 0
  endif

  for cid in reverse(synstack(lnum, strlen(line)))
    let cname = synIDattr(cid, 'name')
    if cname =~? s:sh_here_doc. '$'
      let lnum = s:SkipItemsLines(v:lnum, s:sh_here_doc.'\|'. s:sh_here_doc_eof)
      let ind = s:InsideHereDocIndent(lnum, cline)
      return ind
    elseif cname =~? s:test_d_or_s_quote
          \ && s:EndOfTestQuotes(line, lnum, s:test_d_or_s_quote)
      break
    elseif cname =~? s:d_or_s_quote
      return indent(v:lnum)
    endif
  endfor

  let [line, lnum] = s:SkipCommentLine(line, lnum, 0)
  let line = s:BlankOrContinue(line, lnum, v:lnum - 1)
  let ind = s:BackQuoteIndent(lnum, 0)
  let [line, lnum, ind] = s:GetSkipItemLinesHeadAndTail(line, lnum, ind)
  let ind = indent(lnum) + ind
  let line = s:HideAnyItemLine(line)
  let [pline, pnum] = s:SkipCommentLine(line, lnum, 1)
  let pline = s:BlankOrContinue(pline, pnum, lnum - 1)
  let [rpline, pline, pnum] = s:PreMorePrevLine(pline, pnum)
  let [pline, ind] = s:MorePrevLineIndent(pline, pnum, line, lnum, ind)
  let [line, ind] = s:InsideCaseLabelIndent(pline, line, ind)
  let ind = s:PrevLineIndent(line, lnum, pline, rpline, ind)
  let ind = s:CurrentLineIndent(line, lnum, cline, pline, ind)

  return ind
endfunction

function s:MorePrevLineIndent(pline, pnum, line, lnum, ind)
  let ind = a:ind
  let pline = a:pline
  let line = a:line
  if s:IsTailBackSlash(a:pline)
        \ && (s:IsTailBar(a:pline) || a:line =~# '^\s*|[^|]')
    let pline = s:GetPrevContinueLine(a:pline, a:pnum)
  endif
  if !s:IsInSideCase(pline) && s:IsTailNoContinue(line)
    let line = s:HideTailBackSlash(line)
  endif
  if (!s:IsTailBackSlash(a:pline) && s:IsTailBackSlash(line)
        \ && !g:sh_indent_and_or_or
        \ || !s:IsContinuLineFore(a:pline) && s:IsContinuLineFore(line)
        \ && g:sh_indent_and_or_or
        \ || !s:IsContinuLinePrev(a:pline) && s:IsTailBar(a:line)
        \ && g:sh_indent_tail_bar)
        \ && (!s:IsInSideCase(pline) || a:line =~# '^\s*esac\>')
        \ && s:GetLessIndentLineIndent(a:lnum, ind, 0) == ind
    let ind = ind + shiftwidth()
  elseif (s:IsTailAndOr(a:pline) && !s:IsContinuLineFore(line)
        \ && !s:IsTailBar(a:line) && !s:IsFunctionLine(line)
        \ && s:PairBalance(line, "{", "}") <= 0
        \ && s:PairBalance(line, "(", ")") <= 0
        \ || (s:IsTailBar(a:pline) && !s:IsContinuLineFore(line)
        \ && !s:IsTailBar(a:line)
        \ || s:IsTailBackSlash(a:pline) && s:IsTailBar(a:line)
        \ && !g:sh_indent_tail_bar)
        \ && !s:IsInSideCase(pline))
        \ && !s:IsExprLineHead(line)
        \ || (s:IsTailBackSlash(a:pline) && !s:IsContinuLineFore(line)
        \ && !s:IsTailBar(a:line) && g:sh_indent_and_or_or
        \ || s:IsTailBackSlash(a:pline) && !s:IsTailBackSlash(line)
        \ && !s:IsTailBar(a:line) && !g:sh_indent_and_or_or)
        \ && !s:IsTailNoContinue(a:pline) && !s:IsTailBar(a:pline)
    let ind = s:GetLessIndentLineIndent(a:lnum, ind, 1)
  endif

  return [pline, ind]
endfunction

function s:InsideCaseLabelIndent(pline, line, ind)
  let ind = a:ind
  let line = a:line
  if line =~# ')' && a:line !~# '^\s*case\>' && s:IsInSideCase(a:pline)
    let [line, ind] = s:CaseLabelLineIndent(line, ind)
  elseif line =~# ';[;&]\s*$' && a:line !~# '^\s*case\>\%(.\{-}\<esac\>\)\@!'
    let ind = s:CaseBreakIndent(ind)
  elseif s:IsTailBackSlash(a:line) && s:IsInSideCase(a:pline)
    let line = ""
  endif

  return [line, ind]
endfunction

function s:PrevLineIndent(line, lnum, pline, rpline, ind)
  let line2 = getline(a:lnum)
  let [line, ind] = s:GetFunctionIndent(a:line, a:ind)
  let line = s:HideAnyItemLine2(line)
  let ind = s:PrevLineIndent0(a:pline, line, a:lnum, a:rpline, ind)
  let ind = s:ParenBraceIndent(line, a:lnum, ind)
  let ind = s:CloseParenIndent(a:pline, line2, line, a:lnum, a:rpline, ind)
  let ind = s:CloseBraceIndent(a:pline, line2, line, a:lnum, a:rpline, ind)

  return ind
endfunction

function s:PrevLineIndent0(pline, line, lnum, rpline, ind)
  if !s:IsHeadAndBarOr(a:line) && s:IsTailBackSlash2(a:rpline)
    return a:ind
  endif
  let ind = a:ind
  let pt1 = '\C\%(\%(if\|elif\|while\|until\)\s\+\)\=\%([!]\s\+\)\=\zs{\ze'
  if a:line =~# '[|`(;&]\|\%(\%(^\|;\|&\||\)\s*\|\%(do\|then\|else\)\s\+\)'. pt1
    let s:case_count = 0
    let sum = 0
    for str in split(a:line, '[|`(;&]\|^\s*'. pt1)
      let ind = s:PrevLineIndent3(str, ind, sum)
      let sum += 1
    endfor
    if str =~# '^\s*\%(then\|do\)\>' && s:IsInSideCase(a:pline) && ind == a:ind
      let ind = s:CaseLabelNextIndent(ind) + shiftwidth()
    endif
    if a:line =~# ';[;&]\s*$' && !s:case_count
      let ind = a:ind
    endif
    unlet s:case_count
  else
    let ind = s:PrevLineIndent2(a:line, ind)
  endif
  if a:line =~# '^\s*\%(fi\|done\|esac\)\>'
        \ && !s:IsContinuLinePrev(a:line) && !s:IsContinuLinePrev(a:rpline)
    let ind = s:GetLessIndentLineIndent(a:lnum, ind, 0)
  endif

  return ind
endfunction

function s:PrevLineIndent2(line, ind)
  let ind = a:ind
  let line = a:line
  if line =~# '^\s*\%(then\|do\|else\)\>\s\+\S'
    let ind = ind + shiftwidth()
    let line = substitute(line, '^\s*\S\+\s\+', '', '')
  endif
  if line =~# '^\s*\%(if\|then\|else\|elif\)\>'
        \ || line =~# '^\s*\%(do\|while\|until\|for\|select\)\>'
    let ind = ind + shiftwidth()
  elseif line =~# '^\s*case\>'
    let ind = ind + s:IndentCaseLabels()
  endif

  return ind
endfunction

function s:PrevLineIndent3(line, ind, sum)
  let ind = a:ind
  let line = a:line
  if line =~# '^\s*\%(then\|do\|else\)\>\s*$\|^\s*elif\>' && !a:sum
    let ind = ind + shiftwidth()
  elseif line =~# '^\s*\%(then\|do\|else\)\>\s\+\S' && !a:sum
    let ind = ind + shiftwidth()
    let line = substitute(line, '^\s*\S\+\s\+', '', '')
  elseif line =~# '^\s*\%(then\|do\|else\)\>\s\+\S' && a:sum
    let line = substitute(line, '^\s*\S\+\s\+', '', '')
  endif
  if line =~# '^\s*\%(if\|while\|until\|for\|select\)\>'
    let ind = ind + shiftwidth()
  elseif line =~# '^\s*\%(done\|fi\)\>' && a:sum
    let ind = ind - shiftwidth()
  elseif line =~# '^\s*case\>'
    let s:case_count += 1
    let ind = ind + s:IndentCaseLabels()
  elseif line =~# '^\s*esac\>' && a:sum && s:case_count
    let s:case_count -= 1
    let ind = ind - s:IndentCaseLabels()
  elseif line =~# '^\s*esac\>' && a:sum
    let ind = s:CaseBreakIndent(ind) - s:IndentCaseLabels()
  endif

  return ind
endfunction

function s:CurrentLineIndent(line, lnum, cline, pline, ind)
  if a:cline =~# '^\s*;[;&]'
    return s:CaseBreakIndent(a:ind) + shiftwidth()
  elseif s:IsTailBackSlash2(a:line)
    return a:ind
  endif
  let ind = a:ind
  if a:cline =~# '^\s*esac\>' && a:line !~# ';[;&]\s*$'
    let ind = s:CaseBreakIndent(ind)
  elseif a:cline =~# '^\s*\%(then\|do\)\>[-=+.]\@!' && s:IsInSideCase(a:pline)
    let ind = s:CaseLabelNextIndent(ind) + shiftwidth()
  endif
  if a:cline =~# '^\s*\%(then\|do\|else\|elif\|fi\|done\)\>[-=+.]\@!'
        \ || a:cline =~# '^\s*[})]' && !s:IsInSideCase(a:line)
    let ind = ind - shiftwidth()
  elseif a:cline =~# '^\s*[{(]\s*\%(#.*\)\=$'
        \ && (s:IsTailAndOr(a:line) || s:IsTailBar(a:line))
        \ && !s:IsInSideCase(a:pline)
    let ind = indent(a:lnum)
  elseif a:cline =~# '^\s*esac\>'
    let ind = ind - s:IndentCaseLabels()
  endif
  if ind != a:ind
        \ && a:cline =~# '^\s*\%(then\|do\|else\|elif\|fi\|done\|esac\|[{(]\)$'
    call s:OvrdIndentKeys(a:cline)
  endif

  return ind
endfunction

function s:CloseParenIndent(pline, line, nline, lnum, rpline, ind)
  let ind = a:ind
  if a:nline =~# ')' && a:nline !~# '^\s*case\>'
        \ && a:nline !~# ';[;&]\s*$' && !s:IsInSideCase(a:pline)
    if a:line =~# '^\s*)'
      let ind = ind + shiftwidth()
    endif
    let ind = ind - shiftwidth() * (len(split(a:nline, ')', 1)) - 1)
    if !s:IsContinuLinePrev(a:nline) && !s:IsContinuLinePrev(a:rpline)
      let ind = s:GetLessIndentLineIndent(a:lnum, ind, 0)
    endif
  endif

  return ind
endfunction

function s:CloseBraceIndent(pline, line, nline, lnum, rpline, ind)
  let ind = a:ind
  let pt1 = '\%(^\|\%(\${[^}]\+\)\@<![;&]\)'
        \. '\%(\C\s*\%(done\|fi\|esac\)\)\=\s*}\|^\s\+}'
  if a:nline =~# pt1 && a:nline !~# ';[;&]\s*$'
        \ && !s:MatchSynId(a:lnum, 1, s:sh_echo)
    if a:line =~# '^\s*}' && !s:IsInSideCase(a:pline)
      let ind = ind + shiftwidth()
    endif
    let ind = ind - shiftwidth() * (len(split(a:nline, pt1, 1)) - 1)
    if !s:IsContinuLinePrev(a:nline) && !s:IsContinuLinePrev(a:rpline)
      let ind = s:GetLessIndentLineIndent(a:lnum, ind, 0)
    endif
  endif

  return ind
endfunction

function s:ParenBraceIndent(line, lnum, ind)
  let ind = a:ind
  let pt1 = '\%(\%(^\|;\|&\||\)\s*\|\%(do\|then\|else\)\s\+\)'
        \. '\C\%(\%(if\|elif\|while\|until\)\s\+\)\=\%([!]\s\+\)\={'
  if a:line =~# '('
    let ind = ind + shiftwidth() * (len(split(a:line, '(', 1)) - 1)
  endif
  if a:line =~# pt1
        \ && a:line !~# ';[;&]\s*$' && !s:MatchSynId(a:lnum, 1, s:sh_echo)
    let ind = ind + shiftwidth() * (len(split(a:line, pt1, 1)) - 1)
  endif

  return ind
endfunction

function s:GetLessIndentLineIndent(lnum, ind, more)
  if !a:ind
    return 0
  endif
  let lnum = a:lnum
  let ind = a:ind
  while s:GetPrevNonBlank(lnum)
    let last_ind = ind
    let lnum = s:prev_lnum
    if !a:more && indent(lnum) >= ind
      continue
    endif
    let [line, lnum] = s:SkipCommentLine(getline(lnum), lnum, 0)
    let [line, lnum, ind] = s:GetSkipItemLinesHeadAndTail(line, lnum, ind)
    let cind = indent(lnum)
    if cind == ind
          \ && !s:IsContinuLinePrev(line)
          \ && (s:IsExprLineTail(line)
          \ || !s:IsFunctionLine(line) && !s:IsExprLineHead(line)
          \ && !s:IsHeadAndBarOr(line)
          \ && line !~# '^\s*\%(do\|then\|elif\|else\)\>'
          \ && s:ParenBraceBalanced(line, 1))
      break
    elseif cind < ind && s:IsContinuLinePrev(line) && s:IsExprLineTail(line)
      let ind = cind
    elseif cind < ind && !s:IsContinuLinePrev(line) && s:IsHeadAndBarOr(line)
      continue
    elseif s:IsContinuLinePrev(line)
      let [line, lnum, ind] = s:GetContinueLineIndent(line, lnum, 1)
    endif
    if ind > last_ind
      let ind = last_ind
    endif
    if !ind || !cind || cind < ind
      break
    endif
  endwhile
  unlet! s:prev_lnum

  return ind
endfunction

function s:GetFunctionIndent(line, ind)
  let line = a:line
  let ind = a:ind
  if line =~# '\%(^\|;\|&\||\)\s*\%(\h\w*\|\S\+\)\s*(\s*)\s*{'
    let line = substitute(line,
          \ '\%(^\|;\|&\||\)\zs\s*\%(\h\w*\|\S\+\)\s*(\s*)\s*{', '', '')
    let ind = ind + shiftwidth()
  elseif line =~# '\%(^\|;\|&\||\)\s*\%(\h\w*\|\S\+\)\s*(\s*)\s*('
    let line = substitute(line,
          \ '\%(^\|;\|&\||\)\zs\s*\%(\h\w*\|\S\+\)\s*(\s*)\s*(', '(', '')
  elseif line =~# '\%(^\|;\|&\||\)\s*function\s\+\S\+\s*(\s*)\s*{'
    let line = substitute(line,
          \ '\%(^\|;\|&\||\)\zs\s*function\s\+\S\+\s*(\s*)\s*{', '', '')
    let ind = ind + shiftwidth()
  elseif line =~# '\%(^\|;\|&\||\)\s*function\s\+\S\+\s*(\s*)\s*('
    let line = substitute(line,
          \ '\%(^\|;\|&\||\)\zs\s*function\s\+\S\+\s*(\s*)\s*(', '(', '')
  elseif line =~# '\%(^\|;\|&\||\)\s*function\s\+\S\+\s\+{'
    let line = substitute(line,
          \ '\%(^\|;\|&\||\)\zs\s*function\s\+\S\+\s\+{', '', '')
    let ind = ind + shiftwidth()
  endif

  return [line, ind]
endfunction

function s:SkipCommentLine(line, lnum, prev)
  let line = a:line
  let lnum = a:lnum
  if a:prev && s:GetPrevNonBlank(lnum)
    let lnum = s:prev_lnum
    let line = getline(lnum)
  elseif a:prev
    let line = ""
    let lnum = 0
  endif
  while lnum && line =~# '^\s*#' && s:GetPrevNonBlank(lnum)
        \ && synIDattr(synID(lnum, match(line,'#')+1,1),"name") =~? s:sh_comment
        \ && (line !~# '\\\@<!\%(\\\\\)*\zs`'
        \ || s:HideCommentStr(line, lnum) =~# '^\s*$')
    let lnum = s:prev_lnum
    let line = getline(lnum)
  endwhile
  unlet! s:prev_lnum
  let line = s:HideCommentStr(line, lnum)

  return [line, lnum]
endfunction

function s:GetContinueLineIndent(pline, pnum, ...)
  let [pline, pnum, line, lnum] = s:GetPrevContinueLine(a:pline, a:pnum, 1)
  let [rpline, pline, pnum] = s:PreMorePrevLine(pline, pnum)
  let ind = s:BackQuoteIndent(lnum, indent(lnum))
  let line = s:HideAnyItemLine(line)
  let [line, ind] = s:InsideCaseLabelIndent(pline, line, ind)
  let ind = s:PrevLineIndent(line, lnum, pline, rpline, ind)

  if a:0
    return [line, lnum, ind]
  else
    return ind
  endif
endfunction

function s:GetPrevContinueLine(line, lnum, ...)
  let line = a:line
  let lnum = a:lnum
  let last_line = ""
  let last_lnum = 0
  let s:IsContinueLine = a:0 ? function("s:IsContinuLinePrev")
        \ : function("s:IsTailBackSlash")
  while s:IsContinueLine(line) && s:GetPrevNonBlank(lnum)
    let blank = lnum - 1 == s:prev_lnum ? 0 : 1
    let last_line = s:HideTailBackSlash(line). last_line
    let last_lnum = lnum
    let lnum = s:prev_lnum
    let line = getline(lnum)
    let [line, lnum] = s:SkipCommentLine(line, lnum, 0)
    if s:IsTailBackSlash(line) && (blank || lnum != s:prev_lnum)
      break
    endif
  endwhile
  unlet! s:prev_lnum
  if s:MatchSynId(last_lnum, 1, s:d_or_s_quote. '\|'. s:sh_quote)
    let [last_line, last_lnum] = s:GetQuoteHeadAndTail(last_line, last_lnum)
    let [pline, pnum] = s:SkipCommentLine(last_line, last_lnum, 1)
    if s:IsContinuLinePrev(pline)
      let [line, lnum, nline, last_lnum] = s:GetPrevContinueLine(pline, pnum, 1)
      let last_line = nline. last_line
    endif
  endif

  if a:0 && lnum == 1 && s:IsContinuLinePrev(line)
    return ["", 0, s:HideTailBackSlash(line). last_line, lnum]
  elseif a:0
    return [line, lnum, last_line, last_lnum]
  else
    return line
  endif
endfunction

function s:PreMorePrevLine(line, lnum)
  let line = a:line
  let lnum = a:lnum
  let item = s:sh_here_doc. '\|'. s:sh_here_doc_eof
  if s:MatchSynId(lnum, 1, item)
    let lnum = s:SkipItemsLines(lnum, item)
    let line = s:GetNextContinueLine(getline(lnum), lnum)
  endif

  return [a:line, line, lnum]
endfunction

function s:GetNextContinueLine(line, lnum)
  let line = a:line
  let lnum = a:lnum
  while line =~# '\\\@<!\\\%(\\\\\)*$' && s:GetNextNonBlank(lnum) == lnum + 1
    let line = s:HideTailBackSlash(line)
    let lnum = s:next_lnum
    let line .= getline(lnum)
  endwhile
  unlet! s:next_lnum
  let line = s:HideAnyItemLine(line)
  let line = substitute(line, '\(;\|&\||\|)\|\s\)#.*$', '\1', "")

  return line
endfunction

function s:GetPrevNonBlank(lnum)
  let s:prev_lnum = prevnonblank(a:lnum - 1)

  return s:prev_lnum
endfunction

function s:GetNextNonBlank(lnum)
  let s:next_lnum = nextnonblank(a:lnum + 1)

  return s:next_lnum
endfunction

function s:CaseLabelNextIndent(ind)
  return s:CaseBreakIndent(a:ind, 1)
endfunction

function s:CaseBreakIndent(ind, ...)
  let ind = a:ind
  let lnum = v:lnum
  let sum = 0
  let items = s:d_or_s_quote. '\|'. s:sh_quote. '\|'. s:sh_here_doc_eof
  while !sum && s:GetPrevNonBlank(lnum)
    if s:MatchSynId(s:prev_lnum, 1, items)
      let lnum = s:SkipItemsLines(s:prev_lnum, items. '\|'. s:sh_here_doc)
      let [pline, pnum] = s:SkipCommentLine(getline(lnum), lnum, 1)
      let pline = s:GetPrevContinueLine(pline, pnum)
      if s:IsInSideCase(pline) && indent(lnum) < a:ind
        let ind = indent(lnum)
        break
      endif
    else
      let lnum = s:prev_lnum
    endif
    let nind = indent(lnum)
    if nind < ind
      let line = getline(lnum)
      if line =~# '^\s*case\>'
        let ind = nind + s:IndentCaseLabels()
        break
      elseif line =~# '^\s*\%(do\|then\|else\)\s\+case\>'
        let ind = nind + s:IndentCaseLabels() + shiftwidth()
        break
      elseif line =~# '^\s*#'
        continue
      elseif line =~# ')'
        let [pline, pnum] = s:SkipCommentLine(line, lnum, 1)
        if s:IsTailBackSlash(pline)
              \ && (s:IsTailBar(pline) || line =~# '^\s*|[^|]')
          let pline = s:GetPrevContinueLine(pline, pnum)
        endif
        if s:IsInSideCase(pline)
          let line = s:HideAnyItemLine(line)
          let [line, sum] = s:CaseLabelLineIndent(line, sum)
          let ind = nind
        endif
      endif
    endif
  endwhile
  unlet! s:prev_lnum

  if a:0
    return sum
  else
    return ind
  endif
endfunction

function s:CaseLabelLineIndent(line, ind)
  let line = a:line
  let ind = a:ind
  let sum = 0
  while 1
    let sum = matchend(line, ')', sum)
    if sum < 0
      break
    endif
    let head = strpart(line, 0,  sum)
    let balance = s:PairBalance(head, "(", ")")
    if line =~# '^\s*(' && balance == 0 || balance == -1
      let pt = '^\V'. head
      let line = substitute(line, pt, s:GetItemLenSpaces(line, pt), "")
      break
    endif
  endwhile
  if line !~# '^\s*$' && line !~# ';[;&]\s*$'
    let ind = strdisplaywidth(strpart(line, 0, matchend(line, '\s*')))
  else
    let ind = ind + shiftwidth()
  endif
  if line =~# ';[;&]\s*$'
    let ind = ind - shiftwidth()
  endif

  return [line, ind]
endfunction

function s:GetItemLenSpaces(line, item)
  let pos1 = match(a:line, a:item)
  let pos2 = matchend(a:line, a:item)
  let line = strpart(a:line, pos1, pos2 - pos1)
  let len = strdisplaywidth(line, pos1)
  let line = ""
  while len
    let line .= " "
    let len -= 1
  endwhile

  return line
endfunction

function s:HideAnyItemLine(line)
  let line = a:line
  if line =~# '[;&|`(){}]'
    while line =~# '\\.'
      let line = substitute(line, '\\.', s:GetItemLenSpaces(line, '\\.'), '')
    endwhile
    while 1
      let item = {}
      if line =~# '".\{-}"'
        let item[match(line, '"')] = '".\{-}"'
      endif
      if line =~# '\%o47.\{-}\%o47'
        let item[match(line, "'")] = '\%o47.\{-}\%o47'
      endif
      if line =~# '`.\{-}`'
        let item[match(line, '`')] = '`.\{-}`'
      endif
      if empty(item)
        break
      endif
      let val = max(keys(item))
      let pt = '^.\{'. (val). '}\zs'. item[val]
      let line = substitute(line, pt, s:GetItemLenSpaces(line, pt), '')
    endwhile
    let val = -2
    while 1
      let item = {}
      if line =~# '\${[^{}]\{-}\ze\s\+'
            \ && val == matchend(line, '\${[^{}]\{-}\ze\s\+')
        let item[match(line, '\${[^{}]\{-}\ze\s\+')] = '\${[^{}]\{-}\ze\s\+'
      endif
      if line =~# '\s*{[^{}]\{-}\%([;&]\s*\%(fi\|done\|esac\)\=\s*\)\@<!}'
        let item[match(line,
              \ '\s*{[^{}]\{-}\%([;&]\s*\%(fi\|done\|esac\)\=\s*\)\@<!}')]
              \ = '\s*{[^{}]\{-}\%([;&]\s*\%(fi\|done\|esac\)\=\s*\)\@<!}'
      endif
      if empty(item)
        break
      endif
      let val = max(keys(item))
      let pt = '^.\{'. (val). '}\zs'. item[val]
      let line = substitute(line, pt, s:GetItemLenSpaces(line, pt), '')
    endwhile
  endif

  return line
endfunction

function s:HideAnyItemLine2(line)
  let line = a:line
  if line =~# '(.*)'
    let len = 0
    while len != strlen(line)
      let len = strlen(line)
      let line = substitute(line, '[$=]\=([^()]*)', '', 'g')
    endwhile
  endif
  if line =~# '\<case\>' && line =~# ')'
    let line = substitute(line, '\<case\>\zs.\{-})', '|', 'g')
    let line = substitute(line, ';[;&]\%(\s*\<esac\>\)\@!.\{-})', '|', "g")
  endif

  return line
endfunction

function s:GetTabAndSpaceSum(cline, cind, sstr, sind)
  if a:cline =~# '^\t'
    let tbind = matchend(a:cline, '\t*', 0)
  else
    let tbind = 0
  endif
  let spind = a:cind - tbind * &tabstop
  if a:sstr =~# '<<-' && a:sind
    let tbind = a:sind / &tabstop
  endif

  return [tbind, spind]
endfunction

function s:InsideHereDocIndent(snum, cline)
  let sstr = getline(a:snum)
  if !&expandtab && sstr =~# '<<-' && !strlen(a:cline)
    let ind = indent(a:snum)
  else
    let ind = indent(v:lnum)
  endif
  if !&expandtab && a:cline =~# '^\t'
    let sind = indent(a:snum)
    let [tbind, spind] = s:GetTabAndSpaceSum(a:cline, ind, sstr, sind)
    if spind >= &tabstop
      let b:sh_indent_tabstop = &tabstop
      let &tabstop = spind + 1
    endif
    let ind = tbind * &tabstop + spind
  elseif &expandtab && a:cline =~# '^\t' && sstr =~# '<<-'
    let tbind = matchend(a:cline, '\t*', 0)
    let ind = ind - tbind * &tabstop
  endif

  return ind
endfunction

function s:SkipItemsLines(lnum, item)
  let lnum = a:lnum
  let onum = lnum
  while lnum
    if s:MatchSynId(lnum, 1, a:item) && s:GetPrevNonBlank(lnum)
      let onum = lnum
      let lnum = s:prev_lnum
    else
      if !s:MatchSynId(lnum, strlen(getline(lnum)), a:item)
        let lnum = onum
      endif
      break
    endif
  endwhile
  unlet! s:prev_lnum

  return lnum
endfunction

function s:HideCommentStr(line, lnum)
  let line = a:line
  if a:lnum && line =~# '\\\@<!\%(\\\\\)*\zs#'
        \ && line =~# '\%(\${\%(\h\w*\|\d\+\)#\=\|\${\=\)\@<!#'
    let max = strlen(a:line)
    let sum = 0
    let line = ""
    while sum < max
      if synIDattr(synID(a:lnum, sum + 1, 1), "name") !~? s:sh_comment
        let line .= strpart(a:line, sum, 1)
      endif
      let sum += 1
    endwhile
  endif

  return line
endfunction

function s:HideQuoteStr(line, lnum, rev)
  let line = a:line
  let sum = match(a:line, '\%o47\|"', 0)
  while sum > -1
    let n = 0
    for cid in reverse(synstack(a:lnum, sum + 1))
      let cname = synIDattr(cid, 'name')
      if !n && cname =~? s:sh_quote && a:rev
        let line = strpart(a:line, sum + 1)
        let n += 1
      elseif !n && cname =~? s:sh_quote
        let n += 1
      elseif n && cname =~? s:d_or_s_quote
        let line = strpart(a:line, 0, sum)
        break
      else
        break
      endif
    endfor
    if n && !a:rev
      break
    endif
    let sum = match(a:line, '\%o47\|"', sum + 1)
  endwhile

  return line
endfunction

function s:BackQuoteIndent(lnum, ind)
  let line = getline(a:lnum)
  let ind = a:ind
  if line !~# '\\\@<!\%(\\\\\)*\zs`'
    return ind
  endif
  let lnum = s:SkipItemsLines(a:lnum, s:back_quote)
  let sum = 0
  let csum = 0
  let pnum = 0
  let save_cursor = getpos(".")
  call cursor(lnum, 1)
  let flag = "cW"
  while search('\\\@<!\%(\\\\\)*\zs`', flag, a:lnum)
    let flag = "W"
    let lnum = line(".")
    if synIDattr(synID(lnum, col("."), 1), "name") =~? s:back_quote
      let sum += 1
      if pnum != lnum
        let csum = 1
      else
        let csum += 1
      endif
      let pnum = lnum
    endif
  endwhile
  call setpos(".", save_cursor)
  if sum % 2 && csum % 2 && pnum == a:lnum
    let ind += shiftwidth()
  elseif !(sum % 2) && csum % 2 && pnum == a:lnum
    let ind -= shiftwidth()
  endif

  return ind
endfunction

function s:MatchSynId(lnum, colnum, item)
  let sum = 0
  for cid in synstack(a:lnum, a:colnum)
    if synIDattr(cid, 'name') =~? a:item
      let sum = 1
      break
    endif
  endfor

  return sum
endfunction

function s:GetQuoteHeadAndTail(line, lnum)
  let lnum = s:SkipItemsLines(a:lnum, s:d_or_s_quote. '\|'. s:sh_quote)
  if lnum != a:lnum
    let line = s:HideQuoteStr(a:line, a:lnum, 1)
    let line = s:HideQuoteStr(getline(lnum), lnum, 0). line
  else
    let line = a:line
  endif

  return [line, lnum]
endfunction

function s:GetBackQuoteHeadAndTail(line, lnum, ind)
  let tline = a:line
  let lnum = a:lnum
  let ind = a:ind
  let sum = match(tline, '\\\@<!\%(\\\\\)*\zs`')
  let lsum = 0
  while sum > -1 && s:MatchSynId(lnum, sum + 1, s:back_quote)
    let lsum = sum + 1
    let sum = match(tline, '\\\@<!\%(\\\\\)*\zs`', lsum)
  endwhile
  let tline = strpart(tline, lsum)
  while ind < 0 && s:GetPrevNonBlank(lnum)
    let lnum = s:prev_lnum
    let ind = s:BackQuoteIndent(lnum, ind)
  endwhile
  unlet! s:prev_lnum
  let line = getline(lnum)
  let sum = match(line, '\\\@<!\%(\\\\\)*\zs`')
  while sum > -1
    if synIDattr(synID(lnum, sum + 1, 1), "name") =~? s:back_quote
      let line = strpart(line, 0, sum)
      break
    endif
    let sum = match(line, '\\\@<!\%(\\\\\)*\zs`', sum + 1)
  endwhile

  return [line. tline, lnum, ind]
endfunction

function s:GetSkipItemLinesHeadAndTail(line, lnum, ind)
  let line = a:line
  let lnum = a:lnum
  let ind = a:ind
  for lid in synstack(lnum, 1)
    let lname = synIDattr(lid, 'name')
    if lname =~? s:sh_here_doc_eof
      let lnum = s:SkipItemsLines(lnum, s:sh_here_doc. '\|'. s:sh_here_doc_eof)
      let line = s:GetNextContinueLine(getline(lnum), lnum)
      break
    elseif lname =~? s:d_or_s_quote. '\|'. s:sh_quote
      let [line, lnum] = s:GetQuoteHeadAndTail(line, lnum)
      let ind = s:BackQuoteIndent(lnum, ind)
      break
    elseif lname =~? s:back_quote && ind < 0
      let [line, lnum, ind] = s:GetBackQuoteHeadAndTail(line, lnum, ind)
      break
    endif
  endfor

  return [line, lnum, ind]
endfunction

function s:ParenBraceBalanced(line, hide)
  let line = a:hide ? s:HideAnyItemLine(a:line) : a:line
  return !s:PairBalance(line, "{", "}") && !s:PairBalance(line, "(", ")")
endfunction

function s:OvrdIndentKeys(line)
  let b:sh_indent_indentkeys = &indentkeys
  setlocal indentkeys+=a,b,c,d,<e>,f,g,h,i,j,k,l,m,n,<o>,p,q,r,s,t,u,v,w,x,y,z
  setlocal indentkeys+=A,B,C,D,E,F,G,H,I,J,K,L,M,N,<O>,P,Q,R,S,T,U,V,W,X,Y,Z
  setlocal indentkeys+=1,2,3,4,5,6,7,8,9,<0>,_,-,=,+,.
  if a:line =~# '^\s*do$'
    setlocal indentkeys-=n
    setlocal indentkeys+=<Space>,*<CR>
  elseif a:line =~# '^\s*[{(]$'
    setlocal indentkeys+={,(
  endif
endfunction

function s:BlankOrContinue(line, lnum, lnum2)
  if s:IsTailBackSlash(a:line) && a:lnum != a:lnum2
    return s:HideTailBackSlash(a:line)
  else
    return a:line
  endif
endfunction

function s:HideTailBackSlash(line)
  return substitute(a:line, '\\$', "", "")
endfunction

function s:IsTailBackSlash2(item)
  let line = type(a:item) == type("")
        \ ? a:item : s:HideCommentStr(getline(a:item), a:item)
  return s:IsTailBackSlash(line)
        \ && !s:IsTailBar(line) && !s:IsTailNoContinue(line)
endfunction

function s:IsExprLineHead(line)
  return a:line =~# '^\s*if\>\%(.*[;&]\s*fi\>\)\@!'
        \ || a:line =~# '^\s*case\>\%(.*[;&]\s*esac\>\)\@!'
        \ || a:line =~# '^\s*\%(while\|until\|for\|select\)\>'
        \. '\%(.*[;&]\s*done\>\)\@!'
endfunction

function s:IsExprLineTail(line)
  return a:line =~# '^\s*\%(fi\|done\|esac\)\>'
        \ || a:line =~# '^\s*[)}]'
endfunction

function s:IsFunctionLine(line)
  return a:line =~# '^\s*\%(function\s\+\)\=\%(\h\w*\|\S\+\)\s*(\s*)\s*$'
        \ || a:line =~# '^\s*function\s\+\S\+\s*$'
endfunction

function s:IsHeadAndBarOr(line)
  return a:line =~# '^\s*\%(&&\|||\=\)'
endfunction

function s:IsTailAndOr(line)
  return a:line =~# '\%(&&\|||\)\s*\\\=$'
endfunction

function s:IsTailBar(line)
  return a:line =~# '[^|]|\s*\\\=$'
endfunction

function s:IsTailBackSlash(line)
  return a:line =~# '\\\@<!\\\%(\\\\\)*$'
        \ && a:line =~# '\%(&&\s*\|||\s*\)\@<!\\$'
endfunction

function s:IsTailNoContinue(line)
  return a:line =~# '\%(\\\@<!\\\%(\\\\\)*\|;\)\@<!;\s*\\$'
        \ || a:line =~# '\%(\\\@<!\\\%(\\\\\)*\|&\)\@<!&\s*\\$'
        \ || a:line =~# '\%(\\\@<!\\\%(\\\\\)*\||\)\@<!|\s*\\$'
        \ || a:line =~# '\%(\\\@<!\\\%(\\\\\)*\)\@<!\%(;;\|;&\|;;&\)\s*\\$'
endfunction

function s:IsContinuLineFore(line)
  return a:line =~# '\\\@<!\\\%(\\\\\)*$'
        \ || a:line =~# '\%(&&\|||\)\s*\\\=$'
endfunction

function s:IsContinuLinePrev(line)
  return a:line =~# '\\\@<!\\\%(\\\\\)*$'
        \ || a:line =~# '\%(&&\|||\=\)\s*\\\=$'
endfunction

function s:IsInSideCase(line)
  return a:line =~# '\%(^\%(\s*\%(do\|then\|else\)\s\+\)\=\|[;&|`(){}]\)'
        \. '\s*case\>\%(.*;[;&]\s*\<esac\>\)\@!'
        \ || a:line =~# ';[;&]\s*$'
endfunction

function s:EndOfTestQuotes(line, lnum, item)
  return a:line =~# '^\%("\|\%o47\)$'
        \ || a:line =~# '\\\@<!\%(\\\\\)*\zs\%("\|\%o47\)$'
        \ && synIDattr(synID(a:lnum, strlen(a:line) - 1, 1), "name") =~? a:item
endfunction

function s:IndentCaseLabels()
  return g:sh_indent_case_labels ? shiftwidth() / g:sh_indent_case_labels : 0
endfunction

function s:PairBalance(line, i1, i2)
  return len(split(a:line, a:i1, 1)) - len(split(a:line, a:i2, 1))
endfunction

let &cpo = s:cpo_save
unlet s:cpo_save

" vim: set sts=2 sw=2 expandtab:
