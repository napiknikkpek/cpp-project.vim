
augroup project
  autocmd!
  autocmd FileType c,cpp call project#update_buffer()
augroup END
