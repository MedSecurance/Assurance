				%
				% common access to pattern definitions
				%

:- module(patterns, [ ac_pattern/3,
	ac_pattern_sig/2,
	pattern_sig/2,
	defined_patterns/1,
	load_patterns/1 ]).

:- dynamic([ac_pattern/3, ac_pattern_sig/2, patterns_defined/1]).
:- multifile ac_pattern/3.

:- use_module(library(crypto)).

% ----------------------------------------------------------------------
				% Load-time normalization: accept legacy pattern-ref forms
				% but normalize them as patterns are loaded, so downstream code sees only
				% the canonical form retained in-memory:
				%   ac_pattern_ref(Id, Label, PatternId, Args)
				%
				% Legacy authoring form still accepted:
				%   ac_pattern_ref(PatternId, Args)
				% which is rewritten to:
				%   ac_pattern_ref(pr_N, '', PatternId, Args)
				% with a deterministic per-pattern structural counter.

:- multifile term_expansion/2.

term_expansion(ac_pattern(PatternId, Args, Goal0), ac_pattern(PatternId, Args, Goal)) :-
	% Reset the per-pattern counter for deterministic synthesized ids.
	normalize_goal(Goal0, Goal).

normalize_goal(Goal0, Goal) :-
	normalize_term(Goal0, 1, _Next, Goal).

				% Rewrite legacy ac_pattern_ref/2 to canonical ac_pattern_ref/4.
normalize_term(ac_pattern_ref(PatId, PatArgs), N0, N, ac_pattern_ref(SynthId, '', PatId, PatArgs)) :-
	!,
	format(atom(SynthId), 'pr_~d', [N0]),
	N is N0 + 1.

				% Preserve canonical ac_pattern_ref/4 as-is (but still recurse into its arguments).
normalize_term(ac_pattern_ref(Id, Label, PatId, PatArgs0), N0, N, ac_pattern_ref(Id, Label, PatId, PatArgs)) :-
	!,
	normalize_term(PatArgs0, N0, N, PatArgs).

				% Recursive descent over compound terms.
normalize_term(Term0, N0, N, Term) :-
	compound(Term0),
	!,
	Term0 =.. [F|Args0],
	normalize_terms(Args0, N0, N, Args),
	Term =.. [F|Args].

				% Atomic / variable terms unchanged.
normalize_term(Term, N, N, Term).

normalize_terms([], N, N, []).
normalize_terms([H0|T0], N0, N, [H|T]) :-
	normalize_term(H0, N0, N1, H),
	normalize_terms(T0, N1, N, T).

				% ac_pattern(+Name, +Args, +Goal)
				%
				%	[ arg( +Name, +Type ), ... ]
				%	goal(Id, Claim, Context, Body)

init :-
	param:kb_patterns_dir(KBPdir), param:pattern_files(PreDefPfiles),
	forall(member(F,PreDefPfiles), (
		% atomic_list_concat([KBPdir,'/patterns_',F], Pfile),
		atomic_list_concat([KBPdir,'/',F], Pfile),
		assert( patterns_defined(F) ),
		ensure_loaded(Pfile) )
	),
	% Ensure signatures exist for any pre-defined patterns.
	refresh_pattern_sigs.

defined_patterns(PatSets) :- findall(PatSet, patterns_defined(PatSet), PatSets).

load_patterns(FullFile) :-
	(   (   ( exists_file(FullFile), !)
			;
			( atom_concat(FullFile,'.pl',FullFilePL),
			exists_file(FullFilePL)
			)
		)
	->  true
	;   format('~q: file not found.~n',[FullFile]),
		!, fail
	),
	resolve_patterns_file(FullFile, ActualFile),
	% Prevent multiple in-memory definitions of the same PatternId across repeated loads
	% within the same run (e.g., when a modified pattern set is loaded again, or loaded
	% under a different filename). If the same PatternId is defined more than once in the
	% database, once/1 in instantiation will always pick the oldest clause.
	%
	% Strategy: scan the file for ac_pattern/3 definitions, retract any existing clauses
	% for those PatternIds, then (re)load the file.
	scan_pattern_ids(ActualFile, PatIds),
	forall(member(PatId, PatIds), (
		retractall(ac_pattern(PatId, _, _)),
		retractall(ac_pattern_sig(PatId, _))
	)),
	load_files(ActualFile, [reconsult(true)]),
	refresh_pattern_sigs,
	file_base_name(ActualFile,Base), file_name_extension(Core,_,Base),
	atom(Core), % remember core of basename of loaded file
	(   patterns_defined(Core)
	->  retractall( patterns_defined(Core) )
	;   true
	),
	assert( patterns_defined(Core) ),
	true.

				% resolve_patterns_file(+UserFile, -ActualFile)
				%   Allow callers to omit the .pl extension.

resolve_patterns_file(UserFile, ActualFile) :-
	(   exists_file(UserFile)
	->  ActualFile = UserFile
	;   atom_concat(UserFile, '.pl', ActualFile),
		exists_file(ActualFile)
	).

				% scan_pattern_ids(+File, -PatternIds)
				%   Collect PatternId values of any ac_pattern/3 facts in File.
				%   Used to retract old definitions prior to (re)loading.

scan_pattern_ids(File, PatternIds) :-
	setup_call_cleanup(
		open(File, read, In),
		scan_pattern_ids_stream(In, [], Rev),
		close(In)
	),
	sort(Rev, PatternIds).

scan_pattern_ids_stream(In, Acc, Out) :-
	read_term(In, Term, [syntax_errors(dec10)]),
	(   Term == end_of_file
	->  Out = Acc
	;   (   Term = ac_pattern(PatternId, _Args, _Goal)
		->  scan_pattern_ids_stream(In, [PatternId|Acc], Out)
		;   scan_pattern_ids_stream(In, Acc, Out)
		)
	).

				% pattern_sig(+PatternId, -PatternSig)
				%   PatternSig is a stable, content-derived signature identifying the
				%   exact pattern definition loaded for PatternId.

pattern_sig(PatternId, PatternSig) :-
	ac_pattern_sig(PatternId, PatternSig), !.
pattern_sig(_PatternId, nosig).

				% refresh_pattern_sigs
				%   Recompute signatures for all currently-defined patterns.
				%   This supports the case where multiple versions of patterns may be
				%   loaded across sessions.

refresh_pattern_sigs :-
	retractall(ac_pattern_sig(_,_)),
	forall(ac_pattern(PatternId, Args, Goal),
			( compute_pattern_sig(Args, Goal, Sig),
			assertz(ac_pattern_sig(PatternId, Sig)) )).

				% compute_pattern_sig(+Args, +Goal, -Sig)
				%   Compute sha256 over canonical term text. Normalize the hash to an atom.

compute_pattern_sig(Args, Goal, Sig) :-
	with_output_to(string(S), write_canonical(pattern(Args, Goal))),
	crypto_data_hash(S, Hash0, [algorithm(sha256), encoding(utf8)]),
	( string(Hash0) -> atom_string(Sig, Hash0)
	; Sig = Hash0 ).
