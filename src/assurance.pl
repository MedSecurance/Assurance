:-module(assurance,
	 [ reset_assurance_repository/0,
	   init_assurance_repository/1,	  % +CaseId
	   attach_assurance_repository/1, % +CaseId
	   insert_ac_instance/4,	 % +PatternId, +AArgs, +GoalI, +Log
	   insert_ac_instance_id_args/4, % +PatternId, +Id, +AArgs, -Index
	   ac_instance/4,		 % -PatternId, -AArgs, -GoalI, -Log
	   ac_instance_id_args/4	 % -PatternId, -Id, -AArgs, -Index
	 ]).

:- use_module(library(persistency)).

:- persistent ac_instance(patternid:atom,
			  aargs:list(acyclic),
			  goal:acyclic,
			  log:list(list(acyclic))).

:- persistent ac_instance_id_args(patternid:atom,
				  id:atom,
				  aargs:list(acyclic),
				  index:positive_integer).

:- persistent ac_instance_id_counter(value:nonneg).

				% reset repository db

reset_assurance_repository :-
	detach_assurance_repository,
	param:cases_repo_dir(ACRepoDir), param:cases(Cases),
	atomic_list_concat(['find -d ',ACRepoDir,' -not "(" -name README.md -or -name ',Cases,' ")" -delete'],Cmd),
	shell(Cmd).

				% init repository db

init_assurance_repository(CaseId) :-
	param:cases_repo_dir(ACRepoDir), param:ac_repo_file(RepoFile),
	atomic_list_concat( [ACRepoDir, '/', CaseId], CaseDirectory),
	make_directory_path( CaseDirectory ),
	atomic_list_concat( [CaseDirectory, '/', RepoFile], ACRepoFilename),
	db_attach(ACRepoFilename, []),
	retractall_ac_instance(_,_,_,_),
	retractall_ac_instance_id_args(_,_,_,_),
	retractall_ac_instance_id_counter(_),
	assert_ac_instance_id_counter(0).

				% attach repository db

attach_assurance_repository(CaseId) :-
	param:cases_repo_dir(ACRepoDir), param:ac_repo_file(RepoFile),
	atomic_list_concat( [ACRepoDir, '/', CaseId, '/', RepoFile], Filename),
	(	db_attached(Filename)
	->	true
	;	db_attach(Filename, [])
	).

				% detach current repository db

detach_assurance_repository :- db_detach.

				% insert_ac_instance(+PatternId, +AArgs, +GoalI, +Log)

insert_ac_instance(PatternId, AArgs, GoalI, Log) :-
	assert_ac_instance(PatternId, AArgs, GoalI, Log).

				% insert_ac_instance_id_args(+PatternId, +Id, +AArgs, -Index)

insert_ac_instance_id_args(PatternId, Id, AArgs, Index) :-
	ac_instance_id_args(PatternId, Id, AArgs, Index), !.

insert_ac_instance_id_args(PatternId, Id, AArgs, Index) :-
	with_mutex( assurance,
		    ( ac_instance_id_counter(LastIndex),
		      retractall_ac_instance_id_counter(_),
		      Index is LastIndex + 1,
		      assert_ac_instance_id_counter(Index),
		      assert_ac_instance_id_args(PatternId, Id, AArgs, Index))).

