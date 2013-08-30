" =============================================================================
" Filename: plugin/dictionary.vim
" Version: 0.0
" Author: itchyny
" License: MIT License
" Last Change: 2013/08/31 02:05:20.
" =============================================================================

if exists('g:loaded_dictionary') && g:loaded_dictionary
  finish
endif

let s:save_cpo = &cpo
set cpo&vim

command! -nargs=* -complete=customlist,dictionary#complete
      \ Dictionary call dictionary#new(<q-args>)

let g:loaded_dictionary = 1

let &cpo = s:save_cpo
unlet s:save_cpo
