:- module(agent, [evidence_validate/5]).

:- use_module(evidence).

				% evidence_validate(+Category, +Claim, +Context, +AArgs, +XRef)

evidence_validate(axiom, Claim, Context, AArgs, XRef) :-
	axiom_agent:axiom_validate(Claim, Context, AArgs, XRef, Status),
	update_evidence_status(axiom, Claim, Context, AArgs, XRef, Status).

evidence_validate(certificate, Claim, Context, AArgs, XRef) :-
	certificate_agent:certificate_validate(Claim, Context, AArgs, XRef, Status),
	update_evidence_status(certificate, Claim, Context, AArgs, XRef, Status).

evidence_validate(ocra, Claim, Context, AArgs, XRef) :-
	ocra_agent:ocra_validate(Claim, Context, AArgs, XRef, Status),
	update_evidence_status(ocra, Claim, Context, AArgs, XRef, Status).

evidence_validate(ichecker, Claim, Context, AArgs, XRef) :-
	ichecker_agent:ichecker_validate(Claim, Context, AArgs, XRef, Status),
	update_evidence_status(ichecker, Claim, Context, AArgs, XRef, Status).

evidence_validate(unknown, _Claim, _Context, _AArgs, _XRef) :-
				% nothing
	true.

evidence_validate(_Category, _Claim, _Context, _AArgs, _XRef) :-
				% not yet implemented: additional evidence categories
	true.

				% update_evidence_status(+Category, +Claim, +Context, +AArgs, +XRef, +Status)

update_evidence_status(Category, Claim, Context, AArgs, XRef, Status) :-
	update_ac_evidence(Category, Claim, Context, AArgs, XRef, Status),
	param:evidence_repo_dir(RepoDir), param:ev_status_file(StatusFile),
	atomic_list_concat([RepoDir, Category, XRef , StatusFile], '/', Filename),
	open(Filename, write, Output),
	write_term(Output, Status, [fullstop(true)]),
	close(Output).

