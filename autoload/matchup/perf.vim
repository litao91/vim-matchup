" vim match-up - even better matching
"
" Maintainer: Andy Massimino
" Email:      a@normed.space
"

let s:save_cpo = &cpo
set cpo&vim

let s:time_start = {}
let s:alpha = 2.0/(10+1)

let g:matchup#perf#times = {}

function! matchup#perf#tic(context)
  call luaeval('require"matchup.perf".tic(_A[1])', [a:context])
endfunction

function! matchup#perf#toc(context, state)
  call luaeval('require"matchup.perf".toc(_A[1], _A[2])', [a:context, a:state])
endfunction

let s:timeout = 0
let s:timeout_enabled = 0
let s:timeout_pulse_time = reltime()

function! matchup#perf#timeout() " {{{1
  return float2nr(s:timeout)
endfunction

"}}}1
function! matchup#perf#timeout_start(timeout) " {{{1
  let s:timeout = a:timeout
  let s:timeout_enabled = (a:timeout == 0) ? 0 : 1
  let s:timeout_pulse_time = reltime()
endfunction

" }}}1
function! matchup#perf#timeout_check() " {{{1
  if !s:timeout_enabled | return 0 | endif
  let l:elapsed = 1000.0 * s:Reltimefloat(reltime(s:timeout_pulse_time))
  let s:timeout -= l:elapsed
  let s:timeout_pulse_time = reltime()
  return s:timeout <= 0.0
endfunction

" }}}1

let &cpo = s:save_cpo

" vim: fdm=marker sw=2

