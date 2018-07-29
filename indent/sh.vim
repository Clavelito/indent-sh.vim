" Vim indent file
" Language:         Shell Script
" Maintainer:       Clavelito <maromomo@hotmail.com>
" Last Change:      Sun, 29 Jul 2018 13:43:00 +0900
" Version:          4.80
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
let s:command_sub = 'CmdSubRegion'
let s:sh_comment = 'Comment\|Todo'
let s:test_d_or_s_quote = 'TestDoubleQuote\|TestSingleQuote'
let s:d_or_s_quote = 'DoubleQuote\|SingleQuote\|DblQuote\|SnglQuote'
let s:double_quote = 'DoubleQuote'
let s:sh_quote = 'shQuote'
let s:sh_here_doc = 'HereDoc'
let s:sh_here_doc_eof = 'HereDoc\d\d\|shRedir\d\d'
let s:sh_deref = 'PreProc'
let s:sh_deref_str = 'Deref'

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

  let sum = 0
  for cid in reverse(synstack(lnum, strlen(line)))
    let cname = synIDattr(cid, 'name')
    if cname =~? s:sh_here_doc. '$'
      return s:InsideHereDocIndent(lnum, cline)
    elseif cname =~? s:test_d_or_s_quote && s:EndOfTestQuotes(line, lnum)
      break
    elseif cname =~? s:back_quote
      let sum += 1
    elseif cname =~? s:double_quote && sum
      break
    elseif cname =~? s:d_or_s_quote || cname =~? s:sh_deref_str. '$'
      return indent(v:lnum)
    endif
  endfor

  let [line, lnum] = s:SkipCommentLine(line, lnum, 0)
  let line = s:BlankOrContinue(line, lnum, v:lnum - 1)
  let ind = s:BackQuoteIndent(lnum, 0)
  let [line, lnum, ind] = s:GetSkipItemLinesHeadAndTail(line, lnum, ind)
  let ind = indent(lnum) + ind
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
        \ && !s:IsInItItem(a:lnum, s:double_quote)
        \ && s:GetLessIndentLineIndent(a:lnum, ind, 0) == ind
    let ind = ind + shiftwidth()
  elseif (s:IsTailAndOr(a:pline) && !s:IsContinuLineFore(line)
        \ && !s:IsTailBar(a:line) && !s:IsFunctionLine(line)
        \ || (s:IsTailBar(a:pline) && !s:IsContinuLineFore(line)
        \ && !s:IsTailBar(a:line)
        \ || s:IsTailBackSlash(a:pline) && s:IsTailBar(a:line)
        \ && !g:sh_indent_tail_bar)
        \ && !s:IsInSideCase(pline))
        \ && s:PairBalance(s:HideOptionStr(line), "{", "}") <= 0
        \ && s:PairBalance(s:HideOptionStr(line), "(", ")") <= 0
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
  elseif s:IsCaseEnd(line) && a:line !~# '^\s*case\>\%(.\{-}\<esac\>\)\@!'
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
  let ind = s:ParenBraceIndent(line, a:rpline, ind)
  let ind = s:CloseParenIndent(a:pline, line2, line, a:lnum, a:rpline, ind)
  let ind = s:CloseBraceIndent(a:pline, line2, line, a:lnum, a:rpline, ind)

  return ind
endfunction

function s:PrevLineIndent0(pline, line, lnum, rpline, ind)
  if !s:IsHeadAndBarOrSemiColon(a:line) && s:IsTailBackSlash2(a:rpline)
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
    if s:IsCaseEnd(a:line) && !s:case_count
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
  if a:cline =~# '^\s*esac\>' && !s:IsCaseEnd(a:line)
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
        \ && !s:IsCaseEnd(a:nline) && !s:IsInSideCase(a:pline)
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
  let pt1 = '[;&]\C\s*\%(done\|fi\|esac\)\=\s*}\|^\s\+}'
  if a:nline =~# pt1 && !s:IsCaseEnd(a:nline)
        \ && !s:IsTailBackSlash2(a:nline)
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

