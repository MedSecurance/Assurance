:- module(aco_ascii_tree, [
    aco_ascii_tree_from_string/4   % +SourceName, +Raw, -TreeString, +Options
]).

:- use_module(library(readutil)).
:- use_module(library(pairs)).
:- use_module(library(lists)).
:- use_module(aco_core, [
    aco_core_parse/15,
    compute_hierarchical_info/3,
    string_trim/2
]).

/* Options:
      mode(full | no_body | headers_only)
      aliases(on | off)

   Defaults (used by caller): mode(full), aliases(on).
*/

aco_ascii_tree_from_string(SourceName, Raw, TreeString, Options) :-
    aco_core_parse(SourceName, Raw,
                   _IndentSpec, CaseHeaderOpt,
                   _Headers, Nodes0,
                   TreeEdges, _RelEdges, _AllEdges,
                   _IndentMsg, _BodyMsgs, _NodeMsgs,
                   _IndentMsgs, _RelMsgs0, _RelMsgs1),

    compute_hierarchical_info(Nodes0, Infos, _HierMsgs),
    build_tree_index(Nodes0, TreeEdges, Index),
    roots_from_index(Index, RootIds),

    tree_options_mode(Options, Mode),
    tree_options_aliases(Options, AliasFlag),

    ascii_forest(RootIds, Index, Infos, Mode, AliasFlag, Lines),
    ascii_case_lines(CaseHeaderOpt, CaseLines),
    append(CaseLines, Lines, AllLines),
    atomic_list_concat(AllLines, '\n', TreeString).

tree_options_mode(Options, Mode) :-
    (   member(mode(M), Options)
    ->  Mode = M
    ;   Mode = full
    ).

tree_options_aliases(Options, Flag) :-
    (   member(aliases(on), Options)
    ->  Flag = on
    ;   member(aliases(off), Options)
    ->  Flag = off
    ;   Flag = on
    ).

% ----------------------------------------------------------------------
% Index and roots
% ----------------------------------------------------------------------

% Index = index(NodesById, ChildMap)
%   NodesById : [Id-node(...)]
%   ChildMap  : [ParentId-[ChildId,...]]

build_tree_index(Nodes, TreeEdges, index(NodesById, ChildMap)) :-
    findall(Id-node(Id,Type,Label,Body,Level,Line),
            member(node(Id,Type,Label,Body,Level,Line), Nodes),
            NodesById),
    findall(P-C,
            ( member(supported_by(P,C), TreeEdges)
            ; member(in_context_of(P,C), TreeEdges)
            ),
            Pairs0),
    sort(Pairs0, Pairs),
    group_pairs_by_key(Pairs, ChildMap).

lookup_node(Id, index(NodesById,_), Node) :-
    member(Id-Node, NodesById).

children_of(Id, index(_,ChildMap), ChildIdsSorted) :-
    (   member(Id-Children0, ChildMap)
    ->  ChildIds0 = Children0
    ;   ChildIds0 = []
    ),
    sort(ChildIds0, ChildIdsSorted).

% Roots = nodes that are never children, ordered by source line number.

roots_from_index(index(NodesById, ChildMap), RootIds) :-
    findall(Id-Line,
            member(Id-node(Id,_,_,_,_,Line), NodesById),
            IdLines),
    findall(C,
            ( member(_P-Children, ChildMap),
              member(C, Children)
            ),
            ChildIds0),
    sort(ChildIds0, ChildIds),
    findall(Id,
            ( member(Id-_Line, IdLines),
              \+ memberchk(Id, ChildIds)
            ),
            RootIds).

ascii_case_lines(none, []).
ascii_case_lines(some(case_header(Title, Scope)), Lines) :-
    atom_string(Title, T),
    atom_string(Scope, S),
    ( S = ""
    -> format(string(L1), "Case: ~s", [T])
    ;  format(string(L1), "Case: ~s — ~s", [T, S])
    ),
    Lines = [L1, ""].

% ----------------------------------------------------------------------
% Forest and node rendering with options
% ----------------------------------------------------------------------

% ascii_forest(+RootIds, +Index, +Infos, +Mode, +AliasFlag, -Lines)

ascii_forest([], _Index, _Infos, _Mode, _AliasFlag, []).
ascii_forest([RootId], Index, Infos, Mode, AliasFlag, Lines) :-
    !,
    ascii_node_root(RootId, Index, Infos, Mode, AliasFlag, Lines).
ascii_forest(RootIds, Index, Infos, Mode, AliasFlag, Lines) :-
    findall(Ls,
            ( append(_Before, [RootId|Rest], RootIds),
              ( Rest = [] -> IsLast = true ; IsLast = false ),
              ascii_node(RootId, Index, Infos, "", IsLast, Mode, AliasFlag, Ls)
            ),
            Nested),
    flatten(Nested, Lines).

% Root node: no connector, body gets "│   " if there are children, else 4 spaces.

