
				%
				% common access to pattern definitions
				%

:-module(patterns, [ ac_pattern/3 ]).

:- multifile ac_pattern/3.


init :-
    param:kb_patterns_dir(KBPdir), param:pattern_files(Pfiles),
    forall(member(F,Pfiles), (
        atomic_list_concat([KBPdir,'/patterns_',F], Pfile),
        ensure_loaded(Pfile) )
    ).
