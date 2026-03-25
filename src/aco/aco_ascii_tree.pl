:- module(aco_ascii_tree, [
    aco_ascii_tree_from_string/4   % +SourceName, +Raw, -TreeString, +Options
]).

:- use_module(library(lists)).
:- use_module(library(pairs)).
:- use_module(aco_core, [
    aco_core_parse/15,
    compute_hierarchical_info/3,
    string_trim/2
]).

/* Options:
      mode(full | no_body | headers_only)
      aliases(on | off)

   Defaults (used by caller): mode(full), aliases(on).

   Upgrade:
     - Supports multiple compilation units in one .aco string:
         Case:   <title> — <scope>
         Module: <name>(<args>)
       Units may appear in any order. Any text before the first explicit unit
       header is treated as an implicit Case unit.
     - ASCII output shows unit boundaries explicitly.
*/

aco_ascii_tree_from_string(SourceName, Raw, TreeString, Options) :-
    tree_options_mode(Options, Mode),
    tree_options_aliases(Options, AliasFlag),

    split_aco_into_units(Raw, Units),

    maplist(render_unit(SourceName, Mode, AliasFlag), Units, UnitsLinesNested),
    flatten(UnitsLinesNested, Lines0),
    trim_trailing_blank_lines(Lines0, Lines),
    atomic_list_concat(Lines, '\n', TreeString),
    !.

tree_options_mode(Options, Mode) :-
    (   member(mode(M), Options) -> Mode = M ; Mode = full ).

tree_options_aliases(Options, Flag) :-
    (   member(aliases(on), Options)  -> Flag = on
    ;   member(aliases(off), Options) -> Flag = off
    ;   Flag = on
    ).

% ----------------------------------------------------------------------
% Unit splitting (deterministic)
% ----------------------------------------------------------------------
% Unit representation:
%   unit(case,   case_header(TitleAtom,ScopeAtom), UnitText)
%   unit(module, module_header(NameAtom,Formals),  UnitText)
%
% For module units: we do NOT include "Module:" header in UnitText.
% We inject a synthetic "Case: <module-name>" line so aco_core_parse/15
% stays stable; we print the real module header as the boundary label.

split_aco_into_units(Raw, Units) :-
    split_string(Raw, "\n", "", Lines0),
    scan_units(Lines0, none, none, [], [], UnitsRev),
    reverse(UnitsRev, Units).

% scan_units(+Lines, +CurKindOpt, +CurHdrOpt, +CurBodyRev, +UnitsAcc, -UnitsOut)
scan_units([], none, _Hdr, CurBodyRev, UnitsAcc, UnitsOut) :-
    ( CurBodyRev == [] -> UnitsOut = UnitsAcc
    ; close_open_unit(none, none, CurBodyRev, UnitsAcc, UnitsOut)
    ),
    !.
scan_units([], some(Kind), Hdr, CurBodyRev, UnitsAcc, UnitsOut) :-
    close_open_unit(some(Kind), Hdr, CurBodyRev, UnitsAcc, UnitsOut),
    !.
scan_units([L|Ls], CurKindOpt, CurHdrOpt, CurBodyRev, UnitsAcc0, UnitsOut) :-
    (   is_case_unit_header(L, Title, Scope)
    ->  close_open_unit(CurKindOpt, CurHdrOpt, CurBodyRev, UnitsAcc0, UnitsAcc1),
        scan_units(Ls, some(case), case_header(Title,Scope), [], UnitsAcc1, UnitsOut)
    ;   is_module_unit_header(L, Name, Formals)
    ->  close_open_unit(CurKindOpt, CurHdrOpt, CurBodyRev, UnitsAcc0, UnitsAcc1),
        scan_units(Ls, some(module), module_header(Name,Formals), [], UnitsAcc1, UnitsOut)
    ;   % ordinary line
        ( CurKindOpt = none ->
            % implicit case until first explicit header
            scan_units(Ls, some(case), case_header('', ''), [L|CurBodyRev], UnitsAcc0, UnitsOut)
        ;   scan_units(Ls, CurKindOpt, CurHdrOpt, [L|CurBodyRev], UnitsAcc0, UnitsOut)
        )
    ).

