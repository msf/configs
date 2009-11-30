function <SID>PythonGrep(tool)
  set lazyredraw
  " Close any existing cwindows.
  cclose
  let l:grepformat_save = &grepformat
  let l:grepprogram_save = &grepprg
  set grepformat&vim
  set grepformat&vim
  let &grepformat = '%f:%l:%m'
  if a:tool == "pylint"
    let &grepprg = 'pylint --output-format=parseable --reports=n'
  elseif a:tool == "pychecker"
    let &grepprg = 'pychecker --quiet -q'
  else
    echohl WarningMsg
    echo "PythonGrep Error: Unknown Tool"
    echohl none
  endif
  if &readonly == 0 | update | endif
  silent! grep! %
  let &grepformat = l:grepformat_save
  let &grepprg = l:grepprogram_save
  let l:mod_total = 0
  let l:win_count = 1
  " Determine correct window height
  windo let l:win_count = l:win_count + 1
  if l:win_count <= 2 | let l:win_count = 4 | endif
  windo let l:mod_total = l:mod_total + winheight(0)/l:win_count |
        \ execute 'resize +'.l:mod_total
  " Open cwindow
  execute 'belowright copen '.l:mod_total
  nnoremap <buffer> <silent> c :cclose<CR>
  set nolazyredraw
  redraw!
endfunction

if ( !hasmapto('<SID>PythonGrep(pylint)') && (maparg('<F3>') == '') )
  map <F3> :call <SID>PythonGrep('pylint')<CR>
  map! <F3> :call <SID>PythonGrep('pylint')<CR>
else
  if ( !has("gui_running") || has("win32") )
    echo "Python Pylint Error: No Key mapped.\n".
          \ "<F3> is taken and a replacement was not assigned."
  endif
endif

if ( !hasmapto('<SID>PythonGrep(pychecker)') && (maparg('<F4>') == '') )
  map <F4> :call <SID>PythonGrep('pychecker')<CR>
  map! <F4> :call <SID>PythonGrep('pychecker')<CR>
else
  if ( !has("gui_running") || has("win32") )
    echo "Python Pychecker Error: No Key mapped.\n".
          \ "<F8> is taken and a replacement was not assigned."
  endif
endif


