"
"     Title: MW-RSVP (Moving Window Rapid Serial Visual Presentation)
"    Author: Jason Stewart <support@eggplantsd.com>
"  Modified: 24 Jan 2022
" Copyright: 2022
"   License: MIT
"
"

let s:keepcpo = &cpo
set cpo&vim


" ---------------------------  DEBUG HELPER  ---------------------------


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


" ---------------------------  /DEBUG HELPER  ---------------------------


function! s:TimeFunc(basewait_msec, phrase)

	" ADDITIONAL 50% FOR END OF SENTENCE
	if len(a:phrase) == 0
		return (a:basewait_msec * 15) / 10
	endif

	" ADDITIONAL 20% FOR OTHER PUNCTUATION
	let ix = match(a:phrase, '[[:punct:]]')
	if ix > -1
		return (a:basewait_msec * 12) / 10
	endif

	return a:basewait_msec

endfunction


function! s:GetCurWord(bufwin_id)
	call win_execute(a:bufwin_id, 'noautocmd normal "ryW', 'silent')
	return trim(@r)
endfunction


function! s:GetNextWord(bufwin_id)

	let next_word = ''
	let l_prev = getcurpos(a:bufwin_id)

	" LOOP TO NEXT NON-EMPTY WORD
	while 1

		let next_word = s:GetCurWord(a:bufwin_id)

		" MOVE TO NEXT WORD
		call win_execute(a:bufwin_id, 'noautocmd normal W', 'silent')

		" EXIT ON EOF
		let l_next = getcurpos(a:bufwin_id)
		if l_next == l_prev
			return -1
		endif
		let l_prev = l_next

		" END LOOP ON FIRST NON-EMPTY WORD
		if len(next_word) > 0 | break | endif

	endwhile

	return next_word

endfunction


function! s:RefreshPopup(next_word)

	" TODO: l/r word padding
	" TODO: highlight centroid

	" HIGHLIGHT PUNCTUATION
	let l_props = []
	let d_prop = prop_type_get('pt_rsvp')
	if !empty(d_prop) && (len(a:next_word) > 0)

		const RX_PUNCT = '[[:punct:]]\+'
		let iend = 0
		while 1

			let [mstr, istart, iend] = matchstrpos(a:next_word, RX_PUNCT, iend)
			if istart < 0 | break | endif

			call add(l_props, {
					\ 'col': istart + 1,
					\ 'length': iend - istart,
					\ 'type': 'pt_rsvp',
					\ })

		endwhile

	endif

	" DISPLAY TEXT
	call popup_settext(s:win_nr, [{ 'text': a:next_word, 'props': l_props }])

	" UPDATE PADDING
	let pad_v = (&lines - 10) / 2
	let pad_h = (&columns - 10 - strdisplaywidth(a:next_word))
	let odd   = pad_h % 2
	let pad_h = pad_h / 2
  let d_cfg = { 'padding': [pad_v, pad_h, pad_v, pad_h + odd] }
	call popup_setoptions(s:win_nr, d_cfg)

endfunction


function! s:PresentEndSentence(...)

	" NOTE: single space to work around popup/padding
	" interaction with empty string
	call s:RefreshPopup(' ')

	" GET/SET TIMER FOR END OF SENTENCE
	let msec = s:TimeFuncref(s:GetBasewaitMsec(), '')
	if msec < 10 | let msec = 10 | endif
	let s:timer_id = timer_start(msec, funcref('s:PresentNextTimer'))

endfunction


function! s:PresentNextTimer(tid)
	call s:PresentNext(1)
endfunction


function! s:PresentNext(b_set_timer)

	if !exists('s:win_nr') | return | endif

	" GET BUFFER'S WINDOW FOR NORMAL MODE COMMANDS
	let bufwin = win_findbuf(s:buf_nr)
	if empty(bufwin) | return | endif

	" ADVANCE CURSOR & GET NEXT NON-EMPTY WORD IN TIMER MODE,
	" OTHERWISE, GET CURRENT WORD & LEAVE CURSOR ALONE
	let word = ''
	if a:b_set_timer
		let word = s:GetNextWord(bufwin[0])
	else
		let word = s:GetCurWord(bufwin[0])
	endif

	if type(word) != v:t_string
		call popup_settext(s:win_nr, '> END <')
		return
	endif

	" DRAW
	call s:RefreshPopup(word)

	if !a:b_set_timer | return | endif

	" GET TIMER FOR WORD
	let msec = s:TimeFuncref(s:GetBasewaitMsec(), word)
	if msec < 10 | let msec = 10 | endif

	let ix = match(word, '[.?!;]$')
	if ix > -1

		" BLANK SCREEN AFTER SENTENCE
		let s:timer_id = timer_start(msec, funcref('s:PresentEndSentence'))

	else

		" SET TIMER FOR WORD
		let s:timer_id = timer_start(msec, funcref('s:PresentNextTimer'))

	endif

endfunction


function! s:IsOn()
  return exists('s:win_nr')
endfunction


function! s:IsPaused()
	return !exists('s:timer_id')
endfunction


function! s:TogglePause()

	if s:IsPaused()

		call s:PresentNext(1)

	else

		call timer_stop(s:timer_id)
		unlet s:timer_id

		" REWIND CURSOR
		let bufwin = win_findbuf(s:buf_nr)
		if !empty(bufwin)
			call win_execute(bufwin[0], 'noautocmd normal B', 'silent')
			call s:PresentNext(0)
		endif

	endif

	call s:HelpMsg()

