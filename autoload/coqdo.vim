let s:save_cpo = &cpo
set cpo&vim

let s:curlinenr = 0

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

  nnoremap <buffer> <silent> <LocalLeader>q :<C-u>CoqdoQuit<CR>
  nnoremap <buffer> <silent> <LocalLeader>g :<C-u>CoqdoGoto<CR>
endfunction "}}}

function! s:read_messages() abort " {{{
  let all = ''
  let buf = '>'
  while !empty(buf)
    let buf = s:proc.stdout.read(-1, 100)
    if match(buf, "^Coq <") == -1
      let all .= buf
    endif
  endwhile
  let message = split(all, "[[:cntrl:]]")
  return message[:len(message)-2]
endfunction " }}}

function! s:print_message(lines) abort " {{{
  let winnr = winnr()
  execute bufwinnr(s:bufnr) 'wincmd w'
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

  let s:curlinenr = a:linenr

  let line = getline(0, a:linenr)
  let input = join(line, "\n") . "\n"
  call s:proc.stdin.write(input)
  let output = s:read_messages()
  call s:print_message(output)
endfunction " }}}

let &cpo = s:save_cpo
unlet s:save_cpo
