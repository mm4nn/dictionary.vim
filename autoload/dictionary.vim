" =============================================================================
" Filename: autoload/dictionary.vim
" Version: 0.0
" Author: itchyny
" License: MIT License
" Last Change: 2013/08/23 19:51:38.
" =============================================================================

let s:save_cpo = &cpo
set cpo&vim

let s:path = expand('<sfile>:p:h')
let s:mfile = printf('%s/dictionary.m', s:path)
let s:exepath = substitute(get(g:, 'dictionary_executable_path', s:path), '/*$', '', '')
let s:exename = get(g:, 'dictionary_executable_name', 'dictionary')
let s:exe = expand(printf('%s/%s', s:exepath, s:exename))
let s:gccdefault = executable('llvm-gcc') ? 'llvm-gcc' : 'gcc'
let s:gcc = get(g:, 'dictionary_compile_command', s:gccdefault)
let s:optdefault = '-O3 -framework CoreServices -framework Foundation'
let s:opt = get(g:, 'dictionary_compile_option', s:optdefault)
try
  if !executable(s:exe) || getftime(s:exe) < getftime(s:mfile)
    if executable(s:gcc)
      call vimproc#system(printf('%s -o %s %s %s &', s:gcc, s:exe, s:opt, s:mfile))
    endif
  endif
catch
endtry

function! dictionary#new(args)
  if s:check_mac() | return | endif
  if s:check_exe() | call s:check_vimproc() | return | endif
  if s:check_vimproc() | return | endif
  let [isnewbuffer, command, words] = s:parse(a:args)
  try | silent execute command | catch | return | endtry
  call setline(1, join(words, ' '))
  call cursor(1, 1)
  startinsert!
  call s:au()
  call s:map()
  call s:initdict()
  setlocal buftype=nofile noswapfile
        \ bufhidden=hide nobuflisted nofoldenable foldcolumn=0
        \ nolist wrap completefunc= omnifunc=
        \ filetype=dictionary
endfunction

function! s:parse(args)
  let args = split(a:args, '\s\+')
  let isnewbuffer = bufname('%') != '' || &l:filetype != '' || &modified
        \ || winheight(0) > 9 * &lines / 10
  let command = 'new'
  let below = ''
  let words = []
  for arg in args
    if arg =~? '^-*horizontal$'
      let command = 'new'
      let isnewbuffer = 1
    elseif arg =~? '^-*vertical$'
      let command = 'vnew'
      let isnewbuffer = 1
    elseif arg =~? '^-*here$'
      let command = 'try | enew | catch | tabnew | endtry'
    elseif arg =~? '^-*here!$'
      let command = 'enew!'
    elseif arg =~? '^-*newtab$'
      let command = 'tabnew'
      let isnewbuffer = 1
    elseif arg =~? '^-*below$'
      if command == 'tabnew'
        let command = 'new'
      endif
      let below = 'below '
    elseif arg =~? '^-*cursor-word$'
      let words = [s:cursorword()]
    else
      call add(words, arg)
    endif
  endfor
  let command = 'if isnewbuffer | ' . below . command . ' | endif'
  return [isnewbuffer, command, words]
endfunction

function! s:au()
  augroup Dictionary
    autocmd CursorMovedI <buffer> call s:update()
    autocmd CursorHoldI <buffer> call s:check()
    autocmd BufLeave <buffer> call s:restore()
    autocmd BufEnter <buffer> call s:updatetime()
  augroup END
endfunction

function! s:initdict()
  let b:dictionary = { 'input': '', 'history': [],
        \ 'jump_history': [], 'jump_history_index': 0 }
endfunction

function! s:update()
  setlocal completefunc= omnifunc=
  let word = getline(1)
  if exists('b:dictionary.proc')
    call s:check()
    try
      call b:dictionary.proc.kill(15)
      call b:dictionary.proc.waitpid()
    catch
    endtry
  endif
  try
    let b:dictionary.proc = vimproc#pgroup_open(printf('%s "%s"', s:exe, word))
    call b:dictionary.proc.stdin.close()
    call b:dictionary.proc.stderr.close()
  catch
    if !exists('b:dictionary')
      call s:initdict()
    endif
  endtry
  call s:updatetime()
endfunction