endfunction


function! s:HelpMsg()
	if s:IsPaused()
		echomsg "(w/l) next word, (h/b) prev word"
	else
		echomsg "(?)help, (p)ause/continue, (f)aster, (s)lower, <Esc>/(q)uit"
	endif
endfunction


function! s:PresentKeystroke(win_id, key)

	if !s:IsOn() | return 0 | endif

	if a:key ==? '?'
		call s:HelpMsg()
	elseif (a:key ==? 'p')
		call s:TogglePause()
	elseif a:key ==? 'f'
		call rsvp#SetBaseWaitMsec('-10')
	elseif a:key ==? 's'
		call rsvp#SetBaseWaitMsec('+10')
	elseif (a:key ==? 'q') || (a:key ==# "\<Esc>")
		call rsvp#Off()
	elseif !exists('s:timer_id')

		let motion = ''
		if (a:key ==# "\<Right>") || (a:key ==? 'l') || (a:key ==? 'w')
			let motion = 'W'
		elseif (a:key ==# "\<Left>") || (a:key ==? 'h') || (a:key ==? 'b')
			let motion = 'B'
		else
			return 1
		endif

		let bufwin = win_findbuf(s:buf_nr)
		if !empty(bufwin)
			call win_execute(bufwin[0], 'noautocmd normal ' . motion, 'silent')
			call s:PresentNext(0)
		endif

	endif

	return 1

endfunction


" ---------------------------  EXPOSED COMMANDS  ---------------------------


function! rsvp#Go()

  let s:buf_nr  = bufnr()
	let s:cur_tab = tabpagenr()
	let s:last_r  = @r
	let s:TimeFuncref = exists('g:rsvp_time_func') ?
				\ function('g:rsvp_time_func') : function('s:TimeFunc')

	" CREATE PUNCTUATION TEXTPROP TYPE
	call prop_type_delete('pt_rsvp')
	call prop_type_add('pt_rsvp', {
				\ 'highlight': s:GetHl('rsvp_emphasis_hl', s:DEFAULT_EMPHASIS_HL),
				\ })

	" CREATE NEW TAB FOR RSVP
	execute 'noautocmd $tabnew'
	let s:tab_nr = tabpagenr('$')

	" BEGIN
  let d_cfg = {
        \ 'drag': 0,
        \ 'scrollbar': 0,
        \ 'close': 'none',
				\ 'tabpage': s:tab_nr,
				\ 'border': [],
				\ 'highlight': s:GetHl('rsvp_popup_hl', s:DEFAULT_POPUP_HL),
				\ 'filter': function('s:PresentKeystroke'),
        \ }

  let s:win_nr = popup_create('', d_cfg)
	call s:PresentNext(1)
	call s:HelpMsg()

endfunction


function! rsvp#SetBaseWaitMsec(val)

	let mtch = matchlist(a:val, '\v^([+-]?)(\d+)')
	if len(mtch) < 3 | return | endif

	let n_new = str2nr(mtch[2])
	let n_msec = s:GetBasewaitMsec()

	if mtch[1] ==# '+'
		let n_msec += n_new
	elseif mtch[1] ==# '-'
		let n_msec -= n_new
	else
		let n_msec = n_new
	endif

	if n_msec < 10
		let n_msec = 10
	endif

	let g:rsvp_basewait_msec = n_msec
	echomsg string(n_msec) . 'msec wait'

endfunction


function! rsvp#Off()

	if s:IsOn()
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

	" CLOSE BLANK BUFFER / NEW TAB FOR RSVP
	if exists('s:tab_nr')
		let l_bufs = tabpagebuflist(s:tab_nr)
		if len(l_bufs) == 1
			execute 'noautocmd bdelete ' . string(l_bufs[0])
		endif
		unlet s:tab_nr
	endif

	" RETURN TO ORIGINAL TAB, VERTICALLY CENTER CURSOR
	if exists('s:cur_tab')
		execute 'noautocmd ' . string(s:cur_tab) . 'tabnext'
		execute 'noautocmd normal zz'
		unlet s:cur_tab
	endif

	" RESTORE ORIGINAL r REGISTER
	if exists('s:last_r')
		let @r = s:last_r
		unlet s:last_r
	endif

	" CLEAR HELP MESSAGE
	echomsg ""

endfunction


" ---------------------------  SETUP  ---------------------------


const s:DEFAULT_POPUP_HL      = 'DiffAdd'
const s:DEFAULT_EMPHASIS_HL   = 'NonText'
const s:DEFAULT_BASEWAIT_MSEC = 130

" TODO: asciicast
" TODO: documentation
" TODO: add popup_hl, emph_hl, wait_ms to my vimrc, remove here


function! s:GetBasewaitMsec()

	let ms = s:GetGlobal('rsvp_basewait_msec', v:t_number, s:DEFAULT_BASEWAIT_MSEC)
	if ms > 0
		return ms
	endif

	return s:DEFAULT_BASEWAIT_MSEC

endfunction


function! s:GetHl(key, default)

	let hl = s:GetGlobal(a:key, v:t_string, a:default)
	if hlexists(hl)
		return hl
	endif

	return a:default

endfunction


function! s:GetGlobal(key, type, default)

	let val = get(g:, a:key, a:default)
	if type(val) == a:type
		return val
	endif

	return a:default

endfunction


" Restoration and modelines
let &cpo = s:keepcpo
unlet s:keepcpo

