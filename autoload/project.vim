
if !exists('s:workspace')
  let s:tmpl = {
        \ 'cc': '',
        \ 'current': {'tags': '', 'project': ''},
        \ 'makeprg': {},
        \ 'path': {},
        \ 'projects': {}}
  let s:workspace = deepcopy(s:tmpl)
endif

fu! s:normalize_command(dirname, command)
  return substitute(a:command, '\s\zs\a\+\S\+', a:dirname.'/\0', 'g')
endfu

fu! s:get_system_directories(cc)
  let out = system(a:cc.' -E -x c++ - -v < /dev/null')
  let str = matchstr(out,
        \'.*#include <...> search starts here:\zs.*'.
        \'\zeEnd of search list.*') 
  return split(str, '[[:space:]]\+')
endfu

fu! s:get_include_directories(command)
  let res = []
  let opts = split(a:command, '\s\+')
  for opt in opts
    let incl = matchstr(opt, '^-I\s*\zs.*')
    if incl == ''
      continue
    endif
    call add(res, incl)
  endfor
  return res
endfu

fu! s:get_includes(command)
    let cmd = substitute(a:command, '\s\+-o\s\+\S\+', '', '').' -M'
    return split(
          \ matchstr(substitute(system(cmd), '\\\?\n', ' ', 'g'), '.*:\zs.*'),
          \ '\s\+')
endfu

fu! project#set(cc) abort
  let db = len(a:cc) != 0 ? json_decode(join(readfile(a:cc), '')) : []

  let s:workspace = deepcopy(s:tmpl)
  for entry in db
    let s:workspace.makeprg[entry.file] =
          \ s:normalize_command(entry.directory, entry.command)

    if !has_key(s:workspace.projects, entry.directory)
      let s:workspace.projects[entry.directory] = []
    endif
    call add(s:workspace.projects[entry.directory], entry.file)

    let path = join(s:get_include_directories(entry.command) +
              \ s:get_system_directories(entry.command), ',')
    let includes = s:get_includes(entry.command)
    call add(includes, entry.file)
    for incl in includes
      let s:workspace.path[incl] = path
    endfor
  endfor
  let s:workspace.cc = a:cc
endfu

fu! project#update() abort
  call project#set(s:workspace.cc)
  call project#select(s:workspace.current.project)
endfu

fu! project#get_projects()
  return sort(keys(s:workspace.projects))
endfu

fu! project#generate_tags(tags, commands)
  let files = []
  for x in a:commands
    let files += s:get_includes(x)
  endfor
  if !empty(files)
    let cmd = printf(
          \ 'ctags --language-force=C++ --c++-kinds=+p  -f %s %s',
          \ a:tags, join(files, ' '))
    call system(cmd)
  endif
endfu

fu! project#select(project) abort 
  let s:workspace.current.project = a:project
  let s:workspace.current.tags = a:project.'/tags'
  let files = get(s:workspace.projects, a:project, [])
  if empty(files)
    return
  endif

  let commands = map(copy(files), 's:workspace.makeprg[v:val]')
  call project#generate_tags(s:workspace.current.tags, commands)

  let nr = bufnr('%')
  silent bufdo doautocmd FileType
  exe ':'.nr.'buffer'
endfu

fu! project#update_buffer() abort
  let fn = expand('%:p')
  let &l:makeprg = get(s:workspace.makeprg, fn, '')
  let &l:path = get(s:workspace.path, fn, '')
  let &l:tags = s:workspace.current.tags
endfu
