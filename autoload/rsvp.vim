let s:keepcpo = &cpo
set cpo&vim

"
" MW-RSVP (Moving Window Rapid Serial Visual Presentation)
" longer pauses @ end of clauses & sentences
" color center letter & different color for ending punctuation
" shirah waits additional 0.2s for period, 0.15s for common punctuation
"
" https://cl.lingfil.uu.se/exarb/arch/2001-009.pdf


const s:DEFAULT_WPM = 300


" ---------------------------  DEBUG HELPERS  ---------------------------


function! s:WriteDebugBuf(object)

  let nt = type(a:object)
  let sz_msg = ""
  if (nt == v:t_string) || (nt == v:t_float) || (nt == v:t_number)
    let sz_msg = string(a:object)
  else
    let sz_msg = js_encode(a:object)
  endif

  call writefile([sz_msg], "./rsvp.log", "as")

endfunction


function! s:Cleanup(b_restoretab)

	if rsvp#IsOn()
		call s:WriteDebugBuf('cleanup')
	endif

	if exists('s:timer_id')
		call timer_stop(s:timer_id)
		unlet s:timer_id
	endif

	if exists('s:win_nr')
		call popup_close(s:win_nr)
		unlet s:win_nr
	endif

	if exists('s:buf_nr')
		unlet s:buf_nr
	endif

	if exists('s:tab_nr')

		" CLOSE BLANK BUFFER / NEW TAB FOR RSVP
		let l_bufs = tabpagebuflist(s:tab_nr)
		if len(l_bufs) == 1
			execute 'noautocmd bdelete ' . string(l_bufs[0])
		endif

		" RETURN TO ORIGINAL TAB
		if a:b_restoretab
			execute 'noautocmd ' . string(s:cur_tab) . 'tabnext'
			execute 'noautocmd normal zz'
		endif

		unlet s:tab_nr
		unlet s:cur_tab

	endif

endfunction


function! s:TimeFunc(target_wpm, word)

	" time1 = (nwrd+nchr)/(davg*wpm/60)
	" func(wpm, word) : display time (msec)
	" wait longer for '?' ???
	"
	" SHIRAH
	" t_wait_sec = (1 / wps) * (1 + syllables.estimate(word) ** 2 / 100)
	" shirah waits additional 0.2s for period, 0.15s for common punctuation

	" TODO: time func

	return 100

endfunction


function! s:UpdateText(...)

	if !exists('s:win_nr') | return | endif

	" GET BUFFER'S WINDOW FOR NORMAL MODE COMMANDS
	let bufwin = win_findbuf(s:buf_nr)
	if empty(bufwin) | return | endif

	let next_word = ''
	let l_prev = getcurpos(bufwin[0])

	" LOOP TO NEXT NON-EMPTY WORD
	while 1

		" YANK NEXT WORD INTO REGISTER r
		call win_execute(bufwin[0], 'noautocmd normal! "ryW', 'silent')
		let next_word = trim(@r)

		" MOVE TO NEXT WORD
		call win_execute(bufwin[0], 'noautocmd normal! W', 'silent')

		" EXIT ON EOF
		let l_next = getcurpos(bufwin[0])
		if l_next == l_prev
			call popup_settext(s:win_nr, '> END <')
			return
		endif
		let l_prev = l_next

		" END LOOP ON FIRST NON-EMPTY WORD
		if len(next_word) > 0 | break | endif

	endwhile

	" SET POPUP TEXT
	call s:WriteDebugBuf(next_word)

	" HIGHLIGHT PUNCTUATION
	const PUNCT = '[[:punct:]]\+'
	let l_props = []
	let l_match = matchstrpos(next_word, PUNCT)
	while l_match[1] > -1

		call s:WriteDebugBuf(l_match)
		call add(l_props, {
	 			\ 'col': l_match[1] + 1,
	 			\ 'length': l_match[2] - l_match[1],
	 			\ 'type': 'pt_rsvp',
	 			\ })

		let l_match = matchstrpos(next_word, PUNCT, l_match[2])

	endwhile

	call popup_settext(s:win_nr, [{ 'text': next_word, 'props': l_props }])

	" UPDATE WINDOW PADDING
	let pad_v = (&lines - 10) / 2
	let pad_h = (&columns - strdisplaywidth(next_word) - 10)
	let odd = pad_h % 2
	let pad_h = pad_h / 2
  let d_cfg = { 'padding': [pad_v, pad_h, pad_v, pad_h + odd] }
	call popup_setoptions(s:win_nr, d_cfg)

	" SET TIMER FOR NEXT WORD
	let msec = s:TimeFuncref(s:rsvp_wpm, next_word)
	if msec < 10 | let msec = 10 | endif
  let s:timer_id = timer_start(msec, funcref('s:UpdateText'))

endfunction


" ---------------------------  EXPOSED COMMANDS  ---------------------------


function! rsvp#On()

  let s:buf_nr = bufnr()
	let s:cur_tab = tabpagenr()

	if exists('g:rsvp_time_func')
		let s:TimeFuncref = function('g:rsvp_time_func')
	else
		let s:TimeFuncref = function('s:TimeFunc')
	endif

	" TODO: parameterize punctuation highlight
	" CREATE PUNCTUATION TEXTPROP TYPE
	call prop_type_delete('pt_rsvp')
	call prop_type_add('pt_rsvp', { 'highlight': 'NonText' })

	" CREATE NEW TAB FOR RSVP
	execute 'noautocmd $tabnew'
	let s:tab_nr = tabpagenr('$')

	" TODO: quick keys - speed control

	" BEGIN
  let d_cfg = {
        \ 'drag': 0,
        \ 'scrollbar': 0,
        \ 'close': 'none',
				\ 'tabpage': s:tab_nr,
				\ 'border': [],
        \ }

	if exists('g:rsvp_popup_highlight') && (type(g:rsvp_popup_highlight) == v:t_string)
		let d_cfg['highlight'] = g:rsvp_popup_highlight
	endif

  let s:win_nr = popup_create('', d_cfg)
	call s:UpdateText()

	" PAUSE ON TAB SWITCH
	augroup RSVP
		autocmd!
		autocmd TabEnter * call s:Cleanup(0)
	augroup END

endfunction


function! rsvp#IsOn()
  return exists('s:win_nr')
endfunction


function! rsvp#Off()
  call s:Cleanup(1)
endfunction


function! rsvp#Tog()
  if rsvp#IsOn()
    call rsvp#Off()
  else
    call rsvp#On()
  endif
endfunction


function! rsvp#Wpm(val)
  let s:rsvp_wpm = str2nr(a:val)
	if s:rsvp_wpm < 1
		let s:rsvp_wpm = s:DEFAULT_WPM
	endif
endfunction


" ---------------------------  SETUP  ---------------------------


" TODO: helptext
" TODO: add to my vimrc, remove here
let g:rsvp_popup_highlight = 'DiffAdd'


if exists('g:rsvp_wpm')
	call rsvp#Wpm(g:rsvp_wpm)
else
	call rsvp#Wpm(s:DEFAULT_WPM)
endif


" Restoration and modelines
let &cpo = s:keepcpo
unlet s:keepcpo

