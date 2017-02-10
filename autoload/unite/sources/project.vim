
fu! unite#sources#project#define() abort
  return s:source_project
endfu

let s:action_table = {'set_project': {}}

fu! s:action_table.set_project.func(candidate)
  call project#select(a:candidate.word)
endfu

let s:source_project = {
      \'name': 'project',
      \'action_table': s:action_table,
      \'default_action': {'*': 'set_project'}
      \}

fu! s:source_project.gather_candidates(args, context) abort
  return map(project#get_list(), "{'word': v:val}")
endfu
