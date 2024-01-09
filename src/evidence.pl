:- module(evidence,
          [ reset_evidence_repository/0,
	    attach_evidence_repository/0,
	    ac_evidence/6, % -Category, -Claim, -Context, -AArgs, -XRef, -Status
            insert_ac_evidence/6, % +Category, +Claim, +Context, +AArgs, -XRef, 'pending'
            update_ac_evidence/6, % +Category, +Claim, +Context, +AArgs, +XRef, +Status
	    update_ongoing/0
          ]).

:- use_module(library(persistency)).

:- persistent ac_evidence(category:oneof([axiom,certificate,ichecker,ocra,unknown]),
			  claim:text,
			  context:list(text),
			  aargs:list(acyclic),
			  xref:positive_integer,
			  status:oneof([pending,ongoing,valid,invalid])).

:- persistent ac_evidence_counter(value:positive_integer).

reset_evidence_repository :-
	param:ev_repo_directory(RepoDir), param:ev_repo_file(RepoFile),
	param:initial_evidence_counter_base(EC),
	atomic_list_concat( ['../', RepoDir], Directory),
	make_directory_path( Directory ),
	atomic_list_concat( [Directory, RepoFile], Filename),
	open(Filename, write, Output),
	format(Output, 'assert(ac_evidence_counter(~d)).~n', [EC]),
	close(Output).

				% attach the evidence repository

attach_evidence_repository :-
	param:ev_repo_directory(RepoDir), param:ev_repo_file(RepoFile),
	atomic_list_concat(['../', RepoDir, RepoFile], FullRepoFile),
    db_attach(FullRepoFile, []).

				% insert ac_evidence claims, must be pending

insert_ac_evidence(Category, Claim, Context, AArgs, XRef, 'pending') :-
	ac_evidence(Category, Claim, Context, AArgs, XRef, _), !.

insert_ac_evidence(Category, Claim, Context, AArgs, XRef, 'pending') :-
	with_mutex( evidence,
		    ( ac_evidence_counter(LastXRef),
		      retractall_ac_evidence_counter(_),
		      XRef is LastXRef + 1,
		      assert_ac_evidence_counter(XRef),
		      assert_ac_evidence(Category, Claim, Context, AArgs, XRef, 'pending') ) ),
	param:ev_repo_directory(RepoDir), param:ev_status_file(StatusName),
	atomic_list_concat(['../', RepoDir, Category, '/', XRef], Dirname),
	make_directory_path(Dirname),
	atomic_list_concat([Dirname,'/',StatusName], FullFilename),
	open(FullFilename, write, Output),
	write_term(Output, pending, [fullstop(true)]),
	close(Output).

				% update ac_evidence claims (repository status only)

update_ac_evidence(Category, Claim, Context, AArgs, XRef, Status) :-
        ac_evidence(Category, Claim, Context, AArgs, XRef, Status), !.

update_ac_evidence(Category, Claim, Context, AArgs, XRef, Status) :-
        with_mutex(evidence,
                   ( retractall_ac_evidence(Category, Claim, Context, AArgs, XRef, _),
		     assert_ac_evidence(Category, Claim, Context, AArgs, XRef, Status))).


				% update_ongoing

update_ongoing :-
	format('*** updating ongoing ...'),
	param:ev_repo_directory(RepoDir), param:ev_status_file(StatusName),
	forall( ac_evidence(Category, Claim, Context, AArgs, XRef, ongoing),
		( atomic_list_concat(['../', RepoDir, Category, '/', XRef , '/', StatusName], Filename),
		  open(Filename, read, Input), read_term(Input, Status, []), close(Input),
		  ( member( Status, [valid, invalid] )
		  -> ( update_ac_evidence(Category, Claim, Context, AArgs, XRef, Status),
		       format('.') )
		  ;  ( true ) ) ) ),
	format(' done.~n').

