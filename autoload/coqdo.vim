let s:save_cpo = &cpo
set cpo&vim

let s:oldlinenr = 0
let s:curlinenr = 0
let s:match_id  = 0
let s:output = ''
let s:last_theorem_name = ''
let s:proof = ''

augroup CoqdoAsyncRun
augroup END

function! s:start_coptop(is_silent) abort " {{{
  let s:oldlinenr = 0
  let s:curlinenr = 0

  let s:proc = vimproc#popen2('coqtop')

  let output = ''
  while 1
    let buf = s:proc.stdout.read(-1, 100)
    if match(output, '\(.\+ < \)\+$') != -1
      if empty(buf)
        let buflist = split(output, '[[:cntrl:]]')
        call map(buflist, "matchstr(v:val, '\\(\\(Coq < \\)*\\)\\zs.\\+')")
        call filter(buflist, "match(v:val, '.\\+ < ') == -1")

        if !a:is_silent
          let winnr = winnr()
          execute bufwinnr(s:bufnr) 'wincmd w'
          silent %delete _
          call setline(1, buflist)
          execute winnr 'wincmd w'
        endif

        break
      endif
    endif
    let output .= buf
  endwhile
endfunction " }}}

function! s:async_run(input, is_silent, mode, winnr) abort " {{{
  let ltn = s:find_theorem_name(a:input)
  if ltn !=# s:last_theorem_name
    let s:proof = ltn
  endif
  call s:proc.stdin.write(a:input)

  if a:mode == 'n'
    augroup CoqdoAsyncRun
      execute 'autocmd! CursorHold  * call s:output_if_possible(' . a:is_silent .", 'n', " . a:winnr . ")"
    augroup END
  elseif a:mode == 'i'
    augroup CoqdoAsyncRun
      execute 'autocmd! CursorHoldI * call s:output_if_possible(' . a:is_silent .", 'i', " . a:winnr . ")"
    augroup END
  endif

  let s:updatetime = &updatetime
  let &updatetime = 0
endfunction " }}}

function! s:output_if_possible(is_silent, mode, winnr) abort " {{{
  let buf = s:proc.stdout.read(-1, 100)
  if match(s:output, '\(.\+ < \)\+$') != -1
    if empty(buf)
      let buflist = split(s:output, '[[:cntrl:]]')
      call map(buflist, "matchstr(v:val, '\\(\\(Coq < \\)*\\)\\zs.\\+')")
      call filter(buflist, "match(v:val, 'Coq < ') == -1")
      call filter(buflist, "match(v:val, 'Unnamed_thm\d* < ') == -1")
      if !empty(s:proof)
        let tmp = "match(v:val, \"" . s:proof . " < \") == -1"
        call filter(buflist, tmp)
      endif

      if !a:is_silent
        let winnr = winnr()
        execute a:winnr 'wincmd w'
        silent %delete _
        call setline(1, buflist)
        normal G
        execute winnr 'wincmd w'
      endif

      let s:output = ''

      autocmd! CoqdoAsyncRun

      let &updatetime = s:updatetime

      if a:mode == 'n'
        call feedkeys("g\<ESC>", 'n')
      elseif a:mode == 'i'
        call feedkeys("\<C-g>\<ESC>", 'n')
      endif
      return 1
    endif
  endif

  let s:output .= buf
  if a:mode == 'n'
    call feedkeys('g\<ESC>', 'n')
  elseif a:mode == 'i'
    call feedkeys("\<C-g>\<ESC>", 'n')
  endif
  return 0
endfunction " }}}

function! s:find_theorem_name(string) abort " {{{
  return matchstr(a:string, '.*\zs\(Theorem\|Lemma\|Remark\|Fact\|Corollary\|Proposition\|Definition\|Example\)\s\+\zs\S\+\ze\s*:')
endfunction " }}}

function! coqdo#start() abort " {{{
  let s:mainbufnr = bufnr('%')

  rightbelow vnew
  let s:bufnr = bufnr('%')
  setlocal buftype=nofile noswapfile "TODO set other options

  rightbelow new
  let s:msgbufnr = bufnr('%')
  setlocal buftype=nofile noswapfile "TODO set other options
  execute s:mainbufnr 'wincmd w'

  call s:start_coptop(0)
endfunction "}}}

function! coqdo#quit() abort " {{{
  call s:proc.stdin.write("Quit.\n")
  call s:proc.waitpid()

  let msgwinnr = bufwinnr(s:msgbufnr)
  let winnr = bufwinnr(s:bufnr)
  let curwinnr = winnr()
  execute msgwinnr 'wincmd w'
  close
  execute winnr 'wincmd w'
  close
  execute curwinnr 'wincmd w'

  delcommand CoqdoQuit
  delcommand CoqdoGoto
  delcommand CoqdoClear
  delcommand CoqdoForward
  delcommand CoqdoBackward

  if exists('g:coqdo_default_key_mapping')
    nunmap <buffer> <LocalLeader>q
    nunmap <buffer> <LocalLeader>g
    nunmap <buffer> <LocalLeader>c
    nunmap <buffer> <LocalLeader>j
    nunmap <buffer> <LocalLeader>k
  endif

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
  call s:async_run(input, 0, 'n', s:bufnr)

  if s:match_id > 0
    call matchdelete(s:match_id)
  endif
  let s:match_id = matchadd('coqdoEndLine', '\%' . s:curlinenr . 'l')
endfunction " }}}

function! coqdo#clear(is_silent) abort " {{{
  call s:proc.stdin.write("Quit.\n")
  call s:proc.waitpid()

  call s:start_coptop(a:is_silent)

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

  call coqdo#backward(s:curlinenr, 'n')
endfunction " }}}

function! coqdo#backward(linenr, mode) abort " {{{
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
  call s:async_run(input, 1, a:mode, s:bufnr)
endfunction " }}}

function! coqdo#msg_open() abort " {{{
  if !s:msgbufnr
    execute s:bufnr 'wincmd w'
    rightbelow new
    setlocal buftype=nofile noswapfile "TODO set other options
    let s:msgbufnr = winnr()
    execute s:mainbufnr 'wincmd w'
  endif
endfunction " }}}

function! coqdo#msg_close() abort " {{{
  if s:msgbufnr
    execute s:msgbufnr 'wincmd w'
    close
    let s:msgbufnr = 0
    execute s:mainbufnr 'wincmd w'
  endif
endfunction " }}}

function! coqdo#search_about(args) abort " {{{
  call coqdo#msg_open()
  let input = 'SearchAbout ' . a:args . '.' . "\n"
  call s:async_run(input, 0, 'n', s:msgbufnr)
endfunction " }}}

function! coqdo#check(args) abort " {{{
  call coqdo#msg_open()
  let input = 'Check ' . a:args . '.' . "\n"
  call s:async_run(input, 0, 'n', s:msgbufnr)
endfunction " }}}

function! coqdo#print(args) abort " {{{
  call coqdo#msg_open()
  let input = 'Print ' . a:args . '.' . "\n"
  call s:async_run(input, 0, 'n', s:msgbufnr)
endfunction " }}}

let &cpo = s:save_cpo
unlet s:save_cpo
