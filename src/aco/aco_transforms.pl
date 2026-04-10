:- module(aco_transforms, [
    aco_file_to_doc/2,       % +InFile, -AcoDoc
    aco_doc_to_file/2,       % +OutFile, +AcoDoc
    aco_observe_doc/5,       % +Ti, +AcoDoc, +Scope, +Opts, -Cands
    aco_transform_doc/7,     % +Ti, +AcoDoc, +Scope, +Cand, +Opts, -NewDoc, -Report

    t1_observe_file/2,       % +InFile, -Cands
    t1_slim_evidence_file/3, % +EvidenceTarget, +InFile, +OutFile
    t2_observe_file/2,       % +InFile, -Cands
    t2_insert_goal_file/3,   % +Target, +InFile, +OutFile
    t6_modularize_file/3,    % +Goals, +InFile, +OutFile
    t7_observe_file/2,       % +InFile, -Cands
    t7_insert_strategy_file/3, % +GoalTarget, +InFile, +OutFile

    kelly_assess_candidate/4, % +AcoDoc, +Cand, -KDef, -KEffect
    kelly_rank_candidates/3,  % +Cands, +Policy, -Ranked
    kelly_observe_and_rank_file/6 % +Tis, +InFile, +Scope, +Opts, +Policy, -Ranked
]).



:- use_module(library(readutil)).
:- use_module(library(lists)).
:- use_module(library(apply)).
:- use_module(library(pcre)).

:- use_module(aco_core).
:- use_module(aco_apl).

/*
   ACO Transformations Framework
   -----------------------------

   Canonical internal representation:
     aco_doc(Units, Meta)
       Units: list of parsed Case/Module units
       Meta:  meta{lines:Lines}

   Lines are the authoritative source for serialization and for
   line-preserving transforms.
*/

% ----------------------------------------------------------------------
% File I/O wrappers
% ----------------------------------------------------------------------

aco_file_to_doc(InFile0, aco_doc(Units, meta{lines:Lines})) :-
    must_be(atom, InFile0),
    strip_cr_atom(InFile0, InFile),
    read_file_to_string(InFile, Raw, [newline(detect)]),
    split_string_preserve_empty(Raw, Lines),
    parse_units_from_raw(InFile, Raw, Units).


aco_doc_to_file(OutFile0, aco_doc(_Units, Meta)) :-
    must_be(atom, OutFile0),
    must_be(dict, Meta),
    _{lines:Lines} :< Meta,
    strip_cr_atom(OutFile0, OutFile),
    write_lines_lf(OutFile, Lines).


% ----------------------------------------------------------------------
% Transformation dispatch (doc-level)
% ----------------------------------------------------------------------

aco_observe_doc(t1, AcoDoc, Scope, Opts, Cands) :-
    !,
    observe_t1_doc(AcoDoc, Scope, Opts, Cands).

aco_observe_doc(t2, AcoDoc, Scope, Opts, Cands) :-
    !,
    observe_t2_doc(AcoDoc, Scope, Opts, Cands).

aco_observe_doc(t7, AcoDoc, Scope, Opts, Cands) :-
    !,
    observe_t7_doc(AcoDoc, Scope, Opts, Cands).

aco_observe_doc(Ti, _AcoDoc, _Scope, _Opts, _Cands) :-
    throw(error(observe_not_implemented(Ti), _)).

aco_transform_doc(t6, AcoDoc, Scope, Cand, Opts, NewDoc, Report) :-
    !,
    apply_t6_doc(AcoDoc, Scope, Cand, Opts, NewDoc, Report).

aco_transform_doc(t1, AcoDoc0, Scope, Cand, Opts, NewDoc, Report) :-
    !,
    apply_t1_doc(AcoDoc0, Scope, Cand, Opts, NewDoc, Report).

aco_transform_doc(t2, AcoDoc0, Scope, Cand, Opts, NewDoc, Report) :-
    !,
    apply_t2_doc(AcoDoc0, Scope, Cand, Opts, NewDoc, Report).

aco_transform_doc(t7, AcoDoc0, Scope, Cand, Opts, NewDoc, Report) :-
    !,
    apply_t7_doc(AcoDoc0, Scope, Cand, Opts, NewDoc, Report).

aco_transform_doc(Ti, _AcoDoc, _Scope, _Cand, _Opts, _NewDoc, _Report) :-
    throw(error(transform_not_implemented(Ti), _)).


% ----------------------------------------------------------------------
% Temporary entry point for regression-driving without touching command_etb
% ----------------------------------------------------------------------

t1_observe_file(InFile, Cands) :-
    aco_file_to_doc(InFile, Doc),
    aco_observe_doc(t1, Doc, file_scope, [], Cands).


t1_slim_evidence_file(EvidenceTarget0, InFile, OutFile) :-
    normalize_evidence_target(EvidenceTarget0, EvidenceId),
    aco_file_to_doc(InFile, Doc0),
    Cand = t1_cand(evidence(EvidenceId)),
    aco_transform_doc(t1, Doc0, file_scope, Cand, [], Doc1, _Report),
    aco_doc_to_file(OutFile, Doc1), !.


t2_observe_file(InFile, Cands) :-
    aco_file_to_doc(InFile, Doc),
    aco_observe_doc(t2, Doc, file_scope, [], Cands), !.


t2_insert_goal_file(Target0, InFile, OutFile) :-
    normalize_t2_target(Target0, Target),
    aco_file_to_doc(InFile, Doc0),
    Cand = t2_cand(Target),
    aco_transform_doc(t2, Doc0, file_scope, Cand, [], Doc1, _Report),
    aco_doc_to_file(OutFile, Doc1), !.


t6_modularize_file(Goals0, InFile, OutFile) :-
    normalize_goals_arg(Goals0, Goals),
	    aco_file_to_doc(InFile, Doc0),
    Cand = t6_cand(goals(Goals)),
    aco_transform_doc(t6, Doc0, file_scope, Cand, [], Doc1, _Report),
	    aco_doc_to_file(OutFile, Doc1).


t7_observe_file(InFile, Cands) :-
    aco_file_to_doc(InFile, Doc),
    aco_observe_doc(t7, Doc, file_scope, [], Cands), !.


t7_insert_strategy_file(Target0, InFile, OutFile) :-
    normalize_goal_target(Target0, GoalId),
    aco_file_to_doc(InFile, Doc0),
    Cand = t7_cand(goal(GoalId)),
    aco_transform_doc(t7, Doc0, file_scope, Cand, [], Doc1, _Report),
    aco_doc_to_file(OutFile, Doc1), !.



kelly_observe_and_rank_file(Tis, InFile, Scope, Opts, Policy, Ranked) :-
    must_be(list, Tis),
    aco_file_to_doc(InFile, Doc),
    findall(C,
        ( member(Ti, Tis),
          aco_observe_doc(Ti, Doc, Scope, Opts, Cs),
          member(C, Cs)
        ),
        Cands0),
    maplist(kelly_assess_candidate(Doc), Cands0, KDefs, KEffects),
    maplist(cand_info, Cands0, KDefs, KEffects, Infos),
    kelly_rank_candidates(Infos, Policy, Ranked), !.

cand_info(Cand, KDef, KEffect, cand_info(Cand, KDef, KEffect)).


% ----------------------------------------------------------------------
% Internal: parse multi-unit ACO file into Units
% ----------------------------------------------------------------------

parse_units_from_raw(SourceName, Raw0, Units) :-
    strip_indent_directive_from_raw(Raw0, Raw1),
    aco_apl:split_aco_into_units(Raw1, Units0, _UnitMsgs),
    maplist(parse_unit(SourceName), Units0, Units).

parse_unit(SourceName, unit(Kind, Hdr, UnitText),
           aco_unit(Kind, Hdr, UnitText, Parse)) :-
    unit_text_source_name(SourceName, Kind, Hdr, SrcName),
    once( aco_core:aco_core_parse(SrcName, UnitText,
                                  IndentSpec, CaseHeaderOpt,
                                  _Headers, Nodes0,
                                  TreeEdges, RelEdges, AllEdges,
                                  _IndentMsg, _BodyMsgs, _NodeMsgs,
                                  _IndentMsgs, _RelMsgs0, _RelMsgs1) ),
    Parse = parse{
        indent_spec: IndentSpec,
        case_header: CaseHeaderOpt,
        nodes: Nodes0,
        tree_edges: TreeEdges,
        rel_edges: RelEdges,
        all_edges: AllEdges
    }.

unit_text_source_name(SourceName, case, case_header(T,_Scope), SrcName) :-
    !,
    format(atom(SrcName), '~w(case:~w)', [SourceName, T]).

unit_text_source_name(SourceName, module, module_header(N,_Formals), SrcName) :-
    !,
    format(atom(SrcName), '~w(module:~w)', [SourceName, N]).

strip_indent_directive_from_raw(Raw0, Raw1) :-
    split_string(Raw0, "\n", "", Lines0),
    (   remove_indent_directive_line(Lines0, Lines1)
    ->  atomic_list_concat(Lines1, '\n', Raw1)
    ;   Raw1 = Raw0
    ).