function s:ParenBraceIndent(line, rpline, ind)
  let ind = a:ind
  if s:IsTailBackSlash2(a:rpline)
    let head_pt = '\%(;\|&\||\)'
  else
    let head_pt = '\%(^\|;\|&\||\)'
  endif
  let pt1 = '\%('. head_pt. '\s*\|\%(do\|then\|else\)\s\+\)'
        \. '\C\%(\%(if\|elif\|while\|until\)\s\+\)\=\%([!]\s\+\)\={'
  if a:line =~# '('
    let ind = ind + shiftwidth() * (len(split(a:line, '(', 1)) - 1)
  endif
  if a:line =~# pt1 && !s:IsCaseEnd(a:line)
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
          \ && !s:IsHeadAndBarOrSemiColon(line)
          \ && line !~# '^\s*\%(do\|then\|elif\|else\)\>'
          \ && !s:PairBalance(s:HideOptionStr(line), "{", "}")
          \ && !s:PairBalance(s:HideOptionStr(line), "(", ")"))
      break
    elseif cind < ind && s:IsContinuLinePrev(line) && s:IsExprLineTail(line)
      let ind = cind
    elseif cind < ind
          \ && !s:IsContinuLinePrev(line) && s:IsHeadAndBarOrSemiColon(line)
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
  if line =~# '\%(^\|;\|&\||\)\s*\%(\h\w*\|\S\+\)\s*(\s*)\s*[{(]'
    let line = substitute(line,
          \ '\%(^\|;\|&\||\)\zs\s*\%(\h\w*\|\S\+\)\s*(\s*)\s*[{(]', '', '')
    let ind = ind + shiftwidth()
  elseif line =~# '\%(^\|;\|&\||\)\s*function\s\+\S\+\s*(\s*)\s*[{(]'
    let line = substitute(line,
          \ '\%(^\|;\|&\||\)\zs\s*function\s\+\S\+\s*(\s*)\s*[{(]', '', '')
    let ind = ind + shiftwidth()
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
        \ && !s:MatchSynId(lnum, match(line,'#') + 1, s:sh_here_doc_eof)
        \ && !(line =~# '\\\@<!\%(\\\\\)*\zs`'
        \ && s:MatchSynId(lnum, 1, s:back_quote))
    let lnum = s:prev_lnum
    let line = getline(lnum)
  endwhile
  unlet! s:prev_lnum
  if a:prev
    let line = s:HideCommentStr(line, lnum)
  else
    let line = s:HideAnyItemLine3(line, lnum)
  endif

  return [line, lnum]
endfunction

function s:GetContinueLineIndent(pline, pnum, ...)
  let [pline, pnum, line, lnum] = s:GetPrevContinueLine(a:pline, a:pnum, 1)
  let [rpline, pline, pnum] = s:PreMorePrevLine(pline, pnum)
  let ind = s:BackQuoteIndent(lnum, indent(lnum))
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
    let [line, lnum, nline, last_lnum] = s:GetPrevContinueLine(pline, pnum, 1)
    let last_line = nline. last_line
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
  let line = s:HideAnyItemLine3(line, lnum)
  while line =~# '\\\@<!\%(\\\\\)*\\$' && s:GetNextNonBlank(lnum) == lnum + 1
    let line = s:HideTailBackSlash(line)
    let lnum = s:next_lnum
    let line .= getline(lnum)
  endwhile
  unlet! s:next_lnum
  if lnum != a:lnum
    let line = s:HideAnyItemLine(line)
    let line = substitute(line, '\(;\|&\||\|\s\)#.*$', '\1', "")
  endif

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
          let line = s:HideAnyItemLine3(line, lnum)
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
  let wid = ind
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
      let end = matchend(line, '\%("\s*"\|\s\)*')
      let wid = strdisplaywidth(strpart(line, 0, end))
      let line = strpart(line, end)
      break
    endif
  endwhile
  if line =~# '^\s*\%(:\s*\)\=$' || s:IsCaseEnd(line) || line =~# '^\s*#'
    let ind = ind + shiftwidth()
  else
    let ind = wid
  endif
  if s:IsCaseEnd(line)
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
    let len -= 1
    if !strlen(line) && len || strlen(line) && !len
      let line .= '"'
    else
      let line .= " "
    endif
  endwhile

  return line