ascii_node_root(Id, Index, Infos, Mode, AliasFlag, LinesOut) :-
    lookup_node(Id, Index, node(Id, Type, Label, Body, _Level, _Line)),
    member(hier_info(Id, CanonId, _T, _Lev, _L, _Path), Infos),

    ascii_header_text(Type, CanonId, Id, Label, Mode, AliasFlag, HeaderCore),
    HeaderLine = HeaderCore,

    children_of(Id, Index, ChildIds),
    ( ChildIds = [] -> BodyPrefix = "    "
    ;                 BodyPrefix = "│   "
    ),
    ascii_body_lines(Body, BodyPrefix, Mode, BodyLines),
    ascii_children_root(ChildIds, Index, Infos, Mode, AliasFlag, ChildrenLines),

    append([HeaderLine|BodyLines], ChildrenLines, LinesOut).

ascii_children_root([], _Index, _Infos, _Mode, _AliasFlag, []).
ascii_children_root([ChildId|Rest], Index, Infos, Mode, AliasFlag, LinesOut) :-
    ( Rest = [] -> IsLast = true ; IsLast = false ),
    ascii_node(ChildId, Index, Infos, "", IsLast, Mode, AliasFlag, ChildLines),
    ascii_children_root(Rest, Index, Infos, Mode, AliasFlag, RestLines),
    append(ChildLines, RestLines, LinesOut).

% Non-root node with Prefix built from “│   ” / “    ” segments.

ascii_node(Id, Index, Infos, Prefix, IsLast, Mode, AliasFlag, LinesOut) :-
    lookup_node(Id, Index, node(Id, Type, Label, Body, _Level, _Line)),
    member(hier_info(Id, CanonId, _T, _Lev, _L, _Path), Infos),

    ascii_header_text(Type, CanonId, Id, Label, Mode, AliasFlag, HeaderCore),

    ( IsLast == true -> Connector = "└── "
    ;                   Connector = "├── "
    ),
    format(string(HeaderLine),
           "~s~s~s",
           [Prefix, Connector, HeaderCore]),

    children_of(Id, Index, ChildIds),

    ( IsLast == true
    -> string_concat(Prefix, "    ", ChildPrefix)
    ;  string_concat(Prefix, "│   ", ChildPrefix)
    ),

    ascii_body_lines(Body, ChildPrefix, Mode, BodyLines),
    ascii_children(ChildIds, Index, Infos, ChildPrefix, Mode, AliasFlag, ChildrenLines),

    append([HeaderLine|BodyLines], ChildrenLines, LinesOut).

ascii_children([], _Index, _Infos, _Prefix, _Mode, _AliasFlag, []).
ascii_children([ChildId|Rest], Index, Infos, Prefix, Mode, AliasFlag, LinesOut) :-
    ( Rest = [] -> IsLast = true ; IsLast = false ),
    ascii_node(ChildId, Index, Infos, Prefix, IsLast, Mode, AliasFlag, ChildLines),
    ascii_children(Rest, Index, Infos, Prefix, Mode, AliasFlag, RestLines),
    append(ChildLines, RestLines, LinesOut).

% ----------------------------------------------------------------------
% Header + body text with options
% ----------------------------------------------------------------------

% ascii_header_text(+Type, +CanonId, +OldId, +Label, +Mode, +AliasFlag, -Text)
%
% Mode:
%   - headers_only : just letter, canonical ID, label (no alias)
%   - full/no_body : also show alias depending on AliasFlag

ascii_header_text(Type, CanonId, OldId, Label, Mode, AliasFlag, Text) :-
    ascii_type_letter(Type, Letter),
    atom_string(Label, LabelStr),
    ( Mode = headers_only
    ->  % minimal: no alias
        format(string(Text), "~w ~w ~s", [Letter, CanonId, LabelStr])
    ;   % full / no_body: alias controlled by AliasFlag
        header_alias_suffix(OldId, CanonId, AliasFlag, AliasSuffix),
        format(string(Text), "~w ~w~s ~s", [Letter, CanonId, AliasSuffix, LabelStr])
    ).

header_alias_suffix(_OldId, _CanonId, off, "").
header_alias_suffix(OldId, CanonId, on, AliasSuffix) :-
    alias_suffix_for_id(OldId, CanonId, AliasSuffix).

ascii_body_lines(_Body, _Prefix, headers_only, []) :- !.
ascii_body_lines(_Body, _Prefix, no_body,      []) :- !.
ascii_body_lines("",    _Prefix, full,         []) :- !.
ascii_body_lines(Body,  Prefix,  full,         Lines) :-
    split_string(Body, "\n", "\r", RawLines),
    exclude(=(""), RawLines, NonEmpty),
    findall(LineStr,
            ( member(T, NonEmpty),
              string_trim(T, TextTrim),
              format(string(LineStr), "~s~s", [Prefix, TextTrim])
            ),
            Lines).

% Type letter used in header text (includes Evidence)

ascii_type_letter(goal,          'G').
ascii_type_letter(strategy,      'S').
ascii_type_letter(context,       'C').
ascii_type_letter(assumption,    'A').
ascii_type_letter(justification, 'J').
ascii_type_letter(evidence,      'E').
ascii_type_letter(module,        'M').

% Alias suffix: " <OldId>" if OldId is a non-canonical user ID.

alias_suffix_for_id(OldId, CanonId, AliasSuffix) :-
    (   OldId == CanonId
    ->  AliasSuffix = ""
    ;   format(string(AliasSuffix), " <~w>", [OldId])
    ).