remove_indent_directive_line(Lines0, Lines1) :-
    % drop leading blanks/comments until we hit indent directive or first unit header
    skip_preamble(Lines0, Prefix, [Line|Rest]),
    is_indent_directive_line(Line),
    append(Prefix, Rest, Lines1).

is_indent_directive_line(Line) :-
    string_trim(Line, T),
    re_match('^indent\\(\\s*\\d+\\s*,\\s*(space|tab)\\s*\\)\\s*$', T).

skip_preamble([L|Ls], [L|Ps], R) :-
    ( string_blank(L)
    ; is_comment_line(L)
    ),
    !,
    skip_preamble(Ls, Ps, R).
skip_preamble(Ls, [], Ls).

is_comment_line(L) :-
    string_trim(L, T),
    ( sub_string(T, 0, _, _, "/*")
    ; sub_string(T, 0, _, _, "%")
    ).


% ----------------------------------------------------------------------
% T6 (modularization) implementation on aco_doc/2
% ----------------------------------------------------------------------

apply_t6_doc(aco_doc(_Units0, Meta0), Scope, Cand, _Opts, aco_doc(Units1, Meta1), Report) :-
    must_be(dict, Meta0),
    _{lines:Lines0} :< Meta0,
    apply_t6_lines(Lines0, Scope, Cand, Lines1, Report),
    atomic_list_concat(Lines1, '\n', Raw1),
    parse_units_from_raw('t6', Raw1, Units1),
    Meta1 = meta{lines:Lines1}.

observe_t7_doc(aco_doc(_Units0, Meta0), Scope, Opts, Cands) :-
    must_be(dict, Meta0),
    _{lines:Lines0} :< Meta0,
    observe_t7_lines(Lines0, Scope, Opts, Cands).


apply_t7_doc(aco_doc(Units0, Meta0), Scope, Cand, Opts, aco_doc(Units1, Meta1), Report) :-
    must_be(dict, Meta0),
    _{lines:Lines0} :< Meta0,
    apply_t7_lines(Lines0, Units0, Scope, Cand, Opts, Lines1, Report),
    atomic_list_concat(Lines1, '\n', Raw1),
    parse_units_from_raw('t7', Raw1, Units1),
    Meta1 = meta{lines:Lines1}.


observe_t2_doc(aco_doc(_Units0, Meta0), Scope, Opts, Cands) :-
    must_be(dict, Meta0),
    _{lines:Lines0} :< Meta0,
    observe_t2_lines(Lines0, Scope, Opts, Cands).


apply_t2_doc(aco_doc(Units0, Meta0), Scope, Cand, Opts, aco_doc(Units1, Meta1), Report) :-
    must_be(dict, Meta0),
    _{lines:Lines0} :< Meta0,
    apply_t2_lines(Lines0, Units0, Scope, Cand, Opts, Lines1, Report),
    atomic_list_concat(Lines1, '\n', Raw1),
    parse_units_from_raw('t2', Raw1, Units1),
    Meta1 = meta{lines:Lines1}.



apply_t6_lines(Lines0, _Scope, t6_cand(goals(Goals0)), LinesOut, Report) :-
    normalize_goals_arg(Goals0, Goals),
    index_goal_headers(Lines0, GoalIndex),
    order_goals_descendants_first(Goals, GoalIndex, GoalsOrdered),
    modularize_loop(GoalsOrdered, GoalIndex, Lines0, Lines1, ModuleUnitsRev),
    reverse(ModuleUnitsRev, ModuleUnits),
    append_module_units(Lines1, ModuleUnits, LinesOut),
    Report = t6_report{
        goals_requested: Goals,
        goals_applied: GoalsOrdered,
        modules_emitted: ModuleUnits
    }.


% ----------------------------------------------------------------------
% Goal argument normalization
% ----------------------------------------------------------------------

normalize_goals_arg(Goals0, Goals) :-
    (   is_list(Goals0)
    ->  maplist(must_be(atom), Goals0),
        Goals = Goals0
    ;   must_be(atom, Goals0),
        Goals = [Goals0]
    ).


% ----------------------------------------------------------------------
% Evidence target normalization
% ----------------------------------------------------------------------

normalize_evidence_target(EvidenceTarget0, EvidenceId) :-
    (   EvidenceTarget0 = evidence(EvidenceId0)
    ->  must_be(atom, EvidenceId0),
        EvidenceId = EvidenceId0
    ;   must_be(atom, EvidenceTarget0),
        EvidenceId = EvidenceTarget0
    ).


% ----------------------------------------------------------------------
% Splitting/joining lines with predictable LF behavior
% ----------------------------------------------------------------------

split_string_preserve_empty(Raw, Lines) :-
    (   Raw == ""
    ->  Lines = [""]
    ;   split_string(Raw, "\n", "", Lines0),
        Lines = Lines0
    ).

write_lines_lf(File, Lines) :-
    setup_call_cleanup(
        open(File, write, Out, [encoding(utf8)]),
        (   write_lines_lf_stream(Out, Lines),
            flush_output(Out)
        ),
        close(Out)
    ).

write_lines_lf_stream(_Out, []) :-
    !.

write_lines_lf_stream(Out, [Last]) :-
    !,
    format(Out, "~s~n", [Last]).

write_lines_lf_stream(Out, [L|Ls]) :-
    format(Out, "~s\n", [L]),
    write_lines_lf_stream(Out, Ls).


strip_cr_atom(AtomIn, AtomOut) :-
    atom_codes(AtomIn, CodesIn),
    strip_cr_codes(CodesIn, CodesOut),
    atom_codes(AtomOut, CodesOut).

strip_cr_codes(Codes, Stripped) :-
    append(Stripped, [13, 10], Codes), !.
strip_cr_codes(Codes, Stripped) :-
    append(Stripped, [13], Codes), !.
strip_cr_codes(Codes, Codes) :-
    !.


% ----------------------------------------------------------------------
% Index goal headers: GoalId -> header(LineIdx, Indent, Label)
% ----------------------------------------------------------------------

index_goal_headers(Lines, GoalIndex) :-
    findall(GoalId-header(I, Indent, Label),
        ( nth0(I, Lines, Line),
          goal_header_line(Line, Indent, GoalId, Label)
        ),
        Pairs),
    dict_create(GoalIndex, goals, Pairs).

goal_header_line(Line, Indent, GoalId, Label) :-
    re_matchsub('^(\\s*)Goal\\s+([A-Za-z0-9_]+)\\s+([^:]+):\\s*$',
                Line, Sub, []),
    string_length(Sub.1, Indent),
    atom_string(GoalId, Sub.2),
    string_trim_local(Sub.3, Label).

string_trim_local(S0, S) :-
    re_replace('^\\s+'/g, '', S0, S1),
    re_replace('\\s+$'/g, '', S1, S).


% ----------------------------------------------------------------------
% Descendants-first ordering using indentation-derived depths
% ----------------------------------------------------------------------

order_goals_descendants_first(Goals, GoalIndex, GoalsOrdered) :-
    maplist(goal_depth_pair(GoalIndex), Goals, DepthPairs),
    keysort(DepthPairs, SortedAsc),
    reverse(SortedAsc, SortedDesc),
    pairs_values(SortedDesc, GoalsOrdered).

goal_depth_pair(GoalIndex, GoalId, Depth-GoalId) :-
    (   get_dict(GoalId, GoalIndex, header(_I, Indent, _Label))
    ->  Depth is Indent
    ;   throw(error(missing_goal_id(GoalId), _))
    ).


% ----------------------------------------------------------------------
% Main rewrite loop (applies in descendants-first order)
% ----------------------------------------------------------------------

modularize_loop([], _GoalIndex, Lines, Lines, []).

modularize_loop([GoalId|Rest], GoalIndex,
                Lines0, LinesOut, [ModuleUnit|MoreUnits]) :-
    find_goal_header_line(Lines0, GoalId, Indent, Label, StartIdx),
    find_subtree_end(Lines0, Indent, StartIdx, EndIdx),
    slice_lines(Lines0, StartIdx, EndIdx, SubtreeLines),
    extract_goal_body_preview(SubtreeLines, Indent, PreviewLines0),
    trim_trailing_blank_lines(PreviewLines0, PreviewLines),
    make_module_ref_lines(Indent, GoalId, Label, PreviewLines, RefLines),
    replace_range_with_lines(Lines0, StartIdx, EndIdx, RefLines, Lines1),
    module_unit_from_subtree(Label, Indent, SubtreeLines, ModuleUnit),
    modularize_loop(Rest, GoalIndex, Lines1, LinesOut, MoreUnits).


find_goal_header_line(Lines, GoalId, Indent, Label, StartIdx) :-
    nth0(StartIdx, Lines, Line),
    goal_header_line(Line, Indent, GoalId2, Label),
    GoalId2 == GoalId,
    !.

find_goal_header_line(_Lines, GoalId, _Indent, _Label, _StartIdx) :-
    throw(error(cannot_find_goal_header(GoalId), _)).


find_subtree_end(Lines, RootIndent, StartIdx, EndIdx) :-
    Start1 is StartIdx + 1,
    find_subtree_end_scan(Lines, RootIndent, Start1, EndIdx).

