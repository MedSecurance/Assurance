:-module(assurance,
	 [ ar_write_status/0,
	   set_current_assurance_repository/1,
	   current_assurance_repository/1,
	   reset_assurance_repository/0,
	   init_assurance_repository/1,	  % +CaseId
	   attach_assurance_repository/1, % +CaseId
	   insert_ac_instance/4,	 % +PatternId, +AArgs, +GoalI, +Log
	   insert_ac_instance_id_args/4, % +PatternId, +Id, +AArgs, -Index
	   ac_instance/4,		 % -PatternId, -AArgs, -GoalI, -Log
	   ac_instance_id_args/4	 % -PatternId, -Id, -AArgs, -Index
	 ]).

:- use_module(library(persistency)).
:- use_module(com/param).

:- persistent ac_instance(patternid:atom,
			  aargs:list(acyclic),
			  goal:acyclic,
			  log:list(list(acyclic))).

:- persistent ac_instance_id_args(patternid:atom,
				  id:atom,
				  aargs:list(acyclic),
				  index:positive_integer).

:- persistent ac_instance_id_counter(value:nonneg).

:- dynamic current_assurance_repository/1.

current_assurance_repository(none).

ar_write_status :-
	current_assurance_repository(ACid),
	write('   Current assurance case: '), writeln(ACid),
	writeln('   CASES Repository status:'),
	% too verbose: ( param:verbose(on) -> command:do(show_cases) ; true ),
	% gather and show some AR statistics
	true.

set_current_assurance_repository(CaseId) :-
	( atom(CaseId) -> ACid = CaseId ; ACid = defaultCID ),
	retractall(current_assurance_repository(_)),
	assert(current_assurance_repository(ACid)).

				% reset repository db

reset_assurance_repository :-
	detach_assurance_repository,
	% param:cases_repo_dir(ACRepoDir), param:cases(Cases),
	% atomic_list_concat(['find -d ',ACRepoDir,' -not "(" -name README.md -or -name ',Cases,' ")" -delete'],Cmd),
	Cmd = 'make clean_cases', % just use make
	shell(Cmd).

				% init repository db

init_assurance_repository(CaseId) :-
	param:cases_repo_dir(ACRepoDir), param:ac_repo_file(RepoFile),
	atomic_list_concat( [ACRepoDir, '/', CaseId], CaseDirectory),
	make_directory_path( CaseDirectory ),
	atomic_list_concat( [CaseDirectory, '/', RepoFile], ACRepoFilename),
	db_attach(ACRepoFilename, []), set_current_assurance_repository(CaseId),
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
	;	db_attach(Filename, []), set_current_assurance_repository(CaseId)
	).

				% detach current repository db

detach_assurance_repository :- db_detach, set_current_assurance_repository(none).

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

