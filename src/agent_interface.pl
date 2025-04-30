:- module(agent_interface, [evidence_validate/5]).

:- use_module(evidence).
:- use_module(category).

init :-
	validation_agents(Agents), param:kb_agents_dir(KBAdir),
	forall(member(Agent,Agents),
			(	atomic_list_concat([KBAdir,'/',Agent,'.pl'], AgentFile),
				(	exists_file(AgentFile)
				->	use_module(AgentFile)
				;	format('File ~q for declared agent ~q does not exist~n',[AgentFile,Agent])
				)
			)
		).

				% evidence_validate(+Category, +Claim, +Context, +AArgs, +XRef)
evidence_validate(Category, Claim, Context, AArgs, XRef) :-
	atom(Category), evidence_categories(Categories), member(Category, Categories), !,
	evidence_category(Category, _CatDesc, _CatType, CatValidationMethod),
	validation_method(CatValidationMethod, _ValDesc, CatAgent), % lookup agent for category
	param:ev_validate_extension(Validate),
	atomic_concat(Category, Validate, CatValidate),
	ValidateGoal =.. [CatValidate,Claim,Context,AArgs,XRef,Status],
	% calling CatAgent:CatValidate(+Claim, +Context, +AArgs, +XRef, -Status)
	call(CatAgent:ValidateGoal),
	update_evidence_status(Category, Claim, Context, AArgs, XRef, Status), !.

evidence_validate(unknown, _, _, _, _) :- !, true; % do nothing for 'unknown'

evidence_validate(_Category, _Claim, _Context, _AArgs, _XRef) :-
				% undefined evidence category or other error handling here
	true.

				% update_evidence_status(+Category, +Claim, +Context, +AArgs, +XRef, +Status)

update_evidence_status(Category, Claim, Context, AArgs, XRef, Status) :-
	update_ac_evidence(Category, Claim, Context, AArgs, XRef, Status), % update evidence DB
	param:evidence_repo_dir(RepoDir), param:ev_status_file(StatusFile),
	atomic_list_concat([RepoDir, Category, XRef , StatusFile], '/', Filename),
	open(Filename, write, Output),
	write_term(Output, Status, [fullstop(true)]), % update status file
	close(Output).

load_agent(AgentFile) :-
	(	exists_file(AgentFile)
	->	use_module(AgentFile),
		format('Agent file ~q loaded~n',AgentFile)
	;	format('Agent file ~q does not exist~n',AgentFile)
	).