find_subtree_end_scan(Lines, _RootIndent, I, EndIdx) :-
    length(Lines, Len),
    I >= Len,
    !,
    EndIdx = Len.

find_subtree_end_scan(Lines, RootIndent, I, EndIdx) :-
    nth0(I, Lines, Line),
    (   header_line_any(Line, Indent2, _Type)
    ->  (   Indent2 =< RootIndent
        ->  EndIdx = I
        ;   I1 is I + 1,
            find_subtree_end_scan(Lines, RootIndent, I1, EndIdx)
        )
    ;   I1 is I + 1,
        find_subtree_end_scan(Lines, RootIndent, I1, EndIdx)
    ).


header_line_any(Line, Indent, Type) :-
    re_matchsub('^(\\s*)(Goal|Strategy|Context|Assumption|Justification|Evidence|Module)\\b',
                Line, Sub, []),
    string_length(Sub.1, Indent),
    atom_string(Type, Sub.2).


slice_lines(Lines, StartIdx, EndIdx, Slice) :-
    Len is EndIdx - StartIdx,
    length(Prefix, StartIdx),
    append(Prefix, Rest, Lines),
    length(Slice, Len),
    append(Slice, _Suffix, Rest).


replace_range_with_lines(Lines0, StartIdx, EndIdx, Insert, LinesOut) :-
    length(Prefix, StartIdx),
    append(Prefix, Rest0, Lines0),
    DropLen is EndIdx - StartIdx,
    length(Dropped, DropLen),
    append(Dropped, Suffix, Rest0),
    append(Prefix, Insert, Tmp),
    append(Tmp, Suffix, LinesOut).


indent_lines([], _Step, []).
indent_lines([L|Ls], Step, [L2|Out]) :-
    ( L == "" -> L2 = L
    ; make_spaces(Step, Spaces),
      string_concat(Spaces, L, L2)
    ),
    indent_lines(Ls, Step, Out).


make_goal_node_lines(Indent, GoalId, Label, ChildLines, BlockLines) :-
    make_spaces(Indent, Spaces),
    format(string(H), "~sGoal ~w ~s:", [Spaces, GoalId, Label]),
    BodyIndent is Indent + 2,
    make_spaces(BodyIndent, BSpaces),
    format(string(B), "~sTODO: define dischargeable claim supported by evidence.", [BSpaces]),
    append([H, B, ""], ChildLines, BlockLines).


t2_parent_goal_body_line(Lines0, GoalId, BodyLine) :-
    find_goal_header_index(Lines0, GoalId, GIdx, GIndent),
    find_subtree_end(Lines0, GIndent, GIdx, GEnd),
    slice_lines(Lines0, GIdx, GEnd, GBlock),
    (   goal_body_first_line(GBlock, BodyLine0)
    ->  BodyLine = BodyLine0
    ;   BodyLine = ""
    ),
    !.


make_goal_node_lines_t2(Indent, GoalId, Label, BodyLines0, ChildLines, BlockLines) :-
    make_spaces(Indent, Spaces),
    format(string(H), "~sGoal ~w ~s:", [Spaces, GoalId, Label]),
    BodyIndent is Indent + 2,
    make_spaces(BodyIndent, BSpaces),
    t2_prefix_body_lines(BSpaces, BodyLines0, BodyLines1),
    append([H|BodyLines1], [""|ChildLines], BlockLines).


t2_prefix_body_lines(_BSpaces, [], []).
t2_prefix_body_lines(BSpaces, [L|Ls], [L2|Out]) :-
    ( L == "" -> L2 = L
    ; format(string(L2), "~s~s", [BSpaces, L])
    ),
    t2_prefix_body_lines(BSpaces, Ls, Out).


t2_synthesize_intermediate_goal_body_lines(GoalBodyLine0, EvidenceBodyLines0, OutLines) :-
    must_be(string, GoalBodyLine0),
    must_be(list, EvidenceBodyLines0),
    exclude(string_blank, EvidenceBodyLines0, EvidenceBodyLines1),
    t2_extract_subject(GoalBodyLine0, SubjectOpt),
    t2_extract_predicates(SubjectOpt, GoalBodyLine0, EvidenceBodyLines1, PredLines0),
    ( PredLines0 == []
    -> t2_fallback_lines(GoalBodyLine0, OutLines)
    ;  OutLines = PredLines0
    ),
    !.


t2_fallback_lines(GoalBodyLine0, [L]) :-
    ( GoalBodyLine0 == ""
    -> L = "AUTHOR CHECK: The evidence supports the claim stated above."
    ;  format(string(L), "AUTHOR CHECK: The evidence supports the claim that ~s", [GoalBodyLine0])
    ).


t2_extract_subject(GoalBodyLine0, SubjectOpt) :-
    string_trim_local(GoalBodyLine0, GoalBodyLine),
    ( GoalBodyLine == ""
    -> SubjectOpt = none
    ;  re_matchsub('^(.*?)(\b(is|are|was|were|provides|provide|ensures|ensure|guarantees|guarantee|addresses|address|complies|comply|meets|meet|records|record|includes|include|identifies|identify)\b)',
                  GoalBodyLine, Sub, [caseless(true)])
    -> string_trim_local(Sub.1, Subj0),
       t2_normalize_subject(Subj0, Subj),
       ( Subj == "" -> SubjectOpt = none ; SubjectOpt = some(Subj) )
    ;  split_string(GoalBodyLine, " ", "", Ws),
       t2_take_prefix_words(Ws, 6, Ws2),
       atomic_list_concat(Ws2, ' ', Subj0),
       t2_normalize_subject(Subj0, Subj),
       ( Subj == "" -> SubjectOpt = none ; SubjectOpt = some(Subj) )
    ).


t2_normalize_subject(Subj0, Subj) :-
    string_trim_local(Subj0, S1),
    ( re_matchsub('^No\s+(.*)$', S1, Sub, [caseless(true)])
    -> string_trim_local(Sub.1, Subj)
    ;  Subj = S1
    ).


t2_take_prefix_words(Ws, N, Ws2) :-
    length(Ws2, N),
    append(Ws2, _Rest, Ws),
    !.
t2_take_prefix_words(Ws, _N, Ws).


t2_extract_predicates(SubjectOpt, _GoalBodyLine0, EvidenceBodyLines1, OutLines) :-
    atomic_list_concat(EvidenceBodyLines1, '\n', EvText0),
    string_lower(EvText0, EvText),
    t2_predicate_lines(SubjectOpt, EvText, OutLines0),
    t2_prefix_author_check(OutLines0, OutLines).


t2_prefix_author_check([], []).
t2_prefix_author_check([L|Ls], [L2|Out]) :-
    format(string(L2), "AUTHOR CHECK: ~s", [L]),
    t2_prefix_author_check(Ls, Out).


t2_predicate_lines(none, _EvText, []).
t2_predicate_lines(some(Subj), EvText, OutLines) :-
    findall(L,
        t2_predicate_line(Subj, EvText, L),
        Lines0),
    sort(Lines0, OutLines).


t2_predicate_line(Subj, EvText, L) :-
    (   sub_string(EvText, _, _, _, "encrypted")
    ;   sub_string(EvText, _, _, _, "encryption")
    ),
    format(string(L), "~s is encrypted in transit.", [Subj]).
t2_predicate_line(Subj, EvText, L) :-
    (   sub_string(EvText, _, _, _, "authenticated")
    ;   sub_string(EvText, _, _, _, "authentication")
    ),
    format(string(L), "~s uses authenticated endpoints.", [Subj]).
t2_predicate_line(Subj, EvText, L) :-
    sub_string(EvText, _, _, _, "cleartext"),
    format(string(L), "~s is not transmitted in cleartext.", [Subj]).
t2_predicate_line(Subj, EvText, L) :-
    sub_string(EvText, _, _, _, "tls"),
    format(string(L), "~s uses TLS.", [Subj]).
t2_predicate_line(Subj, EvText, L) :-
    (   sub_string(EvText, _, _, _, "cipher")
    ;   sub_string(EvText, _, _, _, "protocol version")
    ),
    format(string(L), "~s uses strong protocol versions and cipher suites.", [Subj]).
t2_predicate_line(Subj, EvText, L) :-
    (   sub_string(EvText, _, _, _, "enumerates")
    ;   sub_string(EvText, _, _, _, "identifies")
    ;   sub_string(EvText, _, _, _, "includes")
    ),
    format(string(L), "~s are enumerated/identified in the referenced model or query result.", [Subj]).
t2_predicate_line(Subj, EvText, L) :-
    sub_string(EvText, _, _, _, "review"),
    ( sub_string(EvText, _, _, _, "signed off")
    ; sub_string(EvText, _, _, _, "sign-off")
    ; sub_string(EvText, _, _, _, "signed")
    ),
    format(string(L), "~s is reviewed and signed off by the responsible role(s).", [Subj]).


% ----------------------------------------------------------------------
% ACO v1.2 module invocation + module-unit emission
% ----------------------------------------------------------------------

