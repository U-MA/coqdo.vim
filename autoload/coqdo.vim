let s:save_cpo = &cpo
set cpo&vim

let s:oldlinenr = 0
let s:curlinenr = 0
let s:match_id  = 0
let s:output = ''

augroup CoqdoAsyncRun
augroup END

function! s:async_run(input, is_silent) abort " {{{
  call s:proc.stdin.write(a:input)

  augroup CoqdoAsyncRun
    execute 'autocmd! CursorHold,CursorHoldI * call s:output_if_possible(' . a:is_silent .')'
  augroup END

  let s:updatetime = &updatetime
  let &updatetime = 0
endfunction " }}}

function! s:output_if_possible(is_silent) abort " {{{
  let buf = s:proc.stdout.read(-1, 100)
  if match(s:output, '\(.\+ < \)\+$') != -1
    if empty(buf)
      let buflist = split(s:output, '[[:cntrl:]]')
      call map(buflist, "matchstr(v:val, '\\(\\(Coq < \\)*\\)\\zs.\\+')")
      call filter(buflist, "match(v:val, '.\\+ < ') == -1")

      if !a:is_silent
        let winnr = winnr()
        execute bufwinnr(s:bufnr) 'wincmd w'
        silent %delete _
        call setline(1, buflist)
        execute winnr 'wincmd w'
      endif

      let s:output = ''

      autocmd! CoqdoAsyncRun

      let &updatetime = s:updatetime

      call feedkeys('g\<ESC>', 'n')
      return 1
    endif
  endif

  let s:output .= buf
  call feedkeys('g\<ESC>', 'n')
  return 0
endfunction " }}}

function! coqdo#start() abort " {{{
  let s:proc = vimproc#popen2('coqtop')

  rightbelow vnew
  let s:bufnr = bufnr('%')
  setlocal buftype=nofile noswapfile "TODO set other options
  wincmd p

  call s:async_run('', 0)
endfunction "}}}

function! coqdo#quit() abort " {{{
  call s:proc.stdin.write("Quit.\n")
  call s:proc.waitpid()

  let winnr = bufwinnr(s:bufnr)
  let curwinnr = winnr()
  execute winnr 'wincmd w'
  close
  execute curwinnr 'wincmd w'

  delcommand CoqdoQuit
  delcommand CoqdoGoto
  delcommand CoqdoClear
  delcommand CoqdoForward
  delcommand CoqdoBackward

  nunmap <buffer> <LocalLeader>q
  nunmap <buffer> <LocalLeader>g
  nunmap <buffer> <LocalLeader>c
  nunmap <buffer> <LocalLeader>j
  nunmap <buffer> <LocalLeader>k

  augroup Coqdo
    autocmd!
  augroup END

  if s:match_id > 0
    call matchdelete(s:match_id)
  endif
  let s:match_id = 0
  let s:oldlinenr = 0
  let s:curlinenr = 0

  unlet g:coqdo_started
endfunction " }}}

function! coqdo#goto(linenr) abort " {{{
  if a:linenr < s:curlinenr
    return
  endif

  let s:oldlinenr = s:curlinenr
  let s:curlinenr = a:linenr

  let line = getline(s:oldlinenr+1, a:linenr)
  let input = join(line, "\n") . "\n"
  call s:async_run(input, 0)

  if s:match_id > 0
    call matchdelete(s:match_id)
  endif
  let s:match_id = matchadd('coqdoEndLine', '\%' . s:curlinenr . 'l')
endfunction " }}}

function! coqdo#clear(is_silent) abort " {{{
  call s:proc.stdin.write("Quit.\n")
  call s:proc.waitpid()

  let s:proc = vimproc#popen2('coqtop')

  let s:oldlinenr = 0
  let s:curlinenr = 0

  call s:async_run('', a:is_silent)

  if s:match_id > 0
    let s:match_id = matchdelete(s:match_id)
  endif
endfunction " }}}

function! coqdo#forward() abort " {{{
  if s:curlinenr == line('$')
    return
  endif

  call coqdo#goto(s:curlinenr + 1)
endfunction " }}}

function! coqdo#backward_one() abort " {{{
  if s:curlinenr == 0
    return
  endif

  call coqdo#backward(s:curlinenr)
endfunction " }}}

function! coqdo#backward(linenr) abort " {{{
  if a:linenr > s:curlinenr
    return
  endif

  call coqdo#clear(1)

  let s:curlinenr = a:linenr - 1 " TODO how do a:linenr = 0 ?
  if s:match_id > 0
    call matchdelete(s:match_id)
  endif
  let s:match_id = matchadd('coqdoEndLine', '\%' . s:curlinenr . 'l')

  let line = getline(s:oldlinenr+1, s:curlinenr)
  let input = join(line, "\n") . "\n"
  call s:async_run(input, 1)
endfunction " }}}

function! coqdo#search_about(args) abort " {{{
  let input = 'SearchAbout "' . a:args . '".' . "\n"
  call s:async_run(input, 0)
endfunction " }}}

let &cpo = s:save_cpo
unlet s:save_cpo
