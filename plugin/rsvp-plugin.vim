
" Reload guard and 'compatible' handling
"if exists("loaded_rsvp") | finish | endif

let loaded_rsvp = 1

let s:save_cpo = &cpo
set cpo&vim

command! RsvpGo  call rsvp#Go()
command! -nargs=1 RsvpWait call rsvp#SetBaseWaitMsec(<f-args>)

" TODO: move to vimrc
nnoremap <leader>w :RsvpGo<CR>
nnoremap <leader>q :source %<CR>

" Cleanup and modelines
let &cpo = s:save_cpo