endfunction

function s:HideQuotePairs(line, pos, bq)
  let line = a:line
  while 1
    let item = {}
    if strpart(line, a:pos) =~# '"\@<!\%(""\)*"..\{-}"'
      let item[match(line, '"', a:pos)] = '"\@<!\%(""\)*"..\{-}"'
    endif
    if strpart(line, a:pos) =~# "'[^']*'"
      let item[match(line, "'", a:pos)] = "'[^']*'"
    endif
    if strpart(line, a:pos) =~# '`.\{-}`' && a:bq
      let item[match(line, '`', a:pos)] = '`.\{-}`'
    endif
    if empty(item)
      break
    endif
    let val = min(keys(item))
    let pt = '^.\{'. (strchars(strpart(line, 0, val))). '}\zs'. item[val]
    let line = substitute(line, pt, '""', '')
  endwhile

  return line
endfunction

function s:HideBracePairs(line)
  let line = a:line
  let pt1 = '\%(&\s*\||\s*\)\@<!{[^{}]\{-}}'
  while line =~# pt1
    let pt = '^.\{'. (strchars(strpart(line, 0, match(line, pt1)))). '}\zs'. pt1
    let line = substitute(line, pt, s:GetItemLenSpaces(line, pt), '')
  endwhile

  return line
endfunction

function s:HideOptionStr(line)
  let line = a:line
  let pt1 = '[^ \t;&|#()<>`-]'
  let pt2 = '\%([^ \t;&|()<>`]\+\)\='
  let pt3 = '--\=[a-zA-Z]'
  let pt4 = '\%(\s\+'. pt1. pt2. '\)\+'
  for str in [pt1. '-'. pt2, pt3. pt2. pt4, pt3. pt2]
    while line =~# str
      let pt = '^.\{'. strchars(strpart(line, 0, match(line, str))). '}\zs'. str
      let line = substitute(line, pt, s:GetItemLenSpaces(line, pt), '')
    endwhile
  endfor

  return line
endfunction


function s:HideAnyItemLine(line)
  let line = a:line
  if line =~# '[;&|`(){}]'
    while line =~# '\\.'
      let line = substitute(line, '\\.', "", '')
    endwhile
    if line =~# '\$((\@!.*)'
      let line = s:HideQuotePairs(line, matchend(line, '\$((\@!'), 1)
    endif
    if line =~# '`.\{-}`'
      let line = s:HideQuotePairs(line, matchend(line, '`'), 0)
    endif
    let line = s:HideQuotePairs(line, 0, 1)
    let line = s:HideBracePairs(line)
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

