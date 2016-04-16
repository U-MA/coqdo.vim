let s:save_cpo = &cpo
set cpo&vim

command! Coqdo call coqdo#start()

let &cpo = s:save_cpo
unlet s:save_cpo