make_module_ref_lines(Indent, GoalId, Label, PreviewLines, RefLines) :-
    make_spaces(Indent, Spaces),
    goalid_to_module_callsite_id(GoalId, CallsiteId),
	    module_sig_from_goal_label(Label, ModuleSig),
    format(string(H), "~sModuleRef ~w [~w]:", [Spaces, CallsiteId, ModuleSig]),
    append([H|PreviewLines], [""], RefLines).


module_unit_from_subtree(Label, RootIndent, SubtreeLines, ModuleUnitLines) :-
	    module_sig_from_goal_label(Label, ModuleSig),
    format(string(ModHdr), "Module: ~w", [ModuleSig]),
    Shift is 2 - RootIndent,
    shift_lines_indent(SubtreeLines, Shift, SubtreeShifted),
    ModuleUnitLines = ["", ModHdr, "" | SubtreeShifted].


append_module_units(Lines0, [], Lines0).
append_module_units(Lines0, ModuleUnits, LinesOut) :-
    flatten(ModuleUnits, FlatMods0),
    ensure_trailing_blank_line(Lines0, Lines1),
    ensure_single_blank_line_at_end(Lines1, Lines2),
    append(Lines2, FlatMods0, Lines3),
    ensure_trailing_blank_line(Lines3, LinesOut).


ensure_trailing_blank_line(Lines0, LinesOut) :-
    (   Lines0 == []
    ->  LinesOut = [""]
    ;   append(_Init, [Last], Lines0),
        ( Last == "" -> LinesOut = Lines0 ; append(Lines0, [""], LinesOut) )
    ).


ensure_single_blank_line_at_end(Lines0, LinesOut) :-
    reverse(Lines0, Rev),
    drop_while_blank(Rev, RevTail),
    reverse(RevTail, Tail),
    append(Tail, [""], LinesOut).


drop_while_blank([""|Rest], Out) :-
    !,
    drop_while_blank(Rest, Out).
drop_while_blank(List, List).


extract_goal_body_preview([_GoalHdr|Rest], RootIndent, PreviewLines) :-
    BodyIndent is RootIndent + 2,
    take_until_child_header(Rest, BodyIndent, PreviewLines).
extract_goal_body_preview([], _RootIndent, []).


take_until_child_header([], _BodyIndent, []).
take_until_child_header([L|_Ls], BodyIndent, []) :-
    header_line_any(L, Indent2, _Type),
    Indent2 =:= BodyIndent,
    !.
take_until_child_header([L|Ls], BodyIndent, [L|Out]) :-
    take_until_child_header(Ls, BodyIndent, Out).


trim_trailing_blank_lines(Lines0, Lines) :-
    reverse(Lines0, Rev0),
    drop_while_blank(Rev0, Rev),
    reverse(Rev, Lines).


shift_lines_indent([], _N, []).
shift_lines_indent([L0|Ls0], N, [L|Ls]) :-
    shift_line_indent(L0, N, L),
    shift_lines_indent(Ls0, N, Ls).


shift_line_indent(Line0, 0, Line0) :-
    !.

shift_line_indent(Line0, N, Line) :-
    (   N > 0
    ->  make_spaces(N, Spaces),
        string_concat(Spaces, Line0, Line)
    ;   N < 0
    ->  K is -N,
        remove_leading_spaces(Line0, K, Line)
    ).


remove_leading_spaces(Line0, K, Line) :-
    string_codes(Line0, Codes0),
    remove_n_spaces(Codes0, K, Codes),
    string_codes(Line, Codes).


remove_n_spaces(Codes, 0, Codes) :-
    !.
