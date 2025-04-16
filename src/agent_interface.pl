:- module(agent_interface, [evidence_validate/5]).

:- use_module(evidence).
:- use_module(categories).

				% evidence_validate(+Category, +Claim, +Context, +AArgs, +XRef)
evidence_validate(Category, Claim, Context, AArgs, XRef) :-
	atom(Category), evidence_categories(Categories), member(Category, Categories), !,
	atomic_concat(Category, '_agent', CatAgent), atomic_concat(Category, '_validate', CatValidate),
	ValidateGoal =.. [CatValidate,Claim,Context,AArgs,XRef,Status],
	% calling CatAgent:CatValidate(Claim, Context, AArgs, XRef, Status)
	call(CatAgent:ValidateGoal),
	update_evidence_status(Category, Claim, Context, AArgs, XRef, Status).

evidence_validate(_Category, _Claim, _Context, _AArgs, _XRef) :-
				% unknown evidence category
	true.

				% update_evidence_status(+Category, +Claim, +Context, +AArgs, +XRef, +Status)

update_evidence_status(Category, Claim, Context, AArgs, XRef, Status) :-
	update_ac_evidence(Category, Claim, Context, AArgs, XRef, Status),
	param:evidence_repo_dir(RepoDir),
	atomic_list_concat([RepoDir, Category, XRef , 'status'], '/', Filename),
	open(Filename, write, Output),
	write_term(Output, Status, [fullstop(true)]),
	close(Output).