close_open_unit(none, _Hdr, CurBodyRev, UnitsAcc, UnitsAcc) :-
    CurBodyRev == [], !.
close_open_unit(none, _Hdr, CurBodyRev, UnitsAcc, [Unit|UnitsAcc]) :-
    reverse(CurBodyRev, BodyLines),
    unit_text_from_lines(case, case_header('', ''), BodyLines, UnitText),
    Unit = unit(case, case_header('', ''), UnitText).

close_open_unit(some(case), case_header(T,S), CurBodyRev, UnitsAcc, [Unit|UnitsAcc]) :-
    reverse(CurBodyRev, BodyLines),
    unit_text_from_lines(case, case_header(T,S), BodyLines, UnitText),
    Unit = unit(case, case_header(T,S), UnitText).

close_open_unit(some(module), module_header(N,F), CurBodyRev, UnitsAcc, [Unit|UnitsAcc]) :-
    reverse(CurBodyRev, BodyLines),
    unit_text_from_lines(module, module_header(N,F), BodyLines, UnitText),
    Unit = unit(module, module_header(N,F), UnitText).

unit_text_from_lines(case, case_header(T,S), Lines, Text) :-
    case_header_line(T,S, HLine),
    append([HLine], Lines, All),
    atomic_list_concat(All, '\n', Text).

unit_text_from_lines(module, module_header(N,_F), Lines, Text) :-
    % inject a synthetic Case: line so aco_core_parse/15 can extract a case header
    atom_string(N, NS),
    format(string(HLine), "Case: ~s", [NS]),
    append([HLine], Lines, All),
    atomic_list_concat(All, '\n', Text).

case_header_line(TitleAtom, ScopeAtom, Line) :-
    atom_string(TitleAtom, T),
    atom_string(ScopeAtom, S),
    ( S = ""
    -> format(string(Line), "Case: ~s", [T])
    ;  format(string(Line), "Case: ~s — ~s", [T, S])
    ).

is_case_unit_header(Line0, Title, Scope) :-
    aco_core:string_trim(Line0, Line),
    ( sub_string(Line, 0, 5, _, "Case:")
    ; sub_string(Line, 0, 5, _, "CASE:")
    ),
    sub_string(Line, 5, _, 0, After),
    aco_core:string_trim(After, Content),
    ( Content = "" -> Title = '', Scope = ''
    ; split_title_scope(Content, Title, Scope)
    ).

is_module_unit_header(Line0, Name, Formals) :-
    aco_core:string_trim(Line0, Line),
    ( sub_string(Line, 0, 7, _, "Module:")
    ; sub_string(Line, 0, 7, _, "MODULE:")
    ),
    sub_string(Line, 7, _, 0, After0),
    aco_core:string_trim(After0, After),
    After \= "",
    parse_module_header_rhs(After, Name, Formals).

split_title_scope(Content, Title, Scope) :-
    (   sub_string(Content, Pos, 3, After, " — ")
    ;   sub_string(Content, Pos, 3, After, " – ")
    ;   sub_string(Content, Pos, 3, After, " - ")
    ),
    !,
    sub_string(Content, 0, Pos, _, T0),
    Pos3 is Pos + 3,
    sub_string(Content, Pos3, After, 0, S0),
    aco_core:string_trim(T0, TitleStr),
    aco_core:string_trim(S0, ScopeStr),
    atom_string(Title, TitleStr),
    atom_string(Scope, ScopeStr).
split_title_scope(Content, Title, '') :-
    aco_core:string_trim(Content, TitleStr),
    atom_string(Title, TitleStr).