function! s:void()
  silent call feedkeys(mode() ==# 'i' ? "\<C-g>\<ESC>" : "g\<ESC>", 'n')
endfunction

function! s:check()
  try
    if !exists('b:dictionary.proc') || b:dictionary.proc.stdout.eof
      return
    endif
    let result = split(b:dictionary.proc.stdout.read(), "\n")
    let word = getline(1)
    let newword = substitute(word, ' $', '', '')
    if len(result) == 0 && b:dictionary.input ==# newword && newword !=# ''
      call s:void()
      return
    endif
    let b:dictionary.input = newword
    let curpos = getpos('.')
    silent % delete _
    call setline(1, word)
    call setline(2, result)
    try
      call b:dictionary.proc.stdout.close()
      call b:dictionary.proc.stderr.close()
      call b:dictionary.proc.waitpid()
    catch
    endtry
    unlet b:dictionary.proc
    call cursor(1, 1)
    startinsert!
    if curpos[1] == 1
      call setpos('.', curpos)
    endif
  catch
  endtry
endfunction

function! s:updatetime()
  if !exists('s:updatetime')
    let s:updatetime = &updatetime
  endif
  set updatetime=50
endfunction

function! s:restore()
  try
    if exists('s:updatetime')
      let &updatetime = s:updatetime
    endif
    unlet s:updatetime
  catch
  endtry
endfunction

function! s:map()
  if &l:filetype ==# 'dictionary'
    return
  endif
  nnoremap <buffer><silent> <Plug>(dictionary_jump)
        \ :<C-u>call <SID>jump()<CR>
  nnoremap <buffer><silent> <Plug>(dictionary_jump_back)
        \ :<C-u>call <SID>back()<CR>
  nnoremap <buffer><silent> <Plug>(dictionary_exit)
        \ :<C-u>bdelete!<CR>
  inoremap <buffer><silent> <Plug>(dictionary_nop)
        \ <Nop>
  nmap <buffer> <C-]> <Plug>(dictionary_jump)
  nmap <buffer> <C-t> <Plug>(dictionary_jump_back)
  nmap <buffer> q <Plug>(dictionary_exit)
  imap <buffer> <CR> <Plug>(dictionary_nop)
endfunction

function! s:with(word)
  call setline(1, a:word)
  call cursor(1, 1)
  startinsert!
  let curpos = getpos('.')
  if curpos[1] == 1
    call setpos('.', curpos)
  endif
endfunction

function! s:jump()
  try
    let prev_word = substitute(getline(1), ' $', '', '')
    call insert(b:dictionary.jump_history, prev_word, b:dictionary.jump_history_index)
    let b:dictionary.jump_history_index += 1
    let word = s:cursorword()
    call s:with(word)
  catch
    call s:with('')
  endtry
endfunction

function! s:back()
  try
    if len(b:dictionary.jump_history) && b:dictionary.jump_history_index
      let b:dictionary.jump_history_index -= max([v:count, 1])
      let b:dictionary.jump_history_index = max([b:dictionary.jump_history_index, 0])
      call s:with(b:dictionary.jump_history[b:dictionary.jump_history_index])
    else
      call s:with('')
    endif
  catch
    call s:with('')
  endtry
endfunction

function! s:cursorword()
  try
    let curpos = getpos('.')
    let c = curpos[2]
    let line = split(getline(curpos[1]), '\<\|\>')
    let i = 0
    while c > 0 && i < len(line)
      let c -= strlen(line[i])
      let i += 1
    endwhile
    if i > len(line)
      let i -= 1
    elseif i < 1
      let i += 1
    endif
    if line[i - 1] =~# '^[=()\[\]{}.,; :#<>/"]'
      if i < len(line) | let i += 1 | else | let i -= 1 | endif
    endif
    return line[max([0, i - 1])]
  catch
    return ''
  endtry
endfunction

function! s:error(msg)
  echohl ErrorMsg
  echomsg 'dictionary.vim: '.a:msg
  echohl None
endfunction

function! s:check_mac()
  if !(has('mac') || has('macunix') || has('guimacvim'))
    call s:error('Mac is required.')
    return 1
  endif
  return 0
endfunction

function! s:check_exe()
  if !executable(s:exe)
    call s:error('The dictionary executable is not created.')
    try
      if executable(s:gcc)
        call vimproc#system(printf('%s -o %s %s %s &', s:gcc, s:exe, s:opt, s:mfile))
      endif
    catch
    endtry
    if !exists('g:dictionary_compile_option') && !executable('gcc')
      call s:error('gcc is not available. (This plugin requires gcc.)')
    endif
    return 1
  endif
  return 0
endfunction

function! s:check_vimproc()
  if !exists('*vimproc#pgroup_open')
    call s:error('vimproc is not found.')
    return 1
  endif
  return 0
endfunction

let &cpo = s:save_cpo
unlet s:save_cpo