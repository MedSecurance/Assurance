
				%
				% common access to pattern definitions
				%

:-module(patterns, [ ac_pattern/3, defined_patterns/1, load_patterns/1 ]).

:- dynamic([ac_pattern/3, patterns_defined/1]).
:- multifile ac_pattern/3.

				% ac_pattern(+Name, +Args, +Goal)
				%
				%	[ arg( +Name, +Type ), ... ]
				%	goal(Id, Claim, Context, Body)

init :-
    param:kb_patterns_dir(KBPdir), param:pattern_files(PreDefPfiles),
    forall(member(F,PreDefPfiles), (
        atomic_list_concat([KBPdir,'/patterns_',F], Pfile),
		assert( patterns_defined(F) ),
        ensure_loaded(Pfile) )
    ).

defined_patterns(PatSets) :- findall(PatSet, patterns_defined(PatSet), PatSets).

load_patterns(FullFile) :-
	ensure_loaded(FullFile),
	file_base_name(FullFile,Base), file_name_extension(Core,_,Base),
	atom(Core), % remember core of basename of loaded file
	(   patterns_defined(Core)
	->  retractall( patterns_defined(Core) )
	;   true
	),
	assert( patterns_defined(Core) ),
	true.
	
	