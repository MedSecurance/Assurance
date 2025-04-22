:- module(evidence,
          [ er_write_status/0,
		  	reset_evidence_repository/0,
	    	attach_evidence_repository/0,
	    	ac_evidence/6, % -Category, -Claim, -Context, -AArgs, -XRef, -Status
            insert_ac_evidence/6, % +Category, +Claim, +Context, +AArgs, -XRef, 'pending'
            update_ac_evidence/6, % +Category, +Claim, +Context, +AArgs, +XRef, +Status
	    	update_ongoing/0
          ]).

:- use_module(library(persistency)).
:- use_module(categories).
:- use_module('com/param').

% :- persistent ac_evidence(category:oneof([axiom,certificate,ichecker,ocra,hazard_log,risk_acceptance,unknown]),
:- persistent ac_evidence(category:atom,
			  claim:text,
			  context:list(text),
			  aargs:list(acyclic),
			  xref:positive_integer,
			  status:oneof([pending,ongoing,valid,invalid])).

:- persistent ac_evidence_counter(value:positive_integer).

er_write_status :-
	writeln('   EVIDENCE Repository:').

reset_evidence_repository :-
	detach_evidence_repository,
	% param:evidence_repo_dir(EvRepoDir), param:ev_repo_file(RepoFile), param:evidence(Evidence),
	% atomic_list_concat(['find -d ',EvRepoDir,' -not "(" -name README.md -or -name ',Evidence,' -or -name axiom -or -name certificate -or -name ichecker -or -name ocra -or -name unknown ")" -delete'],Cmd),
	Cmd = 'make clean_evidence', % just use make
	shell(Cmd),
	% following not currently used due to use of make command above
	% param:initial_evidence_counter_base(EC),
	% make_directory_path( EvRepoDir ),
	% atomic_list_concat( [EvRepoDir, '/', RepoFile], RepoFilename),
	% open(RepoFilename, write, Output),
	% format(Output, 'assert(ac_evidence_counter(~d)).~n', [EC]),
	% close(Output),
	true.

				% attach the evidence repository

attach_evidence_repository :-
	param:evidence_repo_dir(EvRepoDir), param:ev_repo_file(RepoFile),
	atomic_list_concat([EvRepoDir, '/', RepoFile], FullRepoFile),
    	db_attach(FullRepoFile, []).

				% detach repository db

detach_evidence_repository :- db_detach.

				% insert_ac_evidence(+Category, +Claim, +Context, +AArgs, +XRef, +Status)
				% status must be 'pending'

insert_ac_evidence(Category, Claim, Context, AArgs, XRef, 'pending') :-
	ac_evidence(Category, Claim, Context, AArgs, XRef, _), !.

insert_ac_evidence(Category, Claim, Context, AArgs, XRef, 'pending') :-
	evidence_categories(Categories),
	(	member(Category,Categories)
	->	true
	;	!, fail % Category not a KB defined evidence category - see KB/EVIDENCE/categories.pl
	),
	with_mutex( evidence,
		    ( ac_evidence_counter(LastXRef),
		      retractall_ac_evidence_counter(_),
		      XRef is LastXRef + 1,
		      assert_ac_evidence_counter(XRef),
		      assert_ac_evidence(Category, Claim, Context, AArgs, XRef, 'pending') ) ),
	param:evidence_repo_dir(EvRepoDir), param:ev_status_file(StatusName),
	atomic_list_concat([EvRepoDir, '/', Category, '/', XRef], Dirname),
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
	format('*** updating evidence repository ...'),
	param:evidence_repo_dir(EvRepoDir), param:ev_status_file(StatusName),
	forall( ac_evidence(Category, Claim, Context, AArgs, XRef, ongoing),
		( atomic_list_concat([EvRepoDir, '/', Category, '/', XRef , '/', StatusName], Filename),
		  open(Filename, read, Input), read_term(Input, Status, []), close(Input),
		  ( member( Status, [valid, invalid] )
		  -> ( update_ac_evidence(Category, Claim, Context, AArgs, XRef, Status),
		       format('.') )
		  ;  ( true ) ) ) ),
	format(' done.~n').

