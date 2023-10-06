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


function! matchup#perf#timeout() " {{{1
  return luaeval('require"matchup.perf".timeout()')
endfunction

"}}}1
function! matchup#perf#timeout_start(timeout) " {{{1
  return luaeval('require"matchup.perf".timeout_start(_A)', a:timeout)
endfunction

" }}}1
function! matchup#perf#timeout_check() " {{{1
  return luaeval('require"matchup.perf".timeout_check()')
endfunction



" function! s:reltimefloat(time) {{{1
if exists('*reltimefloat')
  let s:Reltimefloat = function('reltimefloat')
else
  function! s:Reltimefloat(time)
    return str2float(reltimestr(a:time))
  endfunction
endif

" }}}1

let &cpo = s:save_cpo

" vim: fdm=marker sw=2

