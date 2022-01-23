
" Reload guard and 'compatible' handling
if exists("loaded_rsvp") | finish | endif

let loaded_rsvp = 1

let s:save_cpo = &cpo
set cpo&vim

command! RsvpOn  call rsvp#On()
command! RsvpOff call rsvp#Off()
command! RsvpTog call rsvp#Tog()

" TODO: param
command! RsvpWpm call rsvp#Wpm()

" TODO: move to vimrc
nnoremap <leader>w :RsvpTog<CR>
nnoremap <leader>q :source %<CR>

" Cleanup and modelines
let &cpo = s:save_cpo