parse_module_header_rhs(S, Name, Formals) :-
    ( sub_string(S, P, _, _, "(")
    -> sub_string(S, 0, P, _, NameStr0),
       aco_core:string_trim(NameStr0, NameStr),
       atom_string(Name, NameStr),
       sub_string(S, P, _, 0, Tail),
       parse_paren_list(Tail, FormalsStrs),
       maplist(formal_from_string, FormalsStrs, Formals)
    ; aco_core:string_trim(S, NameStr),
      atom_string(Name, NameStr),
      Formals = []
    ).

formal_from_string(S0, FormalAtom) :-
    aco_core:string_trim(S0, S),
    atom_string(FormalAtom, S).

parse_paren_list(S, Items) :-
    aco_core:string_trim(S, S1),
    sub_string(S1, 0, 1, _, "("),
    sub_string(S1, _, 1, 0, ")"),
    sub_string(S1, 1, _, 1, Inner0),
    aco_core:string_trim(Inner0, Inner),
    ( Inner = "" -> Items = []
    ; split_string(Inner, ",", " \t", Items0),
      findall(I,
          ( member(X, Items0),
            aco_core:string_trim(X, I),
            I \= ""
          ),
          Items)
    ).

trim_trailing_blank_lines(Lines0, Lines) :-
    reverse(Lines0, Rev0),
    drop_leading_blanks(Rev0, Rev),
    reverse(Rev, Lines).

drop_leading_blanks([""|Rest], Out) :- !, drop_leading_blanks(Rest, Out).
drop_leading_blanks(Rest, Rest).

% ----------------------------------------------------------------------
% Unit rendering
% ----------------------------------------------------------------------

render_unit(SourceName, Mode, AliasFlag, unit(case, case_header(T,S), UnitText), LinesOut) :-
    aco_core_parse(SourceName, UnitText,
                   _IndentSpec, CaseHeaderOpt,
                   _Headers, Nodes0,
                   TreeEdges, _RelEdges, AllEdges,
                   _IndentMsg, _BodyMsgs, _NodeMsgs,
                   _IndentMsgs, _RelMsgs0, _RelMsgs1),
    ( Nodes0 == [], TreeEdges == [] ->
        LinesOut = []
    ;
    compute_hierarchical_info(Nodes0, Infos, _HierMsgs),
    build_tree_index(Nodes0, AllEdges, Index),
    roots_from_index(Index, RootIds),
    ascii_unit_boundary_case(T,S,CaseHeaderOpt, BoundaryLines),
    ascii_forest(RootIds, Index, Infos, Mode, AliasFlag, TreeLines),
    append(BoundaryLines, TreeLines, Lines1),
    append(Lines1, [""], LinesOut)
    ).

render_unit(SourceName, Mode, AliasFlag, unit(module, module_header(N,F), UnitText), LinesOut) :-
    aco_core_parse(SourceName, UnitText,
                   _IndentSpec, _CaseHeaderOpt,
                   _Headers, Nodes0,
                   _TreeEdges, _RelEdges, AllEdges,
                   _IndentMsg, _BodyMsgs, _NodeMsgs,
                   _IndentMsgs, _RelMsgs0, _RelMsgs1),
    compute_hierarchical_info(Nodes0, Infos, _HierMsgs),
    build_tree_index(Nodes0, AllEdges, Index),
    roots_from_index(Index, RootIds),
    ascii_unit_boundary_module(N,F, BoundaryLines),
    ascii_forest(RootIds, Index, Infos, Mode, AliasFlag, TreeLines),
    append(BoundaryLines, TreeLines, Lines1),
    append(Lines1, [""], LinesOut).

ascii_unit_boundary_case(Title, Scope, CaseHeaderOpt, Lines) :-
    ( CaseHeaderOpt = some(case_header(T2,S2)) ->
        atom_string(T2, T),
        atom_string(S2, S)
    ; atom_string(Title, T),
      atom_string(Scope, S)
    ),
    ( S = ""
    -> format(string(H), "=== Case: ~s ===", [T])
    ;  format(string(H), "=== Case: ~s — ~s ===", [T, S])
    ),
    Lines = [H, ""].

