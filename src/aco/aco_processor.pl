:- module(aco_processor, [
    translate_aco_file/2,          % +ACOFile, +APLFile
%    translate_aco_string/4,        % +SourceName, +String, -AplTerms, -Messages

    canonicalize_aco_file/2,       % +ACOFile, +CanonicalACOFile
    canonicalize_aco_string/4,     % +SourceName, +String, -CanonicalString, -Messages

    aco_ascii_tree_from_file/2,    % +ACOFile, -TreeString
    aco_ascii_tree_from_string/3,  % +SourceName, +String, -TreeString
    aco_ascii_tree_from_string/4,  % +SourceName, +String, -TreeString, +Options

    print_messages/1
]).

:- use_module(library(readutil)).
:- use_module(aco_core).
:- use_module(aco_ascii_tree).
:- use_module(aco_apl).

% ----------------------------------------------------------------------
% File-level wrappers
% ----------------------------------------------------------------------

translate_aco_file(ACOFile, APLFile) :-
    read_file_to_string(ACOFile, Raw, [newline(detect)]),
    once(translate_aco_string(ACOFile, Raw, AplTerms, Messages)),
    print_messages(Messages),
    setup_call_cleanup(
        open(APLFile, write, Out),
        maplist(write_term_line(Out), AplTerms),
        close(Out)
    ).

% translate_aco_string(SourceName, Raw, AplTerms, Messages) :-
%     aco_core:translate_aco_string(SourceName, Raw, AplTerms, Messages).

canonicalize_aco_file(ACOFile, CanonFile) :-
    read_file_to_string(ACOFile, Raw, [newline(detect)]),
    once(canonicalize_aco_string(ACOFile, Raw, CanonRaw, Messages)),
    print_messages(Messages),
    setup_call_cleanup(
        open(CanonFile, write, Out),
        ( format(Out, "~s", [CanonRaw]), flush_output(Out), ! ),
        close(Out)
    ).

% canonicalize_aco_string(SourceName, Raw, CanonicalRaw, Messages) :-
%     aco_core:canonicalize_aco_string(SourceName, Raw, CanonicalRaw, Messages).

aco_ascii_tree_from_file(ACOFile, TreeString) :-
    read_file_to_string(ACOFile, Raw, [newline(detect)]),
    aco_ascii_tree_from_string(ACOFile, Raw, TreeString).

aco_ascii_tree_from_string(SourceName, Raw, TreeString) :-
    aco_ascii_tree_from_string(SourceName, Raw, TreeString,
                               [mode(full), aliases(on)]).

% aco_ascii_tree_from_string(SourceName, Raw, TreeString, Options) :-
%     aco_ascii_tree:aco_ascii_tree_from_string(SourceName, Raw, TreeString, Options).

% ----------------------------------------------------------------------
% Helpers: writing and printing messages
% ----------------------------------------------------------------------

write_term_line(Out, Term) :-
    write_term(Out, Term, [fullstop(true), nl(true), quoted(true)]).

print_messages([]).
print_messages([Msg|Rest]) :-
    % Special case: stats summary (now with Evidence)
    Msg = stats_summary(_,_,_,_,_,_,_,_,_,_,_,_,_,_,_),
    !,
    print_stats_summary(Msg),
    print_messages(Rest).

print_messages([Msg|Rest]) :-
    (Msg = apl_error(_) ; Msg = apl_warning(_) ),
    !,
    format('informational: ~w~n', [Msg]),
    print_messages(Rest).

print_messages([Msg|Rest]) :-
    ( param:debug(on)
    -> format('informational: ~w~n', [Msg])
    ;   true
    ),
    print_messages(Rest).

print_stats_summary(
    stats_summary(
        TotalNodes,
        NumGoals,
        NumStrategies,
        NumContexts,
        NumAssumptions,
        NumJustifications,
        NumEvidence,
        NumModules,
        NumUndevGoals,
        NumUndevModules,
        NumTreeSupported,
        NumRelSupported,
        NumTreeContexts,
        NumRelContexts,
        NumCrossRelations
    )
) :-
    format("~n=== ACO summary ===~n", []),
    format("  Total nodes: ~d~n", [TotalNodes]),
    format("    Goals:          ~d (undeveloped: ~d)~n",
           [NumGoals, NumUndevGoals]),
    format("    Strategies:     ~d~n", [NumStrategies]),
    format("    Contexts:       ~d (tree: ~d, relation: ~d)~n",
           [NumContexts, NumTreeContexts, NumRelContexts]),
    format("    Assumptions:    ~d~n", [NumAssumptions]),
    format("    Justifications: ~d~n", [NumJustifications]),
    format("    Evidence:       ~d~n", [NumEvidence]),
    format("    Modules:        ~d (undeveloped: ~d)~n",
           [NumModules, NumUndevModules]),
    format("~n  supported_by edges:~n", []),
    format("    from indentation (tree):  ~d~n", [NumTreeSupported]),
    format("    from explicit relations:  ~d~n", [NumRelSupported]),

    format("~n  in_context_of edges:~n", []),
    format("    from indentation (tree):  ~d~n", [NumTreeContexts]),
    format("    from explicit relations:  ~d~n", [NumRelContexts]),
    
    format("~n  Cross-branch relations: ~d~n", [NumCrossRelations]),
    format("======================~n~n", []).

/*
print_stats_summary(
    stats_summary(
        TotalNodes,
        NumGoals,
        NumStrategies,
        NumContexts,
        NumAssumptions,
        NumJustifications,
        NumEvidence,
        NumModules,
        NumUndevGoals,
        NumUndevModules,
        NumTreeSupported,
        NumRelSupported,
        NumTreeContexts,
        NumRelContexts,
        NumCrossRelations
    )
) :-
    format("~n=== ACO summary ===~n", []),
    format("  Total nodes: ~d~n", [TotalNodes]),
    format("    Goals:          ~d (undeveloped: ~d)~n",
           [NumGoals, NumUndevGoals]),
    format("    Strategies:     ~d~n", [NumStrategies]),
    format("    Contexts:       ~d (tree: ~d, relation: ~d)~n",
           [NumContexts, NumTreeContexts, NumRelContexts]),
    format("    Assumptions:    ~d~n", [NumAssumptions]),
    format("    Justifications: ~d~n", [NumJustifications]),
    format("    Evidence:       ~d~n", [NumEvidence]),
    format("    Modules:        ~d (undeveloped: ~d)~n",
           [NumModules, NumUndevModules]),
    format("~n  supported_by edges:~n", []),
    format("    from indentation (tree):  ~d~n", [NumTreeSupported]),
    format("    from explicit relations:  ~d~n", [NumRelSupported]),
    format("~n  Cross-branch relations: ~d~n", [NumCrossRelations]),
    format("======================~n~n", []).
*/