function s:HideAnyItemLine3(line, lnum, ...)
  let line = a:line
  let item = {}
  let pt = ""
  let sum = 0
  if line =~# '[;&|`(){}]' && line =~# '[$",]\|\%o47\|\\.\|\V..'
        \ || line =~# '#' || a:0 && a:1
    for str in split(line, '\zs')
      if empty(item) && str !~# '[$`"#}'. "']"
        let sum += strlen(str)
        continue
      elseif empty(item) && str ==# '$'
        let item = s:GetItemProperty(a:lnum, sum + 1)
        if item.name !=? s:sh_deref
          let item = {}
        endif
      elseif empty(item) && (str ==# "'" || str ==# '"')
        let item = s:GetItemProperty(a:lnum, sum + 1)
        if item.name !~? s:sh_quote
          let item = {}
        elseif item.name =~? s:sh_quote && item.under !~? s:d_or_s_quote
              \ && str ==# '"' && sum && line =~# '^"'
          let str = '"\s*"[^"]*'. str
          let line = s:HideHeadAndReachStr(line, str)
          let item = {}
        elseif item.name =~? s:sh_quote && item.under !~? s:d_or_s_quote
              \ && str ==# '"' && sum
          let str = '\%("\s*"[^"]*\)*'. str
          let line = s:HideHeadAndReachStr(line, str)
          let item = {}
        elseif item.name =~? s:sh_quote && item.under !~? s:d_or_s_quote
          let line = s:HideHeadAndReachStr(line, str)
          let item = {}
        endif
      elseif empty(item) && str ==# '#'
        let item = s:GetItemProperty(a:lnum, sum + 1)
        if item.name !~? s:sh_comment
          let item = {}
        endif
      elseif empty(item) && str ==# '}'
            \ && s:GetItemProperty(a:lnum, sum + 1).name ==? s:sh_deref
        let line = s:HideHeadAndReachStr(line, str)
      elseif !empty(item) && item.name =~? s:sh_comment
            \ && !s:MatchSynId(a:lnum, sum + 1, s:sh_comment)
        let [line, pt, item] = s:HideItemAndReachStr(line, pt. str)
      elseif !empty(item) && str ==# '`'
            \ && item.under =~? s:double_quote && !a:0
            \ && s:GetItemProperty(a:lnum, sum + 1).name =~? s:back_quote
            \ && s:IsInItItem(a:lnum, s:double_quote) > 0
        let [line, pt, item] = s:HideItemAndReachStr(line, pt)
      elseif !empty(item) && str ==# '$'
            \ && item.under =~? s:double_quote && !a:0
            \ && s:GetItemProperty(a:lnum, sum + 1).name =~? s:command_sub
            \ && s:IsInItItem(a:lnum, s:double_quote) > 0
        let [line, pt, item] = s:HideItemAndReachStr(line, pt)
      elseif !empty(item) && (str ==# '}' || str ==# "'" || str ==# '"')
        let item2 = s:GetItemProperty(a:lnum, sum + 1)
        if item2.name ==# item.name && item2.depth + 1 == item.depth
          let [line, pt, item] = s:HideItemAndReachStr(line, pt. str)
        endif
      endif
      if !empty(item)
        let pt .= str
      endif
      let sum += strlen(str)
    endfor
    if strlen(pt)
      let pt = '\V'. escape(pt, '\')
      let line = substitute(line, pt, "", "")
    endif
    while line =~# '\\.'
      let line = substitute(line, '\\.', s:GetItemLenSpaces(line, '\\.'), '')
    endwhile
    if line =~# '`.\{-}`'
      let pt = '`.\{-}`'
      let line = substitute(line, pt, s:GetItemLenSpaces(line, pt), "")
    endif
    let line = s:HideBracePairs(line)
  endif

  return line
endfunction

function s:GetItemProperty(lnum, colnum)
  let sum = 0
  let name = {}
  let name.name = ""
  let name.under = ""
  for lid in reverse(synstack(a:lnum, a:colnum))
    if sum == 0
      let name.name = synIDattr(lid, 'name')
    elseif sum == 1
      let name.under = synIDattr(lid, 'name')
    endif
    let sum += 1
  endfor
  let name.depth = sum

  return name
endfunction

function s:HideHeadAndReachStr(line, str)
  let pt = '\V'. escape(strpart(a:line, 0, matchend(a:line, a:str)), '\')
  let line = substitute(a:line, pt, s:GetItemLenSpaces(a:line, pt), "")

  return line
endfunction

function s:HideItemAndReachStr(line, str)
  let pt = '\V'. escape(a:str, '\')
  let line = substitute(a:line, pt, s:GetItemLenSpaces(a:line, pt), "")

  return [line, "", {}]
endfunction

function s:GetHereDocEof(lnum)
  let lnum = a:lnum
  while lnum && s:GetNextNonBlank(lnum)
        \ && s:MatchSynId(lnum, 1, s:sh_here_doc. '$')
    let lnum = getline(lnum) =~# '^\t*[ ]' ? 0 : s:next_lnum
  endwhile
  unlet! s:next_lnum
  if lnum && !s:MatchSynId(lnum, 1, s:sh_here_doc_eof)
    let lnum = 0
  endif
  
  return lnum
endfunction

function s:InsideHereDocIndent(lnum, cline)
  let snum = s:SkipItemsLines(a:lnum, s:sh_here_doc, 1)
  let sstr = getline(snum)
  if !&expandtab && sstr =~# '<<-' && !strlen(a:cline)
    let ind = indent(snum)
  else
    let ind = indent(v:lnum)
  endif
  if !&expandtab && a:cline =~# '^\t*' && strlen(a:cline) && sstr =~# '<<-'
    let sind = indent(snum)
    let enum = s:GetHereDocEof(snum + 1)
    let eind = enum ? indent(enum) - sind : 0
    let tbind = a:cline =~# '^\t' ? matchend(a:cline, '\t*', 0) : 0
    let spind = strdisplaywidth(matchstr(a:cline, '\s*', tbind), sind)
    let tbind = sind ? sind / &tabstop : 0
    if spind >= &tabstop
      let b:sh_indent_tabstop = &tabstop
      let &tabstop = spind + 1
    endif
    if spind || !enum
      let ind = tbind * &tabstop + spind
    else
      let ind -= eind
    endif
  elseif &expandtab && a:cline =~# '^\t' && sstr =~# '<<-'
    let tbind = matchend(a:cline, '\t*', 0)
    let ind = ind - tbind * &tabstop
  endif

  return ind
endfunction

function s:SkipItemsLines(lnum, item, ...)
  let lnum = a:lnum
  let onum = lnum
  let cdep = a:0 ? 0 : s:MatchSynId(v:lnum, 1, a:item)
  while lnum
    let depth = s:MatchSynId(lnum, 1, a:item)
    if cdep < depth && s:GetPrevNonBlank(lnum)
      let onum = lnum
      let lnum = s:prev_lnum
    else
      if depth == s:MatchSynId(lnum, strlen(getline(lnum)), a:item)
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
    let sum = 0
    let pt = ""
    for str in split(line, '\zs')
      let item = s:GetItemProperty(a:lnum, sum + 1)
      if item.name =~? s:sh_comment
        let pt .= str
      else
        if strlen(pt)
          let pt = '\V'. escape(pt. str, '\')
          let line = substitute(line, pt, s:GetItemLenSpaces(line, pt), "")
          let pt = ""
        endif
      endif
      let sum += strlen(str)
    endfor
    if strlen(pt)
      let pt = '\V'. escape(pt, '\')
      let line = substitute(line, pt, "", "")
    endif
  endif

  return line
endfunction

function s:BackQuoteIndent(lnum, ind)
  let line = getline(a:lnum)
  let ind = a:ind
  if line !~# '\\\@<!\%(\\\\\)*\zs`'
    return ind
  endif
  let lnum = s:SkipItemsLines(a:lnum, s:back_quote, 1)
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
      let sum += 1
    endif
  endfor

  return sum
endfunction

function s:GetQuoteHeadAndTail(line, lnum)
  let lnum = s:SkipItemsLines(a:lnum, s:d_or_s_quote. '\|'. s:sh_quote)
  if lnum != a:lnum
    let line = s:HideAnyItemLine3(getline(lnum), lnum, 1). a:line
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

function s:GetDerefHeadAndTail(line, lnum)
  let lnum = s:SkipItemsLines(a:lnum, s:sh_deref. '\|'. s:sh_deref_str)
  if lnum != a:lnum
    if a:line =~# '[;&|`(){}]'
      let line = s:HideAnyItemLine3(getline(lnum), lnum, 1). a:line
    else
      let line = s:HideAnyItemLine3(getline(lnum), lnum, 1)
            \. s:HideAnyItemLine3(a:line, a:lnum, 1)
    endif
  else
    let line = a:line
  endif

  return [line, lnum]
endfunction

function s:GetSkipItemLinesHeadAndTail(line, lnum, ind)
  let line = a:line
  let lnum = a:lnum
  let ind = a:ind
  let sum = 0
  for lid in synstack(lnum, 1)
    let lname = synIDattr(lid, 'name')
    if lname =~? s:sh_here_doc_eof
      let lnum = s:SkipItemsLines(lnum, s:sh_here_doc. '\|'. s:sh_here_doc_eof)
      let line = s:GetNextContinueLine(getline(lnum), lnum)
      break
    elseif lname =~? s:d_or_s_quote. '\|'. s:sh_quote
      if lname =~? s:double_quote
        if s:MatchSynId(lnum, 1, s:sh_here_doc_eof)
          continue
        elseif s:MatchSynId(lnum, 1, s:back_quote)
              \ && !s:IsInItItem(lnum, s:d_or_s_quote)
          break
        endif
      endif
      let [line, lnum] = s:GetQuoteHeadAndTail(line, lnum)
      let ind = s:BackQuoteIndent(lnum, ind)
      break
    elseif lname =~? s:back_quote && ind < 0
      let [line, lnum, ind] = s:GetBackQuoteHeadAndTail(line, lnum, ind)
      break
    elseif lname =~? s:sh_deref_str && sum
          \ || lname ==? s:sh_deref && strpart(getline(lnum), 0, 1) ==# '}'
      let [line, lnum] = s:GetDerefHeadAndTail(line, lnum)
      break
    elseif lname =~? s:sh_deref_str
      let sum += 1
    endif
  endfor

  return [line, lnum, ind]
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
  return s:IsTailBackSlash(line) && !s:IsTailNoContinue(line)
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

function s:IsHeadAndBarOrSemiColon(line)
  return a:line =~# '^\s*\%(&&\=\|||\=\|;[^;&]\)'
endfunction

function s:IsTailAndOr(line)
  return a:line =~# '\%(&&\|||\)\s*\\\=$'
endfunction

function s:IsTailBar(line)
  return a:line =~# '[^|]|\s*\\\=$'
endfunction

function s:IsTailBackSlash(line)
  return a:line =~# '\\\@<!\%(\\\\\)*\\$'
        \ && a:line =~# '\%(&&\s*\|||\s*\)\@<!\\$'
endfunction

function s:IsTailNoContinue(line)
  return a:line =~# '\%(\\\@<!\%(\\\\\)*\\\|;\)\@<!;\s*\\$'
        \ || a:line =~# '\%(\\\@<!\%(\\\\\)*\\\|&\)\@<!&\s*\\$'
        \ || a:line =~# '\%(\\\@<!\%(\\\\\)*\\\||\)\@<!|\s*\\$'
        \ || a:line =~# '\%(\\\@<!\%(\\\\\)*\\\)\@<!\%(;;\|;&\|;;&\)\s*\\$'
endfunction

function s:IsContinuLineFore(line)
  return a:line =~# '\\\@<!\%(\\\\\)*\\$'
        \ || a:line =~# '\%(&&\|||\)\s*\\\=$'
endfunction

function s:IsContinuLinePrev(line)
  return a:line =~# '\\\@<!\%(\\\\\)*\\$'
        \ || a:line =~# '\%(&&\|||\=\)\s*\\\=$'
endfunction

function s:IsCaseEnd(line)
  return a:line =~# ';[;&]\s*$'
endfunction

function s:IsInSideCase(line)
  return a:line =~# '\%(\%(^\|[;&]\)\%(\s*\%(do\|then\|else\)\s\+\)\='
        \. '\|[;&|`(){]\)\s*case\>\%(.*;[;&]\s*\<esac\>\)\@!'
        \ || a:line =~# ';[;&]\s*$'
endfunction

function s:EndOfTestQuotes(line, lnum)
  return a:line =~# '^\%("\|\%o47\)$'
        \ || a:line =~# '\\\@<!\%(\\\\\)*\%("\|\%o47\)$'
        \ && s:MatchSynId(a:lnum, strlen(a:line) - 1, s:test_d_or_s_quote)
endfunction

function s:IndentCaseLabels()
  return g:sh_indent_case_labels ? shiftwidth() / g:sh_indent_case_labels : 0
endfunction

function s:PairBalance(line, i1, i2)
  return len(split(a:line, a:i1, 1)) - len(split(a:line, a:i2, 1))
endfunction

function s:IsInItItem(lnum, item)
  return s:MatchSynId(v:lnum, 1, a:item) - s:MatchSynId(a:lnum, 1, a:item)
endfunction

let &cpo = s:cpo_save
unlet s:cpo_save

" vim: set sts=2 sw=2 expandtab:
