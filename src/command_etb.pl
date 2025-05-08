% ETB-specific command set

:- use_module('etb').
:- use_module('patterns').

commands_defined(etb).

%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%
% definition of the ETB tool interactive commands syntax
% syntax( Signature, CommandSet ).
%
syntax(attach_case(case_id),                                     etb).
syntax(attach_evidence,                                     	etb).
syntax(detach_case,                                              etb).
syntax(detach_evidence,											etb).
syntax(detach_repos,											etb).

syntax(etb,                            basic).
% syntax(etb_server,                                               etb).
syntax(etb_reset,						 etb).
% syntax(etb_server(arg),                                          etb).

syntax(etbt,                                                     etb).
syntax(etbt(test_id),                                            etb).
syntax(etbt(test_id,mode),                                       etb).

syntax(etbtests,                                                 etb).

syntax(export_case(basename, format),                            etb).

syntax(import(spec_type,file,s_id),                              etb).

syntax(instantiate_pattern(pattern_name,arg_list,ac_id),		 etb).

syntax(instantiate_pattern_list(pattern_list,ac_id),			 etb).

syntax(load_agent(agent_file),									etb).

syntax(load_model_v(modelid,policy,platform,config),			 etb).

syntax(load_patterns(patterns_file),							etb).

% load_procs is defined in commands.pl

syntax(show_case,						 etb).
syntax(show_case(case_id),					 etb).
syntax(show_cases,						 etb).
syntax(show_evidence,											etb).
syntax(show_evidence(opt),										etb).
syntax(show_pattern(pattern_id),                                 etb).
syntax(show_pattern(pattern_id,mode),                            etb).
syntax(show_patterns,			                         etb).
syntax(show_patterns(mode),			                 etb).
syntax(show_pats,				                 etb).

% show_proc, show_procs are defined in commands.pl

syntax(update,                                                   etb).

%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%
% ETB tool command semantics
% semantics(<signature with formal params>) :- <constraints>.
%
% optional static semantics entry, e.g., used to check command arguments
% distinct from syntax so syntax can be called separately
%

semantics(attach_case(Case)) :- !, atom(Case).

semantics(etb_reset(D)) :- !, (D == cap ; D == repos ; D == all).

% semantics(etb_server(A)) :- !, atomic(A).

semantics(etbt(T)) :- !, atom(T).
semantics(etbt(T,E)) :- !, atom(T), atom(E).

semantics(export_case(Name,Format)) :- !, atom(Name), atom(Format), (Format==txt;Format==html).

semantics(import(T,F,Id)) :- !, atom(T), atom(F), atom(Id).

semantics(instantiate_pattern(PName,Args,CaseId)) :- !, atom(PName), is_list(Args), atom(CaseId).
semantics(instantiate_pattern_list(PatList,CaseId)) :- !, is_list(PatList), atom(CaseId).

semantics(load_agent(F)) :- !, atom(F).

semantics(load_model_v(Mid,Pol,Plat,Config)) :- !, atom(Mid), var(Pol), var(Plat), var(Config).

semantics(load_patterns(F)) :- !, atom(F).

semantics(show_case(Case)) :- !, atom(Case).

semantics(show_evidence(Opt)) :- !, ( Opt=='summary' ; Opt=='all').

semantics(show_pattern(PatId)) :- !, atom(PatId).
semantics(show_pattern(PatId,Mode)) :- !, atom(PatId), atom(Mode), member(Mode,[text,header,pp]).
semantics(show_patterns(M)) :- !, atom(M), member(M,[text,header,pp]).

%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%
% command help strings
%   help(Key,    HelpString)
%
%   all strings for a given key are displayed when key is given as an
%   argument to the help command, e.g., "help(etb_server)"
%
help(attach_case, 'Attach the identified assurance case in the repository.').
help(attach_case, 'Arg is an assurance case identifier.').

help(attach_evidence, 'Attach the EVIDENCE repository.').

help(detach_case, 'Detach the currently attached assurance case.').
help(detach_evidence, 'Detach the EVIDENCE repository.').
help(detach_repos, 'Detach the CASES and EVIDENCE repositories.').

help(etb,       'Switch to etb user mode.').
help(etb_reset,	'Reset ETB repositories.').
help(etb_reset, 'Arg (opt) domain to reset (cap or repos).').
% help(etb_server,'Start the ETB server.').

help(etbt,      'Run an etb built-in test. Default is \'e2e\'.').
help(etbt,      'Arg1 (opt) is a test identifier.').
help(etbt,      'Arg2 (opt) is etb mode.').

help(export_case,	'Export the current assurance case to the CAP.').
help(export_case,	'Arg1 is a name in the CAP directory for the export.').
help(export_case, 'Arg2 is the format (currently either txt or html).').

help(import,    'Import a specification of type (model, property, ...).').
help(import,    'Arg1 is a specification type.').
help(import,    'Arg2 is a file name.').
help(import,    'Arg3 (opt) is the identifier to associate with the spec.').

help(instantiate_pattern,	'Instantiate a pattern from the KB into the REPO.').
help(instantiate_pattern, 	'Arg1 is the name of a defined pattern.').
help(instantiate_pattern, 	'Arg2 is a list of the required parameters for the pattern.').
help(instantiate_pattern, 	'Arg3 is a valid new assurance case ID.').

help(instantiate_pattern_list,	'Instantiate the given AC pattern into the REPO.').
help(instantiate_pattern_list,	'Arg1 is an AC pattern list.').
help(instantiate_pattern_list,	'Arg2 is a valid new assurance case ID.').

help(load_agent,'Load Prolog-side agent module definition from specified file.').
help(load_agent,'Arg is the Prolog-side agent module file name.').

help(load_model_v, 'Load model from KB and return policy, platform and config components.').
help(load_model_v, 'Arg1 is a model identifier.').
help(load_model_v, 'Arg2 is a variable to receive the policy component.').
help(load_model_v, 'Arg3 is a variable to receive the platform component.').
help(load_model_v, 'Arg4 is a variable to receive the configuration component.').

help(load_patterns,'Load pattern definitions from a named file.').
help(load_patterns,'Arg is the patterns file name.').

help(show_case, 'Show the current or identified assurance case.').
help(show_case, 'Arg1 (opt) is the assurance case ID, otherwise current case.').

help(show_cases, 'Show all assurance cases in the CASES Repo.').

help(show_evidence, 'Show current evidence records.').
help(show_evidence, 'Arg1 (opt) is summary or all (summary if not specified).').

help(show_pattern, 'Show a loaded assurance case pattern.').
help(show_pattern, 'Arg1 is the identifier for the pattern.').
help(show_pattern, 'Arg2 (opt) is the mode {all,header,pp}.').

help(show_patterns, 'Show all currently loaded assurance case patterns.').
help(show_patterns, 'Arg1 (opt) is the mode {all,header,pp}.').

help(update,	'Update assurance cases and evidence.').

%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%
% do the command, should be one for every implemented valid command form
% known broken or unimplemented commands should just "fail." straightaway
%

do(attach_case(Case)) :- !, assurance:attach_assurance_repository(Case).

do(attach_evidence) :- !, evidence:attach_evidence_repository.

do(detach_case) :- !, assurance:detach_assurance_repository.
do(detach_evidence) :- !, evidence:detach_evidence_repository.
do(detach_repos) :- !, do(detach_case), do(detach_evidence).

do(etb) :- user_mode(etb), !, writeln('Already in etb mode').
do(etb) :- !, user_mode(M), retractall(user_mode(_)), assert(user_mode(etb)),
	param:prompt_string(etb,Prompt), param:setparam(prompt_string,Prompt),
	rem_commands(M), add_commands(etb), banner(etb).

do(etb_reset) :- !, do(detach_case), etb_reset.

do(etb_reset(D)) :- !, do(detach_case), etb_reset(D).

do(etb_status) :- !,
	assurance:ar_write_status,
	evidence:er_write_status.

% do(etb_server) :- !, etb_server:etb_server_cmd.
% do(etb_server(A)) :- !, etb_server:etb_server_cmd(A).

do(etbt) :- !, etbt(e2e). % abbrev-change to suit current need
do(etbt(e2e)) :- !, etbt(e2e).
do(etbt(T,Mode)) :- !, etbt(T,Mode).
do(etbtests) :- !, load_test_files([]), run_tests. % .plt tests

do(export_case(Name,Format)) :- !, export:ac_export(Name,Format).

do(import(T,F,Sid)) :- !,
    kb:load_specification_from_file(T,F,Sid).

do(instantiate_pattern(Name,Args,ACid)) :- !,
	assurance:detach_assurance_repository,
	instantiate:instantiate_pattern(Name,Args,ACid),
	(param:verbose(on) -> (export:ac_string(S), writeln(S)) ; true).

do(instantiate_pattern_list(PatList,ACid)) :- !,
	assurance:detach_assurance_repository,
	instantiate:instantiate_pattern_list(PatList,ACid),
	(param:verbose(on) -> (export:ac_string(S), writeln(S)) ; true).

do(load_agent(F)) :- !, agent_interface:load_agent(F).

do(load_model_v(Mid,Pol,Plat,Conf)) :- !, model:load_model(Mid,M), M = model(Pol,Plat,Conf).

do(load_patterns(F)) :- !, patterns:load_patterns(F).

do(show_case) :- !,
	assurance:current_assurance_repository(ACid),	
	(	ACid == none
	->	writeln('No current assurance case.')
	;	(
			format('Case ~a:~n',ACid),
			export:ac_string(S), writeln(S)
		)
	).

%do(show_case(ACid)) :- !, do(detach_case), do(attach_case(ACid)), do(show_case). % show and leave as current case

do(show_case(ACid)) :- !, % show and restore previous current case
        assurance:current_assurance_repository(CurrentACid),
	param:cases_repo_dir(ACRepoDir),
	atomic_list_concat( [ACRepoDir, '/', ACid], CaseDirectory),
        exists_directory(CaseDirectory),
        do( detach_case ), do( attach_case(ACid) ),
        do( show_case ), do( detach_case ),
        (       CurrentACid \== none
        ->      do( attach_case(CurrentACid) )
	;       true
        ).

do(show_cases) :- !,
        assurance:current_assurance_repository(CurrentACid), do( detach_case ),
	param:cases_repo_dir(ACRepoDir),
	directory_files(ACRepoDir,Files),
        subtract(Files, ['.', '..', 'README.md'], Cases),
        forall(member(Case,Cases),
                ( format('Case ~a:~n',Case), do( attach_case(Case) ),
		  export:ac_string(S), writeln(S),
                  do( detach_case )
                )
        ),
        (       CurrentACid \== none
        ->      do( attach_case(CurrentACid) )
	;       true
        ).

do(show_evidence) :- !, etb_show_evidence(summary).
do(show_evidence(Opt)) :- !, etb_show_evidence(Opt).

do(show_pattern(PatId)) :- !, do(show_pattern(PatId,pp)).
do(show_pattern(PatId,M)) :- !,
	(	M == pp
	->	listing(ac_pattern(PatId,_,_)), !
	;	ac_pattern(PatId,PatArgs,Goal),
		format('PATTERN: ~s  Args: ~w~n', [PatId,PatArgs]),
		(	M == header 
		->	true
		;	(	M == text
			->	write_term(Goal,[quoted(true),spacing(next_argument)]), nl
			;	true
			)
		)
	).
do(show_pats) :- do(show_patterns(header)).
do(show_patterns) :- do(show_patterns(text)).
/*
do(show_patterns(M)) :- 
	ac_pattern(PatId,PatArgs,Goal),
	format('PATTERN: ~s  Args: ~w~n', [PatId,PatArgs]),
	(	M == header
		->	true
		;	M == pp
		->	listing(ac_pattern)
		;	write_term(Goal,[quoted(true),spacing(next_argument)]), nl,	nl, fail
	).
*/
do(show_patterns(M)) :- 
	(	M == pp
		->	listing(ac_pattern)
		;	ac_pattern(PatId,PatArgs,Goal),
			format('PATTERN: ~s  Args: ~w~n', [PatId,PatArgs]),
			(	M == header
			->	true
			;	(	M == text
				->	write_term(Goal,[quoted(true),spacing(next_argument)]), nl, nl
				;	true
				)
			), fail
	), !.
do(show_patterns(_)).

do(update) :- evidence:update_ongoing.

%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%
% command procedures
%

etbt(e2e) :- % end-to-end test
	true.

etbt(Test,Emode) :-
	param:setparam(etb_mode,Emode),
	etbt(Test).

etb_halting :- % be certain persistent data is flushed
	evidence:detach_evidence_repository,
	assurance:detach_assurance_repository.

etb_show_evidence(all) :-
	listing(evidence:ac_evidence/6).
etb_show_evidence(summary) :-
	forall( evidence:ac_evidence(Cat,Clm,_Ctx,_A,X,S),
			format('~q ~q ~q ~q~n',[X,S,Cat,Clm]) ).

