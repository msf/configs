fun! <SID>StripTrailingWhitespaces()
    let l = line(".")
    let c = col(".")
    %s/\s\+$//e
    call cursor(l, c)
endfun

autocmd BufWritePre *.py :call <SID>StripTrailingWhitespaces()
autocmd BufWritePre *.pl :call <SID>StripTrailingWhitespaces()
autocmd BufWritePre *.pm :call <SID>StripTrailingWhitespaces()
autocmd BufWritePre *.c :call <SID>StripTrailingWhitespaces()
autocmd BufWritePre *.h :call <SID>StripTrailingWhitespaces()
