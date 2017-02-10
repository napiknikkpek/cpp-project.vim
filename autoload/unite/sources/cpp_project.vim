
fu! unite#sources#cpp_project#define() abort
  return s:cpp_project
endfu

let s:action_table = {'set_cpp_project': {}}

fu! s:action_table.set_cpp_project.func(candidate)
  call cpp#project#select(a:candidate.word)
endfu

let s:cpp_project = {
      \'name': 'cpp_project',
      \'action_table': s:action_table,
      \'default_action': {'*': 'set_cpp_project'}
      \}

fu! s:cpp_project.gather_candidates(args, context) abort
  return map(cpp#project#get_list(), "{'word': v:val}")
endfu