ascii_unit_boundary_module(Name, Formals, Lines) :-
    ( Formals = [] ->
        format(string(H), "=== Module: ~w ===", [Name])
    ;   findall(FS, (member(F,Formals), atom_string(F,FS)), FStrs),
        atomic_list_concat(FStrs, ",", Args),
        format(string(H), "=== Module: ~w(~w) ===", [Name, Args])
    ),
    Lines = [H, ""].

% ----------------------------------------------------------------------
% Index and roots
% ----------------------------------------------------------------------

% Index = index(NodesById, ChildMap)
build_tree_index(Nodes, TreeEdges, index(NodesById, ChildMap)) :-
    findall(Id-node(Id,Type,Label,Body,Level,Line,IterOpt),
            member(node(Id,Type,Label,Body,Level,Line,IterOpt), Nodes),
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
/*
children_of(Id, index(_,ChildMap), ChildIdsSorted) :-
    (   member(Id-Children0, ChildMap) -> ChildIds0 = Children0 ; ChildIds0 = [] ),
    sort(ChildIds0, ChildIdsSorted).
*/
% change to following to preserve source line number order
children_of(Id, index(NodesById,ChildMap), ChildIdsSorted) :-
    (   member(Id-Children0, ChildMap) -> ChildIds0 = Children0 ; ChildIds0 = [] ),
    findall(Line-ChildId,
            ( member(ChildId, ChildIds0),
                member(ChildId-node(ChildId, _Type, _Label, _Body, _Level, Line, _IterOpt), NodesById)
            ),
            LinePairs),
    keysort(LinePairs, SortedPairs),
    pairs_values(SortedPairs, ChildIdsSorted).
    

roots_from_index(index(NodesById, ChildMap), RootIds) :-
    findall(C,
            ( member(_P-Children, ChildMap),
              member(C, Children)
            ),
            ChildIds0),
    sort(ChildIds0, ChildIds),
    findall(Id,
            ( member(Id-node(Id,_,_,_,_,_,_), NodesById),
              \+ memberchk(Id, ChildIds)
            ),
            RootIds).

% ----------------------------------------------------------------------
% Forest and node rendering with options
% ----------------------------------------------------------------------

ascii_forest([], _Index, _Infos, _Mode, _AliasFlag, []).
ascii_forest([RootId|Rest], Index, Infos, Mode, AliasFlag, Lines) :-
    ascii_node_root(RootId, Index, Infos, Mode, AliasFlag, L0),
    ascii_forest_rest(Rest, Index, Infos, Mode, AliasFlag, LRest),
    append(L0, LRest, Lines).

ascii_forest_rest([], _Index, _Infos, _Mode, _AliasFlag, []).
ascii_forest_rest([RootId|Rest], Index, Infos, Mode, AliasFlag, Lines) :-
    ascii_node_root(RootId, Index, Infos, Mode, AliasFlag, L0),
    append([""], L0, L0b),     % blank line between roots inside a unit
    ascii_forest_rest(Rest, Index, Infos, Mode, AliasFlag, LRest),
    append(L0b, LRest, Lines).

ascii_node_root(Id, Index, Infos, Mode, AliasFlag, LinesOut) :-
    lookup_node(Id, Index, node(Id, Type, Label, Body, _Level, _Line, IterOpt)),
    member(hier_info(Id, CanonId, _T, _Lev, _L, _Path), Infos),
    ascii_header_text(Type, CanonId, Id, Label, IterOpt, Mode, AliasFlag, HeaderCore),
    HeaderLine = HeaderCore,
    children_of(Id, Index, ChildIds),
    ( ChildIds = [] -> BodyPrefix = "    " ; BodyPrefix = "│       " ),
    ascii_body_lines(Body, BodyPrefix, Mode, BodyLines),
    ascii_children_root(ChildIds, Index, Infos, Mode, AliasFlag, ChildrenLines),
    append([HeaderLine|BodyLines], ChildrenLines, LinesOut).

ascii_children_root([], _Index, _Infos, _Mode, _AliasFlag, []).
ascii_children_root([ChildId|Rest], Index, Infos, Mode, AliasFlag, LinesOut) :-
    ( Rest = [] -> IsLast = true ; IsLast = false ),
    ascii_node(ChildId, Index, Infos, "", IsLast, Mode, AliasFlag, ChildLines),
    ascii_children_root(Rest, Index, Infos, Mode, AliasFlag, RestLines),
    append(ChildLines, RestLines, LinesOut).

ascii_node(Id, Index, Infos, Prefix, IsLast, Mode, AliasFlag, LinesOut) :-
    lookup_node(Id, Index, node(Id, Type, Label, Body, _Level, _Line, IterOpt)),
    member(hier_info(Id, CanonId, _T, _Lev, _L, _Path), Infos),
    ascii_header_text(Type, CanonId, Id, Label, IterOpt, Mode, AliasFlag, HeaderCore),
    ( IsLast == true -> Connector = "└── " ; Connector = "├── " ),
    format(string(HeaderLine), "~s~s~s", [Prefix, Connector, HeaderCore]),
    children_of(Id, Index, ChildIds),
    ( IsLast == true
    -> string_concat(Prefix, "    ", ChildPrefix)
    ;  string_concat(Prefix, "│   ", ChildPrefix)
    ),
    string_concat(ChildPrefix, "    ", BodyPrefix),
    ascii_body_lines(Body, BodyPrefix, Mode, BodyLines),
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

ascii_header_text(Type, CanonId, OldId, Label, IterOpt, Mode, AliasFlag, Text) :-
    ascii_type_letter(Type, Letter),
    atom_string(Label, LabelStr0),
    iterator_suffix_text(IterOpt, IterSuffix),
    string_concat(LabelStr0, IterSuffix, LabelStr),
    ( Mode = headers_only
    -> format(string(Text), "~w ~w ~s", [Letter, CanonId, LabelStr])
    ;  header_alias_suffix(OldId, CanonId, AliasFlag, AliasSuffix),
       format(string(Text), "~w ~w~s ~s", [Letter, CanonId, AliasSuffix, LabelStr])
    ).

iterator_suffix_text(none, "").
iterator_suffix_text(malformed(_), "").
iterator_suffix_text(iterate(Var, Category, Iterand), Suffix) :-
    atom_string(Var, VarS),
    designator_text(Category, CatS),
    designator_text(Iterand, IterS),
    format(string(Suffix), " for each ~s:~s in ~s", [VarS, CatS, IterS]).

designator_text(Term, S) :-
    (   string(Term)
    ->  S = Term
    ;   atom(Term)
    ->  atom_string(Term, S)
    ;   number(Term)
    ->  number_string(Term, S)
    ;   Term == []
    ->  S = "[]"
    ;   is_list(Term)
    ->  maplist(designator_text, Term, Parts),
        atomic_list_concat(Parts, ',', Inner),
        format(string(S), "[~w]", [Inner])
    ;   compound(Term), functor(Term, ':', 2)
    ->  arg(1, Term, A), arg(2, Term, B),
        designator_text(A, AS), designator_text(B, BS),
        format(string(S), "~s:~s", [AS, BS])
    ;   compound(Term)
    ->  functor(Term, F, N),
        findall(AS, (between(1, N, I), arg(I, Term, A), designator_text(A, AS)), Parts),
        atomic_list_concat(Parts, ',', Inner),
        atom_string(F, FS),
        format(string(S), "~s(~w)", [FS, Inner])
    ;   term_string(Term, S)
    ).

header_alias_suffix(_OldId, _CanonId, off, "").
header_alias_suffix(OldId, CanonId, on, AliasSuffix) :-
    ( OldId == CanonId -> AliasSuffix = ""
    ; format(string(AliasSuffix), " <~w>", [OldId])
    ).

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

ascii_type_letter(goal,          'G').
ascii_type_letter(strategy,      'S').
ascii_type_letter(context,       'C').
ascii_type_letter(assumption,    'A').
ascii_type_letter(justification, 'J').
ascii_type_letter(evidence,      'E').
ascii_type_letter(module,        'M').
