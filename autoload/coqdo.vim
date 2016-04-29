let s:save_cpo = &cpo
set cpo&vim

let s:oldlinenr = 0
let s:curlinenr = 0
let s:match_id  = 0

function! coqdo#start() abort " {{{
  if !executable('coqtop')
    let msg = 'cannot execute coqtop'
    echohl ErrorMsg | echo msg | echohl None
    finish
  endif

  " TODO error print: if vimproc do not exist.

  let s:proc = vimproc#popen2('coqtop')

  rightbelow vnew
  let s:bufnr = bufnr('%')
  setlocal buftype=nofile noswapfile "TODO set other options
  wincmd p

  let message_list = s:read_messages()
  call s:print_message(message_list)

  command! -buffer CoqdoQuit call s:quit()
  command! -buffer CoqdoGoto call s:goto(<line2>)
  command! -buffer CoqdoClear call s:clear(0)
  command! -buffer CoqdoForward call s:forward()
  command! -buffer CoqdoBackward call s:backward_one()

  nnoremap <buffer> <silent> <LocalLeader>q :<C-u>CoqdoQuit<CR>
  nnoremap <buffer> <silent> <LocalLeader>g :<C-u>CoqdoGoto<CR>
  nnoremap <buffer> <silent> <LocalLeader>c :<C-u>CoqdoClear<CR>
  nnoremap <buffer> <silent> <LocalLeader>j :<C-u>CoqdoForward<CR>
  nnoremap <buffer> <silent> <LocalLeader>k :<C-u>CoqdoBackward<CR>

  augroup Coqdo
    autocmd!
    autocmd InsertEnter <buffer> call s:backward(line('.'))
  augroup END

  hi def link coqdoEndLine Folded
endfunction "}}}

function! s:read_messages() abort " {{{
  let message_list = []
  let buf = ''
  while 1
    if match(buf, '\(.\+ < \)\+$') != -1
      let buf = s:proc.stdout.read(-1, 100)
      if empty(buf)
        break
      endif
    else
      let buf = s:proc.stdout.read(-1, 100)
    endif

    let buflist = split(buf, '[[:cntrl:]]')
    " TODO 'theorem_name < theorem_name < fst' => 'fst'
    call map(buflist, "matchstr(v:val, '\\(\\(Coq < \\)*\\)\\zs.\\+')")
    call filter(buflist, "match(v:val, '.\\+ < ') == -1")
    call extend(message_list, buflist)
  endwhile

  return message_list
endfunction " }}}

function! s:print_message(lines) abort " {{{
  let winnr = winnr()
  execute bufwinnr(s:bufnr) 'wincmd w'
  silent %delete _
  call setline(1, a:lines)
  execute winnr 'wincmd w'
endfunction " }}}

function! s:quit() abort " {{{
  call s:proc.stdin.write("Quit.\n")
  call s:proc.waitpid()

  let winnr = bufwinnr(s:bufnr)
  let curwinnr = winnr()
  execute winnr 'wincmd w'
  close
  execute curwinnr 'wincmd w'
endfunction " }}}

function! s:goto(linenr) abort " {{{
  if a:linenr < s:curlinenr
    return
  endif

  let s:oldlinenr = s:curlinenr
  let s:curlinenr = a:linenr

  let line = getline(s:oldlinenr+1, a:linenr)
  let input = join(line, "\n") . "\n"
  call s:proc.stdin.write(input)
  let output = s:read_messages()
  call s:print_message(output)

  if s:match_id > 0
    call matchdelete(s:match_id)
  endif
  let s:match_id = matchadd('coqdoEndLine', '\%' . s:curlinenr . 'l')
endfunction " }}}

function! s:clear(is_silent) abort " {{{
  call s:proc.stdin.write("Quit.\n")
  call s:proc.waitpid()

  let s:proc = vimproc#popen2('coqtop')

  let s:oldlinenr = 0
  let s:curlinenr = 0

  let message_list = s:read_messages()
  if !a:is_silent
    call s:print_message(message_list)
  endif

  if s:match_id > 0
    let s:match_id = matchdelete(s:match_id)
  endif
endfunction " }}}

function! s:forward() abort " {{{
  if s:curlinenr == line('$')
    return
  endif

  call s:goto(s:curlinenr + 1)
endfunction " }}}

function! s:backward_one() abort " {{{
  if s:curlinenr == 0
    return
  endif

  call s:backward(s:curlinenr)
endfunction " }}}

function! s:backward(linenr) abort " {{{
  if a:linenr > s:curlinenr
    return
  endif

  call s:clear(1)

  let s:curlinenr = a:linenr - 1 " TODO how do a:linenr = 0 ?
  if s:match_id > 0
    call matchdelete(s:match_id)
  endif
  let s:match_id = matchadd('coqdoEndLine', '\%' . s:curlinenr . 'l')

  let line = getline(s:oldlinenr+1, s:curlinenr)
  let input = join(line, "\n") . "\n"
  call s:proc.stdin.write(input)
  let output = s:read_messages()
endfunction " }}}

let &cpo = s:save_cpo
unlet s:save_cpo
