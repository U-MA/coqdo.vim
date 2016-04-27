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
  command! -buffer CoqdoClear call s:clear()

  nnoremap <buffer> <silent> <LocalLeader>q :<C-u>CoqdoQuit<CR>
  nnoremap <buffer> <silent> <LocalLeader>g :<C-u>CoqdoGoto<CR>
  nnoremap <buffer> <silent> <LocalLeader>c :<C-u>CoqdoClear<CR>

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

function! s:clear() abort " {{{
  call s:proc.stdin.write("Quit.\n")
  call s:proc.waitpid()

  let s:proc = vimproc#popen2('coqtop')

  let s:oldlinenr = 0
  let s:curlinenr = 0

  let message_list = s:read_messages()
  call s:print_message(message_list)

  if s:match_id > 0
    let s:match_id = matchdelete(s:match_id)
  endif
endfunction " }}}

let &cpo = s:save_cpo
unlet s:save_cpo
