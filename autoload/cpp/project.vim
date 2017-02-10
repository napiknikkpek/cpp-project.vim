
if !exists('s:all')
  let s:all_tmpl = {'cc': '', 'current': '', 'projects': {}}
  let s:project_tmpl = {'files': {}, 'tags': '', 'path': ''}
  let s:all = deepcopy(s:all_tmpl)
endif

fu! s:normalize_command(dirname, command)
  return substitute(a:command, '\s\zs\a\+\S\+', a:dirname.'/\0', 'g')
endfu

fu! cpp#project#set(cc) abort
  let db = len(a:cc)!=0 ? json_decode(join(readfile(a:cc), '')) : []

  let s:all = deepcopy(s:all_tmpl)
  for x in db
    if !has_key(s:all.projects, x.directory)
      let proj = deepcopy(s:project_tmpl)
      let proj.tags = x.directory . '/tags'
      let s:all.projects[x.directory] = proj
    endif
    let s:all.projects[x.directory].files[x.file] = 
          \s:normalize_command(x.directory, x.command)
  endfor
  let s:all.cc = a:cc
endfu

fu! cpp#project#update() abort
  let cur = s:all.current
  call cpp#project#set(s:all.cc)
  call cpp#project#select(cur)
endfu

fu! cpp#project#info()
  return s:all
endfu

fu! s:get_default_includes(cc)
  let out = system(a:cc.' -E -x c++ - -v < /dev/null')
  let str = matchstr(out,
        \'.*#include <...> search starts here:\zs.*'.
        \'\zeEnd of search list.*') 
  return split(str, '[[:space:]]\+')
endfu

fu! s:extract_include(out, command)
  let parts = split(a:command, '\s\+')
  for x in parts
    let inc = matchstr(x, '^-I\s*\zs.*')
    if inc == ''
      continue
    endif
    let a:out[inc] = 1
  endfor
endfu

fu! cpp#project#get_list()
  return sort(keys(s:all.projects))
endfu

fu! s:get_current()
  return get(s:all.projects, s:all.current, s:project_tmpl)
endfu

fu! cpp#project#generate_tags()
  let cur = s:get_current()
  let files = []
  for x in values(cur.files)
    let cmd = substitute(x, '\s\+-o\s\+\S\+', '', '').' -M'
    let files += split(
          \matchstr(substitute(system(cmd), '\\\?\n', ' ', 'g'), '.*:\zs.*'), '\s\+')
  endfor
  if !empty(files)
    let cmd = printf(
          \'ctags --language-force=c++ --c++-kinds=+p  -f %s %s',
          \cur.tags, join(files, ' '))
    call system(cmd)
  endif
endfu

fu! cpp#project#select(proj) abort 
  let cur = get(s:all.projects, a:proj)
  if type(cur) == type(0)
    return
  endif
  let s:all.current = a:proj
  if empty(cur.files)
    return
  endif
  let dict = {}
  let cc = matchstr(values(cur.files)[0], '^\S*')
  for x in values(cur.files)
    call s:extract_include(dict, x)
  endfor
  let cur.path = join([&g:path] + keys(dict) + s:get_default_includes(cc), ',')

  call cpp#project#generate_tags()

  let nr = bufnr('%')
  silent bufdo doautocmd FileType
  exe ':'.nr.'buffer'
endfu

fu! cpp#project#update_buffer() abort
  let cur = s:get_current()
  let &l:makeprg = get(cur.files, expand('%:p'), '')
  let &l:path = cur.path
  let &l:tags = cur.tags
endfu
