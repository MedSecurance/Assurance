:-module(assurance,
	 [ ar_write_status/0,
	   set_current_assurance_repository/1,
	   current_assurance_repository/1,
	   reset_assurance_repository/0,
	   init_assurance_repository/1,	  % +CaseId
	   attach_assurance_repository/1, % +CaseId
	   alloc_instid/1,            % -InstId (fresh per occurrence)
	   insert_ac_occurrence/4,     % +OccId, +PatternId, +AArgs, -InstId
	   occurrence_instid/2,        % +OccId, -InstId
	   insert_ac_instance/5,	 % +PatternId, +AArgs, +InstId, +GoalI, +Log
	   insert_ac_instance_id_args/4, % +PatternId, +Id, +AArgs, -Index (legacy)
	   insert_ac_instance_id_args/5, % +PatternId, +PatternSig, +Id, +AArgs, -Index
	   ac_instance/5,		 % -PatternId, -AArgs, -InstId, -GoalI, -Log
	   ac_instance_id_args/5	 % -PatternId, -PatternSig, -Id, -AArgs, -Index
	 ]).

:- use_module(library(persistency)).
:- use_module(com/param).

:- persistent ac_instance(patternid:atom,
			  aargs:list(acyclic),
			  instid:positive_integer,
			  goal:acyclic,
			  log:list(list(acyclic))).

:- persistent ac_instance_id_args(patternid:atom,
				  patternsig:atom,
				  id:atom,
				  aargs:list(acyclic),
				  index:positive_integer).


:- persistent ac_occurrence(occid:acyclic,
                            patternid:atom,
                            aargs:list(acyclic),
                            instid:positive_integer).

:- persistent ac_instid_counter(value:nonneg).

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
	shell('make -s clean_cases'). % just use make

				% init repository db

init_assurance_repository(CaseId) :-
	param:cases_repo_dir(ACRepoDir), param:ac_repo_file(RepoFile),
	atomic_list_concat( [ACRepoDir, '/', CaseId], CaseDirectory),
	make_directory_path( CaseDirectory ),
	atomic_list_concat( [CaseDirectory, '/', RepoFile], ACRepoFilename),
	db_attach(ACRepoFilename, []), set_current_assurance_repository(CaseId),
	retractall_ac_instance(_,_,_,_,_),
	retractall_ac_instance_id_args(_,_,_,_,_),
	retractall_ac_instance_id_counter(_),
	assert_ac_instance_id_counter(0),
	retractall_ac_occurrence(_,_,_,_),
	retractall_ac_instid_counter(_),
	assert_ac_instid_counter(0).

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

				% insert_ac_instance(+PatternId, +AArgs, +InstId, +GoalI, +Log)

insert_ac_instance(PatternId, AArgs, InstId, GoalI, Log) :-
	assert_ac_instance(PatternId, AArgs, InstId, GoalI, Log).

				
				% alloc_instid(-InstId)
				%   Allocate a fresh InstId for a single instantiation occurrence.
				%   InstIds are unique within a single instantiated case (CASES repo).

alloc_instid(InstId) :-
	with_mutex( assurance,
		    ( ac_instid_counter(Last),
		      retractall_ac_instid_counter(_),
		      InstId is Last + 1,
		      assert_ac_instid_counter(InstId))).

				% insert_ac_occurrence(+OccId, +PatternId, +AArgs, -InstId)
				%   Record the association between an occurrence identity and its InstId.
				%   OccId is treated as an opaque, structurally stable term.

insert_ac_occurrence(OccId, PatternId, AArgs, InstId) :-
	ac_occurrence(OccId, PatternId, AArgs, InstId), !.

insert_ac_occurrence(OccId, PatternId, AArgs, InstId) :-
	( var(InstId) -> alloc_instid(InstId) ; true ),
	assert_ac_occurrence(OccId, PatternId, AArgs, InstId).

				% occurrence_instid(+OccId, -InstId)

occurrence_instid(OccId, InstId) :-
	ac_occurrence(OccId, _PatternId, _AArgs, InstId).

% insert_ac_instance_id_args(+PatternId, +Id, +AArgs, -Index)
%   Legacy entry point (PatternSig not provided). Stores PatternSig = nosig.

insert_ac_instance_id_args(PatternId, Id, AArgs, Index) :-
	insert_ac_instance_id_args(PatternId, nosig, Id, AArgs, Index).

% insert_ac_instance_id_args(+PatternId, +PatternSig, +Id, +AArgs, -Index)
%   Persist a stable provenance binding from an instance root (Id) to the
%   pattern version used to produce it. PatternSig is normalized to an atom
%   (accepting either atom or string input).

insert_ac_instance_id_args(PatternId, PatternSig0, Id, AArgs, Index) :-
	(   string(PatternSig0)
	->  atom_string(PatternSig, PatternSig0)
	;   PatternSig = PatternSig0
	),
	ac_instance_id_args(PatternId, PatternSig, Id, AArgs, Index), !.

insert_ac_instance_id_args(PatternId, PatternSig0, Id, AArgs, Index) :-
	(   string(PatternSig0)
	->  atom_string(PatternSig, PatternSig0)
	;   PatternSig = PatternSig0
	),
	with_mutex( assurance,
		    ( ac_instance_id_counter(LastIndex),
		      retractall_ac_instance_id_counter(_),
		      Index is LastIndex + 1,
		      assert_ac_instance_id_counter(Index),
		      assert_ac_instance_id_args(PatternId, PatternSig, Id, AArgs, Index))).