remove_n_spaces([0' |Rest], K, Out) :-
    K > 0,
    !,
    K1 is K - 1,
    remove_n_spaces(Rest, K1, Out).
remove_n_spaces(Codes, _K, Codes).


goalid_to_module_callsite_id(GoalId, CallsiteId) :-
    atom_string(GoalId, Gs0),
    (   sub_string(Gs0, 0, 1, _, "G")
    ->  sub_string(Gs0, 1, _, 0, Suffix),
        string_concat("M", Suffix, Ms),
        atom_string(CallsiteId, Ms)
    ;   atom_concat('M_', GoalId, CallsiteId)
    ).


module_sig_from_goal_label(LabelString, ModuleSig) :-
	    must_be(string, LabelString),
	    atom_string(LabelAtom, LabelString),
	    format(atom(ModuleSig), "~w()", [LabelAtom]).


make_spaces(N, Spaces) :-
    (   N =< 0
    ->  Spaces = ""
    ;   length(Codes, N),
        maplist(=(0' ), Codes),
        string_codes(Spaces, Codes)
    ).


% ----------------------------------------------------------------------
% T1 (Evidence node slimming) - observe + rewrite
% ----------------------------------------------------------------------

/*
   Intent (T1): Slim "fat" Evidence nodes by separating:
     - the minimal artifact reference (kept under Evidence)
     - explanatory/method text (moved to a new Context sibling)
     - adequacy/sufficiency text (moved to a new Justification sibling)

   This implementation is line-preserving outside the replaced evidence span.
   It operates within a single unit; unit membership is inferred from the
   nearest preceding unit header (Case:/Module:) line.
*/

observe_t1_doc(aco_doc(_Units0, Meta0), Scope, Opts, Cands) :-
    must_be(dict, Meta0),
    _{lines:Lines0} :< Meta0,
    observe_t1_lines(Lines0, Scope, Opts, Cands).


apply_t1_doc(aco_doc(Units0, Meta0), Scope, Cand, Opts, aco_doc(Units1, Meta1), Report) :-
    must_be(dict, Meta0),
    _{lines:Lines0} :< Meta0,
    apply_t1_lines(Lines0, Units0, Scope, Cand, Opts, Lines1, Report),
    atomic_list_concat(Lines1, '\n', Raw1),
    parse_units_from_raw('t1', Raw1, Units1),
    Meta1 = meta{lines:Lines1}.


observe_t1_lines(Lines0, _Scope, Opts, Cands) :-
    t1_opts(Opts, t1_opts{min_body_lines:MinBody, require_tool_line:ReqTool}),
    findall(Cand,
        t1_candidate_from_lines(Lines0, MinBody, ReqTool, Cand),
        Cands).


t1_opts(Opts, t1_opts{min_body_lines:MinBody, require_tool_line:ReqTool}) :-
    (   member(min_body_lines(N), Opts)
    ->  must_be(integer, N), MinBody = N
    ;   MinBody = 3
    ),
    (   member(require_tool_line(B), Opts)
    ->  must_be(boolean, B), ReqTool = B
    ;   ReqTool = true
    ).


t1_candidate_from_lines(Lines0, MinBody, ReqTool,
                        t1_cand(evidence(EvidenceId), unit(UnitTag), span(StartIdx, EndIdx), indent(Indent), label(Label), features(Features))) :-
    nth0(StartIdx, Lines0, Line),
    evidence_header_line(Line, Indent, EvidenceId, Label),
    unit_tag_for_line(Lines0, StartIdx, UnitTag),
    find_subtree_end(Lines0, Indent, StartIdx, EndIdx),
    slice_lines(Lines0, StartIdx, EndIdx, SubtreeLines),
    evidence_body_lines(SubtreeLines, BodyLines0),
    exclude(string_blank, BodyLines0, BodyLines),
    length(BodyLines, BodyLen),
    BodyLen >= MinBody,
    (   ReqTool == true
    ->  evidence_body_has_tool_line(BodyLines)
    ;   true
    ),
    t1_features(BodyLines, Features).


t1_features(BodyLines, Features) :-
    ( evidence_body_has_tool_line(BodyLines) -> F1 = [has_tool_line] ; F1 = [] ),
    ( evidence_body_has_sufficiency_markers(BodyLines) -> F2 = [has_sufficiency_markers|F1] ; F2 = F1 ),
    Features = F2.


apply_t1_lines(Lines0, Units0, _Scope, t1_cand(evidence(EvidenceId)), Opts, LinesOut, Report) :-
    must_be(atom, EvidenceId),
    t1_opts(Opts, t1_opts{min_body_lines:MinBody, require_tool_line:ReqTool}),
    (   t1_candidate_for_evidence(Lines0, EvidenceId, MinBody, ReqTool, Cand)
    ->  apply_t1_candidate(Lines0, Cand, Lines1, Report0)
    ;   throw(error(no_applicable_t1_candidate(EvidenceId), _))
    ),
    enforce_unit_count_invariant(t1, Units0, Lines1),
    LinesOut = Lines1,
    Report = Report0.


t1_candidate_for_evidence(Lines0, EvidenceId, MinBody, ReqTool, Cand) :-
    t1_candidate_from_lines(Lines0, MinBody, ReqTool, Cand),
    Cand = t1_cand(evidence(EvidenceId), _Unit, _Span, _Indent, _Label, _Features),
    !.


apply_t1_candidate(Lines0,
                   t1_cand(evidence(EvidenceId), unit(UnitTag), span(StartIdx, EndIdx), indent(Indent), label(Label), features(Features)),
                   LinesOut,
                   Report) :-
    slice_lines(Lines0, StartIdx, EndIdx, SubtreeLines),
    SubtreeLines = [EvidenceHdrLine|_],
    evidence_body_lines(SubtreeLines, BodyLines0),
    partition_evidence_body(BodyLines0, SlimEvidenceBody, ContextBody, JustBody),
    derive_related_ids(Lines0, EvidenceId, CtxId, JustId),
    make_context_node_lines(Indent, CtxId, ContextBody, CtxLines),
    make_just_node_lines(Indent, JustId, JustBody, JustLines),
    make_slim_evidence_lines(EvidenceHdrLine, SlimEvidenceBody, EvidLines),
    append(CtxLines, JustLines, Tmp1),
    append(Tmp1, EvidLines, Replacement),
    replace_range_with_lines(Lines0, StartIdx, EndIdx, Replacement, LinesOut),
    Report = t1_report{
        evidence_id: EvidenceId,
        unit: UnitTag,
        span: span(StartIdx, EndIdx),
        indent: Indent,
        label: Label,
        features: Features,
        context_id: CtxId,
        justification_id: JustId
    }.


enforce_unit_count_invariant(Ti, Units0, Lines1) :-
    ( Ti == t6 -> true
    ; length(Units0, N0),
      atomic_list_concat(Lines1, '\n', Raw0),
      strip_indent_directive_from_raw(Raw0, Raw1),
      aco_apl:split_aco_into_units(Raw1, Units1, _Msgs),
      length(Units1, N1),
      (   N0 =:= N1
      ->  true
      ;   throw(error(unit_count_invariant_violated(Ti, N0, N1), _))
      )
    ).


% ----------------------------------------------------------------------
% Evidence header/body helpers
% ----------------------------------------------------------------------

evidence_header_line(Line, Indent, EvidenceId, Label) :-
    re_matchsub('^(\\s*)Evidence\\s+([A-Za-z0-9_]+)\\s+([^:]+):\\s*$',
                Line, Sub, []),
    string_length(Sub.1, Indent),
    atom_string(EvidenceId, Sub.2),
    string_trim_local(Sub.3, Label).

strategy_header_line(Line, Indent, StrategyId, Label) :-
    re_matchsub('^(\\s*)Strategy\\s+([A-Za-z0-9_]+)\\s+([^:]+):\\s*$',
                Line, Sub, []),
    string_length(Sub.1, Indent),
    atom_string(StrategyId, Sub.2),
    string_trim_local(Sub.3, Label).

context_header_line(Line, Indent, ContextId, Label) :-
    re_matchsub('^(\\s*)Context\\s+([A-Za-z0-9_]+)\\s+([^:]+):\\s*$',
                Line, Sub, []),
    string_length(Sub.1, Indent),
    atom_string(ContextId, Sub.2),
    string_trim_local(Sub.3, Label).

justification_header_line(Line, Indent, JustId, Label) :-
    re_matchsub('^(\\s*)Justification\\s+([A-Za-z0-9_]+)\\s+([^:]+):\\s*$',
                Line, Sub, []),
    string_length(Sub.1, Indent),
    atom_string(JustId, Sub.2),
    string_trim_local(Sub.3, Label).

assumption_header_line(Line, Indent, AssumpId, Label) :-
    re_matchsub('^(\\s*)Assumption\\s+([A-Za-z0-9_]+)\\s+([^:]+):\\s*$',
                Line, Sub, []),
    string_length(Sub.1, Indent),
    atom_string(AssumpId, Sub.2),
    string_trim_local(Sub.3, Label).

module_ref_header_line(Line, Indent, ModuleId, Label) :-
    re_matchsub('^(\\s*)Module\\s+([A-Za-z0-9_]+)\\s+([^:]+):\\s*$',
                Line, Sub, []),
    string_length(Sub.1, Indent),
    atom_string(ModuleId, Sub.2),
    string_trim_local(Sub.3, Label).




evidence_body_lines([_Hdr|Rest], BodyLines) :-
    BodyLines = Rest.
evidence_body_lines([], []).


string_blank(S) :-
    re_matchsub('^\\s*$', S, _Sub, []).


evidence_body_has_tool_line(BodyLines) :-
    member(L, BodyLines),
    re_matchsub('^\\s*Tool\\s*:', L, _Sub, []),
    !.


evidence_body_has_sufficiency_markers(BodyLines) :-
    member(L, BodyLines),
    re_matchsub('(?i)(therefore|sufficient|adequate|meets\\s+.*criteria|covers|coverage|trustworthy|validated|approved)', L, _Sub, []),
    !.


partition_evidence_body(BodyLines0, SlimEvidenceBody, ContextBody, JustBody) :-
    drop_leading_blanks(BodyLines0, BodyLines1),
    (   BodyLines1 = [First|Rest]
    ->  SlimEvidenceBody = [First],
        drop_leading_blanks(Rest, Rest1),
        partition_context_vs_justification(Rest1, Ctx0, Just0),
        trim_blank_edges(Ctx0, ContextBody),
        trim_blank_edges(Just0, JustBody)
    ;   SlimEvidenceBody = [],
        ContextBody = [],
        JustBody = []
    ).



drop_leading_blanks([L|Ls], Out) :-
    string_blank(L),
    !,
    drop_leading_blanks(Ls, Out).
drop_leading_blanks(Ls, Ls).

trim_blank_edges(Lines0, Lines) :-
    drop_leading_blanks(Lines0, L1),
    reverse(L1, Rev1),
    drop_leading_blanks(Rev1, Rev2),
    reverse(Rev2, Lines).


partition_context_vs_justification([], [], []).
partition_context_vs_justification([L|Ls], [L|Cs], Js) :-
    \+ evidence_line_is_justification(L),
    !,
    partition_context_vs_justification(Ls, Cs, Js).
partition_context_vs_justification([L|Ls], Cs, [L|Js]) :-
    evidence_line_is_justification(L),
    !,
    partition_context_vs_justification(Ls, Cs, Js).


evidence_line_is_justification(L) :-
    re_matchsub('(?i)(therefore|sufficient|adequate|meets\\s+.*criteria|covers|coverage|trustworthy|validated|approved|acceptance)', L, _Sub, []).



% ----------------------------------------------------------------------
% T2 — Evidence-discharging goal introduction
% ----------------------------------------------------------------------

observe_t2_lines(Lines0, _Scope, Opts, Cands) :-
    t2_opts(Opts, t2_opts{require_tool_line:ReqTool}),
    findall(Cand,
        t2_candidate_from_lines(Lines0, ReqTool, Cand),
        Cands).


t2_opts(Opts, t2_opts{require_tool_line:ReqTool}) :-
    (   member(require_tool_line(B), Opts)
    ->  must_be(boolean, B), ReqTool = B
    ;   ReqTool = true
    ).


t2_candidate_from_lines(Lines0, ReqTool,
                        t2_cand(pair(goal(GoalId), evidence(EvidenceId)),
                                unit(UnitTag),
                                span(StartIdx, EndIdx),
                                indent(Indent),
                                parent_indent(ParentIndent),
                                features(Features))) :-
    nth0(StartIdx, Lines0, Line),
    evidence_header_line(Line, Indent, EvidenceId, _Label),
    unit_tag_for_line(Lines0, StartIdx, UnitTag),
    find_subtree_end(Lines0, Indent, StartIdx, EndIdx),
    slice_lines(Lines0, StartIdx, EndIdx, SubtreeLines),
    evidence_body_lines(SubtreeLines, BodyLines0),
    exclude(string_blank, BodyLines0, BodyLines),
    (   ReqTool == true
    ->  evidence_body_has_tool_line(BodyLines)
    ;   true
    ),
    find_parent_goal_for_line(Lines0, StartIdx, Indent, GoalId, ParentIndent),
    t2_features(Lines0, GoalId, EvidenceId, BodyLines, Features).


t2_features(Lines0, GoalId, _EvidenceId, BodyLines, Features) :-
    ( evidence_body_has_tool_line(BodyLines) -> F1 = [has_tool_line] ; F1 = [] ),
    ( goal_looks_abstract(Lines0, GoalId) -> F2 = [parent_goal_abstract|F1] ; F2 = F1 ),
    Features = F2.


apply_t2_lines(Lines0, Units0, _Scope, t2_cand(pair(goal(GoalId), evidence(EvidenceId))), Opts, LinesOut, Report) :-
    t2_opts(Opts, t2_opts{require_tool_line:ReqTool}),
    must_be(atom, GoalId),
    must_be(atom, EvidenceId),
    (   t2_candidate_for_pair(Lines0, ReqTool, GoalId, EvidenceId, Cand)
    ->  apply_t2_candidate(Lines0, Cand, Lines1, Report0)
    ;   throw(error(no_applicable_t2_candidate(GoalId, EvidenceId), _))
    ),
    enforce_unit_count_invariant(t2, Units0, Lines1),
    LinesOut = Lines1,
    Report = Report0.


t2_candidate_for_pair(Lines0, ReqTool, GoalId, EvidenceId, Cand) :-
    t2_candidate_from_lines(Lines0, ReqTool, Cand),
    Cand = t2_cand(pair(goal(GoalId), evidence(EvidenceId)), _Unit, _Span, _Indent, _PIndent, _Features),
    !.


apply_t2_candidate(Lines0,
                   t2_cand(pair(goal(GoalId), evidence(EvidenceId)),
                           unit(UnitTag),
                           span(StartIdx, EndIdx),
                           indent(Indent),
                           parent_indent(ParentIndent),
                           features(Features)),
                   LinesOut,
                   Report) :-
    evidenceid_to_stem(EvidenceId, Stem),
    next_free_id_suffix(Lines0, 'G', Stem, NewGoalId),
    derive_t2_goal_label(EvidenceId, GoalId, NewGoalLabel),
    doc_indent_step(Lines0, Step),
    NewIndent is Indent,
    ChildIndent is Indent + Step,
    slice_lines(Lines0, StartIdx, EndIdx, EvidenceLines0),
    indent_lines(EvidenceLines0, Step, EvidenceLines1),
    t2_parent_goal_body_line(Lines0, GoalId, GoalBodyLine),
    evidence_body_lines(EvidenceLines0, EvidenceBodyLines0),
    t2_synthesize_intermediate_goal_body_lines(GoalBodyLine, EvidenceBodyLines0, SynthBodyLines),
    make_goal_node_lines_t2(NewIndent, NewGoalId, NewGoalLabel, SynthBodyLines, EvidenceLines1, NewGoalBlock),
    replace_range_with_lines(Lines0, StartIdx, EndIdx, NewGoalBlock, LinesOut),
    Report = t2_report{
        parent_goal: GoalId,
        evidence_id: EvidenceId,
        new_goal_id: NewGoalId,
        unit: UnitTag,
        span: span(StartIdx, EndIdx),
        indent: NewIndent,
        child_indent: ChildIndent,
        parent_indent: ParentIndent,
        features: Features
    }.


derive_t2_goal_label(EvidenceId, GoalId, Label) :-
    format(string(Label), "evidenceDischarge(~w,~w)", [GoalId, EvidenceId]).


doc_indent_step(Lines0, Step) :-
    (   member(Line, Lines0),
        re_matchsub('^indent\\((\\d+),', Line, Sub, []),
        number_string(N, Sub.1)
    ->  Step = N
    ;   Step = 2
    ).


find_parent_goal_for_line(Lines0, StartIdx, ChildIndent, GoalId, ParentIndent) :-
    I0 is StartIdx - 1,
    between(0, I0, K),
    I is I0 - K,
    nth0(I, Lines0, Line),
    goal_header_line(Line, ParentIndent, GoalId, _Label),
    ParentIndent < ChildIndent,
    !.


goal_looks_abstract(Lines0, GoalId) :-
    % Find the goal header and the first nonblank body line within its subtree
    find_goal_header_index(Lines0, GoalId, GIdx, GIndent),
    find_subtree_end(Lines0, GIndent, GIdx, GEnd),
    slice_lines(Lines0, GIdx, GEnd, GBlock),
    goal_body_first_line(GBlock, BodyLine),
    downcase_atom(BodyLine, Lower),
    abstract_marker_present(Lower).


find_goal_header_index(Lines0, GoalId, GIdx, GIndent) :-
    atom_string(GoalId, GoalIdS),
    nth0(GIdx, Lines0, Line),
    goal_header_line(Line, GIndent, GoalIdAtom, _Label),
    atom_string(GoalIdAtom, GoalIdS),
    !.


goal_body_first_line([_Hdr|Rest], BodyLine) :-
    member(Line, Rest),
    \+ string_blank(Line),
    BodyLine = Line,
    !.


abstract_marker_present(Lower) :-
    % conservative list; extend later
    ( sub_atom(Lower, _, _, _, 'secure')
    ; sub_atom(Lower, _, _, _, 'protect')
    ; sub_atom(Lower, _, _, _, 'confidential')
    ; sub_atom(Lower, _, _, _, 'integrity')
    ; sub_atom(Lower, _, _, _, 'compliance')
    ; sub_atom(Lower, _, _, _, 'adequate')
    ; sub_atom(Lower, _, _, _, 'acceptable')
    ).


normalize_goal_target(goal(G0), G) :-
    must_be(atom, G0),
    G = G0.
normalize_goal_target(G0, G) :-
    must_be(atom, G0),
    G = G0.

normalize_t2_target(pair(goal(G), evidence(E)), pair(goal(G), evidence(E))) :-
    must_be(atom, G),
    must_be(atom, E).
normalize_t2_target(pair(goal(G), evidence(E)), pair(goal(G), evidence(E))) :-
    % allow atoms in evidence/goal wrapper?
    must_be(atom, G),
    must_be(atom, E).
normalize_t2_target(pair(goal(G0), evidence(E0)), pair(goal(G), evidence(E))) :-
    must_be(atom, G0),
    must_be(atom, E0),
    G = G0,
    E = E0.


% ----------------------------------------------------------------------
% T7 — Strategy Insertion
% ----------------------------------------------------------------------

observe_t7_lines(Lines0, _Scope, _Opts, Cands) :-
    doc_indent_step(Lines0, Step),
    findall(Cand,
        t7_candidate_from_lines(Lines0, Step, Cand),
        Cands).


t7_candidate_from_lines(Lines0, Step,
                        t7_cand(goal(GoalId),
                                unit(UnitTag),
                                span(GStart, GEnd),
                                indent(GIndent),
                                features(Features))) :-
    nth0(GStart, Lines0, Line),
    goal_header_line(Line, GIndent, GoalId, _Label),
    unit_tag_for_line(Lines0, GStart, UnitTag),
    find_subtree_end(Lines0, GIndent, GStart, GEnd),
    goal_has_support_children(Lines0, GStart, GIndent, GEnd, Step),
    \+ goal_has_strategy_child_span(Lines0, GStart, GIndent, GEnd, Step, _SIdx),
    Features = [].


goal_has_support_children(Lines0, GStart, GIndent, GEnd, Step) :-
    ChildIndent is GIndent + Step,
    Lo is GStart + 1, Hi is GEnd - 1, between(Lo, Hi, I),
    nth0(I, Lines0, L),
    \+ string_blank(L),
    indent_of_line(L, ChildIndent),
    is_supporter_header_line(L),
    !.

is_supporter_header_line(Line) :-
    ( goal_header_line(Line, _I, _Id, _Lab)
    ; evidence_header_line(Line, _I2, _Eid, _Elab)
    ; context_header_line(Line, _I3, _Cid, _Clab)
    ; justification_header_line(Line, _I4, _Jid, _Jlab)
    ; module_ref_header_line(Line, _I5, _Mid, _Mlab)
    ; assumption_header_line(Line, _I6, _Aid, _Alab)
    ).


goal_has_strategy_child_span(Lines0, GStart, GIndent, GEnd, Step, SIdx) :-
    ChildIndent is GIndent + Step,
    Lo is GStart + 1, Hi is GEnd - 1, between(Lo, Hi, I),
    nth0(I, Lines0, L),
    strategy_header_line(L, ChildIndent, _Sid, _Slab),
    SIdx = I,
    !.


apply_t7_lines(Lines0, Units0, _Scope, t7_cand(goal(GoalId)), _Opts, LinesOut, Report) :-
    must_be(atom, GoalId),
    doc_indent_step(Lines0, Step),
    (   t7_candidate_for_goal(Lines0, Step, GoalId, Cand)
    ->  apply_t7_candidate(Lines0, Step, Cand, Lines1, Report0)
    ;   throw(error(no_applicable_t7_candidate(GoalId), _))
    ),
    enforce_unit_count_invariant(t7, Units0, Lines1),
    LinesOut = Lines1,
    Report = Report0.


t7_candidate_for_goal(Lines0, Step, GoalId, Cand) :-
    t7_candidate_from_lines(Lines0, Step, Cand),
    Cand = t7_cand(goal(GoalId), _Unit, _Span, _Indent, _Features),
    !.


apply_t7_candidate(Lines0, Step,
                   t7_cand(goal(GoalId),
                           unit(UnitTag),
                           span(GStart, GEnd),
                           indent(GIndent),
                           features(Features)),
                   LinesOut,
                   Report) :-
    % Identify direct children region within the goal subtree
    goal_direct_children_span(Lines0, Step, GStart, GIndent, GEnd, CStart, CEnd),

    slice_lines(Lines0, CStart, CEnd, ChildLines0),

    ChildIndent is GIndent + Step,
    t7_partition_direct_children(ChildLines0, ChildIndent, GoalLike0, Other0),

    indent_lines(GoalLike0, Step, GoalLike1),

    goalid_to_stem(GoalId, Stem),
    next_free_id_suffix(Lines0, 'S', Stem, StrategyId),

    (   Other0 == []
    ->  StrategyChildren = GoalLike1
    ;   Step2 is Step*2,
        indent_lines(Other0, Step2, Other1),
        next_free_id_suffix(Lines0, 'G', Stem, SupportGoalId),
        derive_t7_support_goal_label(GoalId, SupportGoalLabel),
        SupportGoalIndent is GIndent + Step2,
        SupportBodyLines = ["AUTHOR CHECK: The evidence supports the claim stated above."],
        make_goal_node_lines_t2(SupportGoalIndent, SupportGoalId, SupportGoalLabel,
                               SupportBodyLines, Other1, SupportGoalBlock),
        append(GoalLike1, SupportGoalBlock, StrategyChildren)
    ),

    derive_t7_strategy_label(GoalId, StrategyLabel),
    SIndent is GIndent + Step,
    make_strategy_node_lines(SIndent, StrategyId, StrategyLabel, StrategyChildren, StrategyBlock),
    replace_range_with_lines(Lines0, CStart, CEnd, StrategyBlock, LinesOut),
    Report = t7_report{
        goal_id: GoalId,
        strategy_id: StrategyId,
        unit: UnitTag,
        span: span(CStart, CEnd),
        indent: GIndent,
        step: Step,
        features: Features
    }.


derive_t7_strategy_label(_GoalId, "insertedStrategy").

derive_t7_support_goal_label(_GoalId, "strategySupport").


% Split the direct children region into blocks at indentation ChildIndent.
% Return flattened lists of lines for goal-like blocks vs other blocks.
t7_partition_direct_children(ChildLines0, ChildIndent, GoalLikeLines, OtherLines) :-
    t7_split_blocks(ChildLines0, ChildIndent, Blocks),
    t7_partition_blocks(Blocks, GoalBlocks, OtherBlocks),
    append(GoalBlocks, GoalLikeLines),
    append(OtherBlocks, OtherLines).


t7_split_blocks([], _ChildIndent, []).
t7_split_blocks([L|Ls], ChildIndent, [Block|Blocks]) :-
    t7_take_block([L|Ls], ChildIndent, Block, Rest),
    t7_split_blocks(Rest, ChildIndent, Blocks).


t7_take_block([L|Ls], ChildIndent, [L|Block], Rest) :-
    t7_take_block_tail(Ls, ChildIndent, Block, Rest).

t7_take_block_tail([], _ChildIndent, [], []).
t7_take_block_tail([L|Ls], ChildIndent, [], [L|Ls]) :-
    \+ string_blank(L),
    indent_of_line(L, ChildIndent),
    is_supporter_header_line(L),
    !.
t7_take_block_tail([L|Ls], ChildIndent, [L|Block], Rest) :-
    t7_take_block_tail(Ls, ChildIndent, Block, Rest).


t7_partition_blocks([], [], []).
t7_partition_blocks([Block|Blocks], [Block|Goals], Others) :-
    Block = [Hdr|_],
    ( goal_header_line(Hdr, _I, _Id, _Lab)
    ; module_ref_header_line(Hdr, _I2, _Mid, _Mlab)
    ),
    !,
    t7_partition_blocks(Blocks, Goals, Others).
t7_partition_blocks([Block|Blocks], Goals, [Block|Others]) :-
    t7_partition_blocks(Blocks, Goals, Others).


goal_direct_children_span(Lines0, Step, GStart, GIndent, GEnd, CStart, CEnd) :-
    ChildIndent is GIndent + Step,
    % find first child header line at ChildIndent
    Lo is GStart + 1, Hi is GEnd - 1, between(Lo, Hi, I0),
    nth0(I0, Lines0, L0),
    \+ string_blank(L0),
    indent_of_line(L0, ChildIndent),
    is_supporter_header_line(L0),
    CStart = I0,
    !,
    % find end of the contiguous region of direct children (up to before first line with indent <= GIndent)
    find_direct_children_end(Lines0, GIndent, CStart, GEnd, CEnd).


find_direct_children_end(Lines0, GIndent, I, GEnd, CEnd) :-
    I1 is I + 1,
    (   I1 >= GEnd
    ->  CEnd = GEnd
    ;   nth0(I1, Lines0, L1),
        ( \+ string_blank(L1), line_indent(L1, IIndent), IIndent =< GIndent )
    ->  CEnd = I1
    ;   find_direct_children_end(Lines0, GIndent, I1, GEnd, CEnd)
    ).


line_indent(Line, Indent) :-
    string_codes(Line, Codes),
    prefix_spaces_len(Codes, 0, Indent).

prefix_spaces_len([], N, N).
prefix_spaces_len([C|Cs], N0, N) :-
    ( C =:= 0'  -> N1 is N0 + 1, prefix_spaces_len(Cs, N1, N)
    ; N = N0
    ).

indent_of_line(Line, Indent) :-
    string_length(Line, Len),
    Len >= Indent,
    sub_string(Line, 0, Indent, _, Prefix),
    forall(sub_string(Prefix, _, 1, _, Ch), Ch = " ").


% ----------------------------------------------------------------------
% Derived IDs and node emission
% ----------------------------------------------------------------------

derive_related_ids(Lines0, EvidenceId, CtxId, JustId) :-
    evidenceid_to_stem(EvidenceId, Stem),
    next_free_id_suffix(Lines0, 'C', Stem, CtxId),
    next_free_id_suffix(Lines0, 'J', Stem, JustId).


goalid_to_stem(GoalId, Stem) :-
    must_be(atom, GoalId),
    atom_chars(GoalId, Cs),
    Cs = ['G'|Ds],
    Ds \= [],
    maplist(char_type_digit, Ds),
    atom_chars(Stem, Ds).

char_type_digit(C) :-
    char_type(C, digit).


evidenceid_to_stem(EvidenceId, Stem) :-
    atom_string(EvidenceId, Es0),
    (   sub_string(Es0, 0, 1, _, "E")
    ->  sub_string(Es0, 1, _, 0, Suffix),
        atom_string(Stem, Suffix)
    ;   Stem = EvidenceId
    ).


next_free_id_suffix(Lines0, PrefixAtom, StemAtom, NewId) :-
    must_be(atom, PrefixAtom),
    must_be(atom, StemAtom),
    suffix_letters(Letters),
    member(Letter, Letters),
    format(atom(NewId), '~w~w~w', [PrefixAtom, StemAtom, Letter]),
    \+ id_is_defined_in_lines(Lines0, NewId),
    !.


suffix_letters([a,b,c,d,e,f,g,h,i,j,k,l,m,n,o,p,q,r,s,t,u,v,w,x,y,z]).


id_is_defined_in_lines(Lines0, Id) :-
    atom_string(Id, IdS),
    member(Line, Lines0),
    (   re_matchsub('^(\\s*)(Goal|Strategy|Context|Assumption|Justification|Evidence|Module)\\s+', Line, _Sub, [])
    ->  re_matchsub('^(\\s*)(Goal|Strategy|Context|Assumption|Justification|Evidence|Module)\\s+([A-Za-z0-9_]+)\\b', Line, Sub2, []),
        Sub2.3 == IdS
    ;   false
    ),
    !.


make_context_node_lines(_Indent, _CtxId, [], []).
make_context_node_lines(Indent, CtxId, BodyLines, Lines) :-
    make_spaces(Indent, Spaces),
    format(string(H), '~sContext ~w evidenceContext:', [Spaces, CtxId]),
    append([H|BodyLines], [''], Lines).


make_just_node_lines(_Indent, _JustId, [], []).
make_just_node_lines(Indent, JustId, BodyLines, Lines) :-
    make_spaces(Indent, Spaces),
    format(string(H), '~sJustification ~w evidenceJustification:', [Spaces, JustId]),
    append([H|BodyLines], [''], Lines).


make_slim_evidence_lines(EvidenceHdrLine, SlimBody, Lines) :-
    ( SlimBody == []
    ->  Lines0 = [EvidenceHdrLine]
    ;   Lines0 = [EvidenceHdrLine|SlimBody]
    ),
    append(Lines0, [''], Lines).

make_strategy_node_lines(Indent, StrategyId, StrategyLabel, ChildLines, OutLines) :-
    must_be(integer, Indent),
    must_be(atom, StrategyId),
    must_be(string, StrategyLabel),
    must_be(list, ChildLines),
    indent_spaces(Indent, Prefix),
    format(string(Hdr), "~sStrategy ~w ~s:", [Prefix, StrategyId, StrategyLabel]),
    % Minimal body: a single AUTHOR CHECK line, then a blank line, then re-hung children.
    format(string(Body1), "~s  AUTHOR CHECK: The evidence will show that the subclaims below are sufficient to support this goal.", [Prefix]),
    OutLines = [Hdr, Body1, "" | ChildLines].

indent_spaces(N, S) :-
    must_be(integer, N),
    N >= 0,
    length(Cs, N),
    maplist(=(' '), Cs),
    string_chars(S, Cs).


% ----------------------------------------------------------------------
% Unit tagging for candidates
% ----------------------------------------------------------------------

unit_tag_for_line(Lines0, LineIdx, unit(case, Title)) :-
    find_prev_unit_header(Lines0, LineIdx, case, Title),
    !.
unit_tag_for_line(Lines0, LineIdx, unit(module, Name)) :-
    find_prev_unit_header(Lines0, LineIdx, module, Name),
    !.
unit_tag_for_line(_Lines0, _LineIdx, unit(unknown, unknown)).


find_prev_unit_header(Lines0, LineIdx, case, TitleAtom) :-
    between(0, LineIdx, Back),
    I is LineIdx - Back,
    I >= 0,
    nth0(I, Lines0, Line),
    re_matchsub('^Case:\\s*(.+)$', Line, Sub, []),
    string_trim_local(Sub.1, TitleString),
    atom_string(TitleAtom, TitleString),
    !.

find_prev_unit_header(Lines0, LineIdx, module, NameAtom) :-
    between(0, LineIdx, Back),
    I is LineIdx - Back,
    I >= 0,
    nth0(I, Lines0, Line),
    re_matchsub('^Module:\\s*([^\\s(]+)', Line, Sub, []),
    atom_string(NameAtom, Sub.1),
    !.

kelly_assess_candidate(aco_doc(_Units0, Meta0), Cand, KDef, KEffect) :-
    must_be(dict, Meta0),
    _{lines:Lines0} :< Meta0,
    kelly_deficits_for_candidate(Lines0, Cand, KDef),
    kelly_effect_for_candidate(Cand, KEffect),
    !.

kelly_deficits_for_candidate(Lines0, Cand, kdef{k2:K2,k3:K3,k4:K4,k5:K5,k6:K6}) :-
    ( Cand = t1_cand(evidence(_EId), _Unit, span(StartIdx, _EndIdx), indent(Indent), _Label, _Features)
    -> kdef_from_evidence(Lines0, StartIdx, Indent, K2, K3, K4, K5, K6)
    ; Cand = t2_cand(pair(goal(GoalId), evidence(_EId)), _Unit, _Span, _Indent, _PIndent, _Features)
    -> kdef_from_goal(Lines0, GoalId, K2, K3, K4, K5, K6)
    ; K2=0.0, K3=0.0, K4=0.0, K5=0.0, K6=0.0
    ),
    !.

kdef_from_evidence(Lines0, StartIdx, Indent, K2, K3, K4, K5, K6) :-
    doc_indent_step(Lines0, Step),
    ( find_parent_goal_for_line(Lines0, StartIdx, Indent, GoalId, ParentIndent)
    -> ( goal_has_context_child(Lines0, GoalId, ParentIndent, Step) -> K2=0.0 ; K2=1.0 ),
       ( goal_has_strategy_child(Lines0, GoalId, ParentIndent, Step) -> K3=0.0 ; K3=1.0 ),
       ( goal_has_strategy_basis(Lines0, GoalId, ParentIndent, Step) -> K4=0.0 ; K4=1.0 ),
       ( goal_looks_abstract(Lines0, GoalId) -> K5=1.0 ; K5=0.5 )
    ; K2=0.5, K3=0.5, K4=0.5, K5=0.5
    ),
    K6 = 1.0.

kdef_from_goal(Lines0, GoalId, K2, K3, K4, K5, K6) :-
    doc_indent_step(Lines0, Step),
    find_goal_header_index(Lines0, GoalId, _GIdx, GIndent),
    ( goal_has_context_child(Lines0, GoalId, GIndent, Step) -> K2=0.0 ; K2=1.0 ),
    ( goal_has_strategy_child(Lines0, GoalId, GIndent, Step) -> K3=0.0 ; K3=1.0 ),
    ( goal_has_strategy_basis(Lines0, GoalId, GIndent, Step) -> K4=0.0 ; K4=1.0 ),
    ( goal_looks_abstract(Lines0, GoalId) -> K5=1.0 ; K5=0.5 ),
    K6 = 0.5.

goal_has_strategy_child(Lines0, GoalId, GIndent, Step) :-
    find_goal_header_index(Lines0, GoalId, GIdx, _),
    find_subtree_end(Lines0, GIndent, GIdx, GEnd),
    ChildIndent is GIndent + Step,
    Lo is GIdx + 1, Hi is GEnd - 1, between(Lo, Hi, I),
    nth0(I, Lines0, Line),
    strategy_header_line(Line, ChildIndent, _Sid, _SLabel),
    !.

goal_has_context_child(Lines0, GoalId, GIndent, Step) :-
    find_goal_header_index(Lines0, GoalId, GIdx, _),
    find_subtree_end(Lines0, GIndent, GIdx, GEnd),
    ChildIndent is GIndent + Step,
    Lo is GIdx + 1, Hi is GEnd - 1, between(Lo, Hi, I),
    nth0(I, Lines0, Line),
    context_header_line(Line, ChildIndent, _Cid, _CLabel),
    !.

goal_has_strategy_basis(Lines0, GoalId, GIndent, Step) :-
    find_goal_header_index(Lines0, GoalId, GIdx, _),
    find_subtree_end(Lines0, GIndent, GIdx, GEnd),
    SIndent is GIndent + Step,
    Lo is GIdx + 1, Hi is GEnd - 1, between(Lo, Hi, I),
    nth0(I, Lines0, Line),
    strategy_header_line(Line, SIndent, _Sid, _SLabel),
    strategy_has_justification(Lines0, I, SIndent, Step),
    !.

strategy_has_justification(Lines0, SIdx, SIndent, Step) :-
    find_subtree_end(Lines0, SIndent, SIdx, SEnd),
    JIndent is SIndent + Step,
    Lo is SIdx + 1, Hi is SEnd - 1, between(Lo, Hi, I),
    nth0(I, Lines0, Line),
    justification_header_line(Line, JIndent, _Jid, _Jlabel),
    !.

kelly_effect_for_candidate(Cand, keffect{k2:E2,k3:E3,k4:E4,k5:E5,k6:E6}) :-
    ( Cand = t1_cand(_,_,_,_,_,_) -> E2=0.0,E3=0.0,E4=0.0,E5=0.1,E6=0.8
    ; Cand = t2_cand(_,_,_,_,_,_) -> E2=0.0,E3=0.0,E4=0.0,E5=0.7,E6=0.1
        ; Cand = t7_cand(_,_,_,_,_) -> E2=0.0,E3=0.8,E4=0.0,E5=0.1,E6=0.0
; E2=0.0,E3=0.0,E4=0.0,E5=0.0,E6=0.0
    ).

synthetic_deficits_for_candidate(Cand, kdef{k2:K2,k3:K3,k4:K4,k5:K5,k6:K6}) :-
    ( Cand = t1_cand(_,_,_,_,_,_) -> K2=0.0,K3=0.0,K4=0.0,K5=0.2,K6=1.0
    ; Cand = t2_cand(_,_,_,_,_,_) -> K2=0.0,K3=0.0,K4=0.0,K5=1.0,K6=0.2
        ; Cand = t7_cand(_,_,_,_,_) -> K2=0.0,K3=1.0,K4=0.2,K5=0.1,K6=0.0
; K2=0.0,K3=0.0,K4=0.0,K5=0.0,K6=0.0
    ).

expected_benefit(kdef{k2:K2,k3:K3,k4:K4,k5:K5,k6:K6},
                 keffect{k2:E2,k3:E3,k4:E4,k5:E5,k6:E6},
                 W2,W3,W4,W5,W6, Benefit) :-
    B2 is W2*min(K2,E2),
    B3 is W3*min(K3,E3),
    B4 is W4*min(K4,E4),
    B5 is W5*min(K5,E5),
    B6 is W6*min(K6,E6),
    Benefit is B2+B3+B4+B5+B6.

churn_estimate(Cand, Churn) :-
    ( Cand = t1_cand(_,_,_,_,_,_) -> Churn = 0.2
    ; Cand = t2_cand(_,_,_,_,_,_) -> Churn = 0.3
        ; Cand = t7_cand(_,_,_,_,_) -> Churn = 0.25
; Churn = 0.5
    ).


kelly_rank_candidates(Cands0, Policy, Ranked) :-
    must_be(list, Cands0),
    must_be(list, Policy),
    maplist(kelly_score_item(Policy), Cands0, Scored),
    keysort(Scored, SortedAsc),
    reverse(SortedAsc, SortedDesc),
    maplist(score_to_ranked, SortedDesc, Ranked),
    !.

kelly_score_item(Policy, Item, Score-Item) :-
    (   Item = cand_info(Cand, KDef, KEffect)
    ->  true
    ;   Cand = Item,
        kelly_effect_for_candidate(Cand, KEffect),
        synthetic_deficits_for_candidate(Cand, KDef)
    ),
    policy_weight(Policy, k2, 4.0, W2),
    policy_weight(Policy, k3, 3.0, W3),
    policy_weight(Policy, k4, 5.0, W4),
    policy_weight(Policy, k5, 3.0, W5),
    policy_weight(Policy, k6, 2.0, W6),
    policy_weight(Policy, churn, 1.0, Wc),
    expected_benefit(KDef, KEffect, W2, W3, W4, W5, W6, Benefit),
    churn_estimate(Cand, Churn),
    Score is Benefit - (Wc * Churn).

score_to_ranked(Score-Item, ranked(Score, Item)).

policy_weight(Policy, Key, Default, W) :-
    ( member(weight(Key, W0), Policy)
    -> must_be(number, W0), W = W0
    ;  W = Default
    ).

