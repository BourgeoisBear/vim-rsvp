"
"     Title: MW-RSVP (Moving Window Rapid Serial Visual Presentation)
"    Author: Jason Stewart <support@eggplantsd.com>
"  Modified: 24 Jan 2022
" Copyright: 2022
"   License: MIT
"
"

" Reload guard and 'compatible' handling
if exists("loaded_rsvp") | finish | endif

if !has('textprop')
  echoerr 'vim-rsvp disabled: +textprop feature not found'
  finish
endif

if !has('popupwin')
  echoerr 'vim-rsvp disabled: +popupwin feature not found'
  finish
endif

let loaded_rsvp = 1

let s:save_cpo = &cpo
set cpo&vim

command! RsvpGo call rsvp#Go()
command! -nargs=? RsvpWait call rsvp#SetBaseWaitMsec(<f-args>)

" Cleanup and modelines
let &cpo = s:save_cpo

