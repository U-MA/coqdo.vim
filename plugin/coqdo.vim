let s:save_cpo = &cpo
set cpo&vim

command! Coqdo call s:setup()

function! s:setup() abort " {{{
  if exists('g:coqdo_started')
    let msg = 'Coqdo is already started'
    echohl ErrorMsg | echo msg | echohl None
    return
  endif

  let g:coqdo_started = 1

  " Check coqtop command {{{
  if !executable('coqtop')
    let msg = 'cannot execute coqtop'
    echohl ErrorMsg | echo msg | echohl None
    return
  end " }}}

  " Check vimproc {{{
  try
    call vimproc#version()
  catch
    let msg = 'Coqdo uses vimproc. You need to install vimproc!!'
    echohl ErrorMsg | echo msg | echohl None
    return
  endtry " }}}

  " Set command {{{
  command! -buffer CoqdoQuit call coqdo#quit()
  command! -buffer CoqdoGoto call coqdo#goto(<line2>)
  command! -buffer CoqdoClear call coqdo#clear(0)
  command! -buffer CoqdoForward call coqdo#forward()
  command! -buffer CoqdoBackward call coqdo#backward_one()
  command! -buffer CoqdoMsgClose call coqdo#msg_close()
  command! -buffer -nargs=1 CoqdoSearchAbout call coqdo#search_about(<args>)
  command! -buffer -nargs=1 CoqdoCheck call coqdo#check(<args>)
  command! -buffer -nargs=1 CoqdoPrint call coqdo#print(<args>)
  " }}}

  " Set map {{{
  if exists('g:coqdo_default_key_mapping')
    nnoremap <buffer> <silent> <LocalLeader>q :<C-u>CoqdoQuit<CR>
    nnoremap <buffer> <silent> <LocalLeader>g :<C-u>CoqdoGoto<CR>
    nnoremap <buffer> <silent> <LocalLeader>c :<C-u>CoqdoClear<CR>
    nnoremap <buffer> <silent> <LocalLeader>j :<C-u>CoqdoForward<CR>
    nnoremap <buffer> <silent> <LocalLeader>k :<C-u>CoqdoBackward<CR>
  endif
  " }}}

  augroup Coqdo
    autocmd!
    autocmd InsertEnter <buffer> call coqdo#backward(line('.'), 'i')
  augroup END

  hi def link coqdoEndLine Folded

  call coqdo#start()
endfunction " }}}

let &cpo = s:save_cpo
unlet s:save_cpo
