:- module(aco_apl,
    [
        aco_string_to_apl_patterns/4,  % +SourceName,+String,-Patterns,-Messages
        aco_file_to_apl_patterns/3,    % +ACOFile,-Patterns,-Messages
        aco_file_to_apl_file/2,        % +ACOFile,+APLFile
        aco_file_to_apl_file_canon/2,  % +ACOFile,+APLFile
        split_aco_into_units/3
    ]).

/*  ACO → APL translation (Case + Module compilation units)
    ------------------------------------------------------

    This module translates an ACO source into *one or more* APL patterns:

        ac_pattern(PatternId, FormalArgs, GoalTree).

    where GoalTree is:

        goal(Id, ClaimText, ContextList, BodyList)

    BodyList may contain:
        - goal/4
        - strategy/3
        - strategy/4     (iterator-bearing strategy)
        - evidence/3
        - ac_pattern_ref/2     (pattern/module call)

    New (per recent design decisions):
      * A single .aco file may contain multiple compilation units:
          - Case: <title> — <scope>          (case unit)
          - Module: name(Formal1,Formal2)    (module-definition unit)
        Units may appear in any order.
      * Module references inside a unit are written using a Module node whose
        *label* is bracketed:
          - [foo]                 (arity 0)
          - [foo({A},{B})]        (actuals; placeholders allowed)
        This is parsed and translated to: ac_pattern_ref(foo, [A,B]).

    Note: We intentionally keep this translator lightweight and tolerant:
      - We do not impose ordering constraints on units.
      - Cross-unit definition checks are done after reading the whole file.
*/

:- use_module(library(readutil)).
:- use_module(library(lists)).
:- use_module(library(pairs)).

:- use_module(aco_core).   % aco_core_parse/15, string_trim/2, is_relation_text/1
:- use_module(aco_processor, [canonicalize_aco_string/4]).

% ----------------------------------------------------------------------
% Public API
% ----------------------------------------------------------------------

aco_file_to_apl_patterns(ACOFile, Patterns, Messages) :-
    read_file_to_string(ACOFile, Raw, [newline(detect)]),
    aco_string_to_apl_patterns(ACOFile, Raw, Patterns, Messages).

aco_file_to_apl_patterns_canon(ACOFile, Patterns, Messages) :-
    read_file_to_string(ACOFile, Raw, [newline(detect)]),
    canonicalize_aco_string(ACOFile, Raw, CanonRaw, CanonMsgs),
    aco_string_to_apl_patterns(ACOFile, CanonRaw, Patterns, AplMsgs),
    append(CanonMsgs, AplMsgs, Messages).

aco_file_to_apl_file(ACOFile, APLFile) :-
    aco_file_to_apl_patterns(ACOFile, Patterns, Messages),
    print_apl_messages(Messages),
    setup_call_cleanup(
        open(APLFile, write, Out),
        ( print_apl_patterns(Out, Patterns),
          flush_output(Out),
          !
        ),
        close(Out)
    ).

aco_file_to_apl_file_canon(ACOFile, APLFile) :-
    aco_file_to_apl_patterns_canon(ACOFile, Patterns, Messages),
    print_apl_messages(Messages),
    setup_call_cleanup(
        open(APLFile, write, Out),
        ( print_apl_patterns(Out, Patterns),
          flush_output(Out),
          !
        ),
        close(Out)
    ).

% ----------------------------------------------------------------------
% Unit splitting (Case:/Module:) without depending on aco_core changes
% ----------------------------------------------------------------------

% aco_string_to_apl_patterns(+SourceName,+Raw,-Patterns,-Messages)
aco_string_to_apl_patterns(SourceName, Raw, Patterns, Messages) :-
    split_aco_into_units(Raw, Units, UnitMsgs0),
    % Build patterns per unit
    findall(Pattern,
        ( member(Unit, Units),
          once( unit_to_pattern(SourceName, Unit, Pattern) )
        ),
        Patterns0),
    % Definition checks (duplicate module name/arity)
    check_unit_definitions(Units, DefMsgs),
    append(UnitMsgs0, DefMsgs, Messages),
    Patterns = Patterns0.

% Unit representation:
%   unit(case, case_header(Title,Scope), UnitText)
%   unit(module, module_header(Name,Formals), UnitText)

split_aco_into_units(Raw, Units, Messages) :-
    split_string(Raw, "\n", "", Lines0),
    % Keep original lines; scan for unit headers
    scan_units(Lines0, none, [], [], UnitsRev, MessagesRev),
    reverse(UnitsRev, Units),
    reverse(MessagesRev, Messages).

% ----------------------------------------------------------------------
% Compatibility wrapper scan_units/6)
% ----------------------------------------------------------------------
scan_units(Lines, CurUnitOpt, CurBodyRev, UnitsAcc, Units, Msgs) :-
    scan_units(Lines, CurUnitOpt, _CurHdr, CurBodyRev, UnitsAcc, [], Units, Msgs).

scan_units([], none, _CurHdr, CurBodyRev, UnitsAcc, MsgAcc, UnitsAcc, MsgAcc) :-
    CurBodyRev == [], !.
scan_units([], some(Kind,Hdr), _CurHdr, CurBodyRev, UnitsAcc, MsgAcc, [Unit|UnitsAcc], MsgAcc) :-
    reverse(CurBodyRev, CurBody),
    unit_text_from_lines(Kind, Hdr, CurBody, UnitText),
    unit_term(Kind, Hdr, UnitText, Unit).
scan_units([L|Ls], CurUnitOpt, CurHdr, CurBodyRev, UnitsAcc0, MsgAcc0, UnitsAcc, MsgAcc) :-
    (   is_case_unit_header(L, Title, Scope)
    ->  close_open_unit(CurUnitOpt, CurHdr, CurBodyRev, UnitsAcc0, UnitsAcc1),
        scan_units(Ls, some(case, case_header(Title,Scope)),
                   case_header(Title,Scope), [], UnitsAcc1, MsgAcc0, UnitsAcc, MsgAcc)
    ;   is_module_unit_header(L, Name, Formals)
    ->  close_open_unit(CurUnitOpt, CurHdr, CurBodyRev, UnitsAcc0, UnitsAcc1),
        scan_units(Ls, some(module, module_header(Name,Formals)),
                   module_header(Name,Formals), [], UnitsAcc1, MsgAcc0, UnitsAcc, MsgAcc)
    ;   % ordinary line
        ( CurUnitOpt = none ->
            % implicit case until first explicit header
            CurUnitOpt1 = some(case, case_header('', '')),
            CurHdr1 = case_header('', ''),
            scan_units(Ls, CurUnitOpt1, CurHdr1, [L|CurBodyRev], UnitsAcc0, MsgAcc0, UnitsAcc, MsgAcc)
          ; scan_units(Ls, CurUnitOpt, CurHdr, [L|CurBodyRev], UnitsAcc0, MsgAcc0, UnitsAcc, MsgAcc)
        )
    ).

close_open_unit(none, _Hdr, CurBodyRev, UnitsAcc, UnitsAcc) :-
    CurBodyRev == [], !.
close_open_unit(none, _Hdr, CurBodyRev, UnitsAcc, [Unit|UnitsAcc]) :-
    reverse(CurBodyRev, CurBody),
    unit_text_from_lines(case, case_header('', ''), CurBody, UnitText),
    unit_term(case, case_header('', ''), UnitText, Unit).
close_open_unit(some(Kind,_), Hdr, CurBodyRev, UnitsAcc, [Unit|UnitsAcc]) :-
    reverse(CurBodyRev, CurBody),
    unit_text_from_lines(Kind, Hdr, CurBody, UnitText),
    unit_term(Kind, Hdr, UnitText, Unit).

unit_term(case,   case_header(T,S), Text, unit(case,   case_header(T,S), Text)).
unit_term(module, module_header(N,F), Text, unit(module, module_header(N,F), Text)).

unit_text_from_lines(case, case_header(T,S), Lines, Text) :-
    % keep Case: header so aco_core can extract it (even if empty)
    case_header_line(T,S, HLine),
    append([HLine], Lines, All),
    atomic_list_concat(All, '\n', Text).
unit_text_from_lines(module, module_header(N,_F), Lines, Text) :-
    % For module units, aco_core doesn't understand "Module:" as a unit header.
    % So we *do not* include that header; instead we inject a synthetic Case:
    % to keep parsing stable. We override PatternId later anyway.
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

is_module_unit_header(Line0, Name, Formals) :-
    aco_core:string_trim(Line0, Line),
    ( sub_string(Line, 0, 7, _, "Module:")
    ; sub_string(Line, 0, 7, _, "MODULE:")
    ),
    sub_string(Line, 7, _, 0, After0),
    aco_core:string_trim(After0, After),
    After \= "",
    parse_module_header_rhs(After, Name, Formals).

parse_module_header_rhs(S, Name, Formals) :-
    % Expect: name or name(Formal1,Formal2) where each formal is either
    %   Name
    % or
    %   Name: category:qualified
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

formal_from_string(S0, Formal) :-
    aco_core:string_trim(S0, S),
    (   split_formal_decl(S, NameS, CatS)
    ->  atom_string(Name, NameS),
        aco_core:parse_designator_term(CatS, Category),
        Formal = arg(Name, Category)
    ;   atom_string(Name, S),
        Formal = Name
    ).

split_formal_decl(S, NameS, CatS) :-
    sub_string(S, Pos, 1, _, ":"),
    Pos > 0,
    sub_string(S, 0, Pos, _, Name0),
    Start is Pos + 1,
    sub_string(S, Start, _, 0, Cat0),
    aco_core:string_trim(Name0, NameS0),
    aco_core:string_trim(Cat0, CatS0),
    NameS0 \= "",
    CatS0 \= "",
    NameS = NameS0,
    CatS = CatS0.

parse_paren_list(S, Items) :-
    % S begins with '(' ... ')'
    aco_core:string_trim(S, S1),
    sub_string(S1, 0, 1, _, "("),
    sub_string(S1, _, 1, 0, ")"),
    sub_string(S1, 1, _, 1, Inner0),
    aco_core:string_trim(Inner0, Inner),
    ( Inner = "" -> Items = []
    ; split_string(Inner, ",", " \t", Items0),
      % trim each
      findall(I,
          ( member(X, Items0),
            aco_core:string_trim(X, I),
            I \= ""
          ),
          Items)
    ).

% ----------------------------------------------------------------------
% Definition checks (post read, no order requirements)
% ----------------------------------------------------------------------

check_unit_definitions(Units, Messages) :-
    findall(Name/Arity,
        ( member(unit(module, module_header(Name,Formals), _), Units),
          length(Formals, Arity)
        ),
        Sig0),
    msort(Sig0, SigS),
    findall(duplicate_module(Name,Arity),
        ( append(_, [Name/Arity, Name/Arity|_], SigS) ),
        DupMsgs0),
    sort(DupMsgs0, DupMsgs),
    ( DupMsgs = [] -> Messages = []
    ; Messages = [apl_error(duplicate_module_definitions(DupMsgs))]
    ).

% ----------------------------------------------------------------------
% Unit -> Pattern
% ----------------------------------------------------------------------

unit_to_pattern(SourceName, unit(case, CaseHdr, UnitText), Pattern) :-
    unit_text_source_name(SourceName, case, CaseHdr, UnitText, SrcName),
    once( aco_core_parse(SrcName, UnitText,
                   _IndentSpec, CaseHeaderOpt,
                   _Headers, Nodes0,
                   TreeEdges, _RelEdges, _AllEdges,
                   _IndentMsg, _BodyMsgs, _NodeMsgs,
                   _IndentMsgs, _RelMsgs0, _RelMsgs1) ),

    warn_duplicate_node_ids(Nodes0, _DupMsgs),
    % optionally append DupMsgs into Messages stream

    build_node_index(Nodes0, NodesById),
    build_child_map(TreeEdges, ChildMap),
    build_context_map(TreeEdges, CtxMap),
    choose_root(Nodes0, ChildMap, RootId, _RootMessages),
    pattern_id_from_case(CaseHeaderOpt, PatternId, CaseCtx),
    build_goal_tree(RootId, NodesById, ChildMap, CtxMap,
                    [], GoalTree, _VisitedFinal, CaseCtx),
    Pattern = ac_pattern(PatternId, [], GoalTree).

unit_to_pattern(SourceName, unit(module, module_header(Name,Formals), UnitText), Pattern) :-
    unit_text_source_name(SourceName, module, module_header(Name,Formals), UnitText, SrcName),
    once( aco_core_parse(SrcName, UnitText,
                   _IndentSpec, _CaseHeaderOpt,
                   _Headers, Nodes0,
                   TreeEdges, _RelEdges, _AllEdges,
                   _IndentMsg, _BodyMsgs, _NodeMsgs,
                   _IndentMsgs, _RelMsgs0, _RelMsgs1) ),

    warn_duplicate_node_ids(Nodes0, _DupMsgs),
    % optionally append DupMsgs into Messages stream

    build_node_index(Nodes0, NodesById),
    build_child_map(TreeEdges, ChildMap),
    build_context_map(TreeEdges, CtxMap),
    choose_root(Nodes0, ChildMap, RootId, _RootMessages),
    % PatternId is module name
    PatternId = Name,
    % Formal args -> APL-style arg(Name, Category), defaulting to identifier
    findall(Arg, (member(F, Formals), formal_to_apl_arg(F, Arg)), FormalArgs),
    build_goal_tree(RootId, NodesById, ChildMap, CtxMap,
                    [], GoalTree, _VisitedFinal, []),
    Pattern = ac_pattern(PatternId, FormalArgs, GoalTree).

unit_text_source_name(SourceName, Kind, Hdr, _Text, SrcName) :-
    % purely diagnostic label
    ( Kind = case ->
        Hdr = case_header(T,_),
        format(atom(SrcName), '~w(case:~w)', [SourceName, T])
    ; Kind = module ->
        Hdr = module_header(N,_),
        format(atom(SrcName), '~w(module:~w)', [SourceName, N])
    ).


formal_to_apl_arg(arg(Name, Category), arg(Name, Category)) :- !.
formal_to_apl_arg(Name, arg(Name, identifier)).


% ----------------------------------------------------------------------
% Pretty-printing APL patterns
% ----------------------------------------------------------------------

print_apl_patterns(_Stream, []).
print_apl_patterns(Stream, [P|Ps]) :-
    print_apl_pattern(Stream, P),
    nl(Stream),
    print_apl_patterns(Stream, Ps).

print_apl_pattern(Stream, Pattern) :-
    nl(Stream),
    pp_pattern(Stream, Pattern),
    format(Stream, ".~n", []).

pp_pattern(Stream, ac_pattern(PId, Args, Goal)) :-
    format(Stream, "ac_pattern(~q,~n", [PId]),
    IndArgs is 4,
    indent(Stream, IndArgs),
    format(Stream, "[", []),
    ( Args = [] ->
        format(Stream, "],~n", [])
    ;   nl(Stream),
        IndArgElem is IndArgs + 4,
        pp_list_terms(Stream, IndArgElem, Args),
        nl(Stream),
        indent(Stream, IndArgs),
        format(Stream, "],~n", [])
    ),
    IndGoal is 4,
    indent(Stream, IndGoal),
    pp_goal(Stream, IndGoal, Goal),
    nl(Stream),
    indent(Stream, 0),
    format(Stream, ")", []).

pp_goal(Stream, Indent, goal(Id, Label, Claim, Contexts, Body)) :-
	format(Stream, "goal(~q,~n", [Id]),
	Ind1 is Indent + 4,
	indent(Stream, Ind1),
	format(Stream, "~q,~n", [Label]),
	indent(Stream, Ind1),
	format(Stream, "~q,~n", [Claim]),
	indent(Stream, Ind1),
	pp_list(Stream, Ind1, Contexts),
	format(Stream, ",~n", []),
	indent(Stream, Ind1),
	pp_list(Stream, Ind1, Body),
	nl(Stream),
	indent(Stream, Indent),
	format(Stream, ")", []).

pp_goal(Stream, Indent, goal(Id, Claim, Contexts, Body)) :-
    format(Stream, "goal(~q,~n", [Id]),
    Ind1 is Indent + 4,
    indent(Stream, Ind1),
    format(Stream, "~q,~n", [Claim]),
    indent(Stream, Ind1),
    pp_list(Stream, Ind1, Contexts),
    format(Stream, ",~n", []),
    indent(Stream, Ind1),
    pp_list(Stream, Ind1, Body),
    nl(Stream),
    indent(Stream, Indent),
    format(Stream, ")", []).

pp_strategy(Stream, Indent, strategy(Id, Label, Claim, Contexts, Body)) :-
	format(Stream, "strategy(~q,~n", [Id]),
	Ind1 is Indent + 4,
	indent(Stream, Ind1),
	format(Stream, "~q,~n", [Label]),
	indent(Stream, Ind1),
	format(Stream, "~q,~n", [Claim]),
	indent(Stream, Ind1),
	pp_list(Stream, Ind1, Contexts),
	format(Stream, ",~n", []),
	indent(Stream, Ind1),
	pp_list(Stream, Ind1, Body),
	nl(Stream),
	indent(Stream, Indent),
	format(Stream, ")", []).

pp_strategy(Stream, Indent, strategy(Claim, Iterator, Contexts, Body)) :-
    format(Stream, "strategy(~q,~n", [Claim]),
    Ind1 is Indent + 4,
    indent(Stream, Ind1),
    format(Stream, "~q,~n", [Iterator]),
    indent(Stream, Ind1),
    pp_list(Stream, Ind1, Contexts),
    format(Stream, ",~n", []),
    indent(Stream, Ind1),
    pp_list(Stream, Ind1, Body),
    nl(Stream),
    indent(Stream, Indent),
    format(Stream, ")", []).

pp_strategy(Stream, Indent, strategy(Claim, Contexts, Body)) :-
    format(Stream, "strategy(~q,~n", [Claim]),
    Ind1 is Indent + 4,
    indent(Stream, Ind1),
    pp_list(Stream, Ind1, Contexts),
    format(Stream, ",~n", []),
    indent(Stream, Ind1),
    pp_list(Stream, Ind1, Body),
    nl(Stream),
    indent(Stream, Indent),
    format(Stream, ")", []).

pp_evidence(Stream, Indent, evidence(Id, Label, Category, Desc, Contexts)) :-
	format(Stream, "evidence(~q,~n", [Id]),
	Ind1 is Indent + 4,
	indent(Stream, Ind1),
	format(Stream, "~q,~n", [Label]),
	indent(Stream, Ind1),
	format(Stream, "~q,~n", [Category]),
	indent(Stream, Ind1),
	format(Stream, "~q,~n", [Desc]),
	indent(Stream, Ind1),
	pp_list(Stream, Ind1, Contexts),
	nl(Stream),
	indent(Stream, Indent),
	format(Stream, ")", []).

pp_evidence(Stream, Indent, evidence(Category, Desc, Contexts)) :-
    format(Stream, "evidence(~q,~n", [Category]),
    Ind1 is Indent + 4,
    indent(Stream, Ind1),
    format(Stream, "~q,~n", [Desc]),
    indent(Stream, Ind1),
    pp_list(Stream, Ind1, Contexts),
    nl(Stream),
    indent(Stream, Indent),
    format(Stream, ")", []).

pp_list(Stream, _Indent, []) :-
    format(Stream, "[]", []).
pp_list(Stream, Indent, List) :-
    format(Stream, "[~n", []),
    IndElem is Indent + 4,
    pp_list_terms(Stream, IndElem, List),
    nl(Stream),
    indent(Stream, Indent),
    format(Stream, "]", []).

pp_list_terms(Stream, Indent, [X]) :-
    indent(Stream, Indent),
    pp_term(Stream, Indent, X).
pp_list_terms(Stream, Indent, [X|Xs]) :-
    indent(Stream, Indent),
    pp_term(Stream, Indent, X),
    format(Stream, ",~n", []),
    pp_list_terms(Stream, Indent, Xs).

pp_term(Stream, Indent, goal(Id, Label, Claim, Ctx, Body)) :-
	pp_goal(Stream, Indent, goal(Id, Label, Claim, Ctx, Body)).
pp_term(Stream, Indent, strategy(Id, Label, Claim, Ctx, Body)) :-
	pp_strategy(Stream, Indent, strategy(Id, Label, Claim, Ctx, Body)).
pp_term(Stream, Indent, evidence(Id, Label, Cat, Desc, Ctx)) :-
	pp_evidence(Stream, Indent, evidence(Id, Label, Cat, Desc, Ctx)).
pp_term(Stream, _Indent, ac_pattern_ref(Id, Label, Callee, Actuals)) :-
	write_term(Stream, ac_pattern_ref(Id, Label, Callee, Actuals), [quoted(true)]).

pp_term(Stream, Indent, goal(Id, Claim, Ctx, Body)) :-
    pp_goal(Stream, Indent, goal(Id, Claim, Ctx, Body)).
pp_term(Stream, Indent, strategy(Claim, Iterator, Ctx, Body)) :-
    pp_strategy(Stream, Indent, strategy(Claim, Iterator, Ctx, Body)).
pp_term(Stream, Indent, strategy(Claim, Ctx, Body)) :-
    pp_strategy(Stream, Indent, strategy(Claim, Ctx, Body)).
pp_term(Stream, Indent, evidence(Cat, Desc, Ctx)) :-
    pp_evidence(Stream, Indent, evidence(Cat, Desc, Ctx)).
pp_term(Stream, _Indent, Term) :-
    write_term(Stream, Term, [quoted(true)]).

indent(_Stream, 0) :- !.
indent(Stream, N) :-
    N > 0,
    put_char(Stream, ' '),
    N1 is N - 1,
    indent(Stream, N1).

% ----------------------------------------------------------------------
% Existing translator core (adapted only where necessary)
% ----------------------------------------------------------------------

print_apl_messages([]).
print_apl_messages([M|Ms]) :-
    format('apl-info: ~q~n', [M]),
    print_apl_messages(Ms).

/*
build_node_index(Nodes, NodesById) :-
    findall(Id-node(Id,Type,Label,Body,Level,Line,IterOpt),
            member(node(Id,Type,Label,Body,Level,Line,IterOpt), Nodes),
            NodesById).

lookup_node(Id, NodesById, Node) :-
    member(Id-Node, NodesById).
*/

build_node_index(Nodes, NodesById) :-
    % Keep first occurrence of each Id (stable)
    build_node_index_(Nodes, [], NodesByIdRev),
    reverse(NodesByIdRev, NodesById).

build_node_index_([], Acc, Acc).
build_node_index_([node(Id,Type,Label,Body,Level,Line,IterOpt)|Rest], Acc0, Acc) :-
    (   memberchk(Id-_, Acc0)
    ->  Acc1 = Acc0              % duplicate Id: ignore later duplicates
    ;   Acc1 = [Id-node(Id,Type,Label,Body,Level,Line,IterOpt)|Acc0]
    ),
    build_node_index_(Rest, Acc1, Acc).

lookup_node(Id, NodesById, Node) :-
    memberchk(Id-Node, NodesById).

warn_duplicate_node_ids(Nodes, Messages) :-
    findall(Id, member(node(Id,_,_,_,_,_,_), Nodes), Ids0),
    msort(Ids0, Ids),
    findall(Id, (append(_, [Id,Id|_], Ids)), Dups0),
    sort(Dups0, Dups),
    ( Dups == [] -> Messages = []
    ; Messages = [apl_warning(duplicate_node_ids(Dups))]
    ).

build_child_map(TreeEdges, ChildMap) :-
    findall(P-C,
            member(supported_by(P,C), TreeEdges),
            Pairs0),
    reverse(Pairs0, Pairs0R),
    keysort(Pairs0R, Pairs),
    group_pairs_by_key(Pairs, ChildMap).

children_of(Id, ChildMap, Children) :-
    (   member(Id-Childs0, ChildMap)
    ->  list_to_set(Childs0, Children)
    ;   Children = []
    ).

build_context_map(TreeEdges, CtxMap) :-
    findall(P-C,
            member(in_context_of(P,C), TreeEdges),
            Pairs0),
    reverse(Pairs0, Pairs0R),
    keysort(Pairs0R, Pairs),
    group_pairs_by_key(Pairs, CtxMap).

contexts_of(Id, CtxMap, CtxIds) :-
    (   member(Id-CtxIds0, CtxMap)
    ->  list_to_set(CtxIds0, CtxIds)
    ;   CtxIds = []
    ).

choose_root(Nodes, ChildMap, RootId, Messages) :-
    findall(Id, member(node(Id,_,_,_,_,_,_), Nodes), AllIds0),
    sort(AllIds0, AllIds),
    findall(C,
            ( member(_P-Children, ChildMap),
              member(C, Children)
            ),
            Childs0),
    sort(Childs0, Childs),
    findall(Id,
            ( member(Id, AllIds),
              \+ memberchk(Id, Childs)
            ),
            CandidateRoots0),
    roots_of_interest(CandidateRoots0, Nodes, CandidateRoots),
    (   CandidateRoots == []
    ->  Messages = [apl_warning(no_root_found)],
        RootId  = anonymous_root
    ;   CandidateRoots = [Only]
    ->  Messages = [],
        RootId   = Only
    ;   CandidateRoots = [First|Rest],
        Messages = [apl_warning(multiple_roots([First|Rest]))],
        RootId   = First
    ).

roots_of_interest(CandidateIds, Nodes, Filtered) :-
    findall(Id,
            ( member(Id, CandidateIds),
              member(node(Id,Type,_,_,_,_,_), Nodes),
              Type = goal
            ),
            Interesting),
    ( Interesting \= [] -> Filtered = Interesting
    ; Filtered = CandidateIds
    ).

pattern_id_from_case(none, 'anonymous_case', []).
pattern_id_from_case(some(case_header(TitleAtom, ScopeAtom)), PatternId, CaseCtx) :-
    atom_string(TitleAtom, TitleStr),
    title_to_slug_keep_caps(TitleStr, SlugStr),
    atom_string(PatternId, SlugStr),
    ( ScopeAtom == ''
    -> format(atom(CaseText), 'Case: ~w', [TitleAtom])
    ;  format(atom(CaseText), 'Case: ~w — ~w', [TitleAtom, ScopeAtom])
    ),
    CaseCtx = [context(CaseText)].

title_to_slug_keep_caps(Title, Slug) :-
    string_codes(Title, Codes),
    maplist(map_title_char, Codes, Mapped),
    collapse_underscores(Mapped, CleanedCodes),
    ( CleanedCodes = [] ->
        Slug = 'Anonymous'
    ; string_codes(Slug, CleanedCodes)
    ).

map_title_char(C, Out) :-
    (   char_type(C, alnum)
    ->  Out = C
    ;   Out = 0'_
    ).

collapse_underscores(Codes, Cleaned) :-
    collapse_underscores_(Codes, [], Rev),
    reverse(Rev, Cleaned0),
    trim_edge_underscores(Cleaned0, Cleaned).

collapse_underscores_([], Acc, Acc).
collapse_underscores_([0'_|Rest], [], Acc) :-
    collapse_underscores_(Rest, [], Acc).
collapse_underscores_([0'_|Rest], [0'_ | Acc], Out) :-
    collapse_underscores_(Rest, [0'_ | Acc], Out).
collapse_underscores_([0'_|Rest], Acc, Out) :-
    collapse_underscores_(Rest, [0'_|Acc], Out).
collapse_underscores_([C|Rest], Acc, Out) :-
    C \= 0'_,
    collapse_underscores_(Rest, [C|Acc], Out).

trim_edge_underscores([], []).
trim_edge_underscores([0'_|Rest], Cleaned) :-
    trim_edge_underscores(Rest, Cleaned).
trim_edge_underscores(List, Cleaned) :-
    reverse(List, Rev),
    (   Rev = [0'_|RevRest]
    ->  reverse(RevRest, Cleaned)
    ;   Cleaned = List
    ).

clean_evidence_body(Body0, BodyClean) :-
    ( Body0 == '' ; Body0 == "" ; Body0 == ' ' ; Body0 == " " ),
    !,
    BodyClean = "".
clean_evidence_body(Body0, BodyClean) :-
    ( string(Body0) -> S0 = Body0
    ; atom_string(Body0, S0)
    ),
    aco_core:string_trim(S0, S),
    ( S == ""
    ->  BodyClean = ""
    ;   split_string(S, "\n", "\r", RawLines),
        findall(LineTrim,
            (   member(Line0, RawLines),
                aco_core:string_trim(Line0, LineTrim),
                LineTrim \= "",
                \+ aco_core:is_relation_text(LineTrim)
            ),
            KeptLines),
        (   KeptLines == []
        ->  BodyClean = ""
        ;   atomic_list_concat(KeptLines, '\n', BodyClean)
        )
    ).

% ----------------------------------------------------------------------
% Goal tree building (includes module references via [foo(...)] label)
% ----------------------------------------------------------------------

build_goal_tree(Id, NodesById, ChildMap, CtxMap,
                Visited0, Goal, Visited, ExtraCtx) :-
    (   memberchk(Id, Visited0)
	->  Goal = goal(Id, '', 'Cyclic reference (omitted)', [], []),
        Visited = Visited0
    ;   lookup_node(Id, NodesById,
				    node(Id, Type, LabelAtom, Body, _Level, _Line, _IterOpt)),
        Type = goal,
        !,
        Visited1 = [Id|Visited0],
        claim_text_from_body_or_id(Body, Id, ClaimText),
        contexts_for_node(Id, NodesById, ChildMap, CtxMap, NodeCtx),
        append(ExtraCtx, NodeCtx, CtxAll),
        children_of(Id, ChildMap, ChildIds),
        build_children_terms(ChildIds, NodesById, ChildMap, CtxMap,
                             Visited1, BodyTerms, Visited),
		Goal = goal(Id, LabelAtom, ClaimText, CtxAll, BodyTerms)
    ;
        Visited1 = [Id|Visited0],
        claim_text_from_body_or_id('', Id, ClaimText2),
		lookup_node(Id, NodesById, node(Id, _Type2, LabelAtom, _Body2, _Level2, _Line2, _IterOpt2)),
        contexts_for_node(Id, NodesById, ChildMap, CtxMap, NodeCtx2),
        children_of(Id, ChildMap, ChildIds2),
        build_children_terms(ChildIds2, NodesById, ChildMap, CtxMap,
                             Visited1, BodyTerms2, Visited),
		Goal = goal(Id, LabelAtom, ClaimText2, NodeCtx2, BodyTerms2)
    ).

claim_text_from_body_or_id(Body, Id, ClaimText) :-
    ( Body \= '',
      Body \= ""
    -> ClaimText = Body
    ; atom_string(Id, IdStr),
      ClaimText = IdStr
    ).

build_children_terms([], _NodesById, _ChildMap, _CtxMap, Visited, [], Visited).

% Structural abstractions
build_children_terms([IfId,ElseId|Rest], NodesById, ChildMap, CtxMap,
                     Visited0, [Term|Terms], VisitedOut) :-
    lookup_node(IfId, NodesById, node(IfId, if, _IfLabel, _IfBody, _IfLev, _IfLine, IfIterOpt)),
    lookup_node(ElseId, NodesById, node(ElseId, else, _ElseLabel, _ElseBody, _ElseLev, _ElseLine, _ElseIterOpt)),
    !,
    if_condition_term(IfIterOpt, Cond),
    branch_term_for_if_wrapper(IfId, NodesById, ChildMap, CtxMap, Visited0, TrueBranch, _IgnoredNestedElse, Visited1),
    branch_term_for_wrapper(ElseId, NodesById, ChildMap, CtxMap, Visited1, FalseBranch, Visited2),
    Term = conditional(Cond, TrueBranch, FalseBranch),
    build_children_terms(Rest, NodesById, ChildMap, CtxMap, Visited2, Terms, VisitedOut).

build_children_terms([ChildId|Rest], NodesById, ChildMap, CtxMap,
                     Visited0, [Term|Terms], VisitedOut) :-
    lookup_node(ChildId, NodesById, node(ChildId, if, _IfLabel, _IfBody, _IfLev, _IfLine, IfIterOpt)),
    !,
    if_condition_term(IfIterOpt, Cond),
    branch_term_for_if_wrapper(ChildId, NodesById, ChildMap, CtxMap, Visited0, TrueBranch, MaybeFalseBranch, Visited1),
    (   MaybeFalseBranch = some(FalseBranch)
    ->  Term = conditional(Cond, TrueBranch, FalseBranch)
    ;   Term = conditional([cond(Cond, TrueBranch)])
    ),
    build_children_terms(Rest, NodesById, ChildMap, CtxMap, Visited1, Terms, VisitedOut).

build_children_terms([ChildId|Rest], NodesById, ChildMap, CtxMap,
                     Visited0, [Term|Terms], VisitedOut) :-
    lookup_node(ChildId, NodesById, node(ChildId, conditionals, _Label, _Body, _Lev, _Line, _IterOpt)),
    !,
    children_of(ChildId, ChildMap, CondIds),
    build_conditional_group_terms(CondIds, NodesById, ChildMap, CtxMap, Visited0, CondTerms, Visited1),
    Term = conditional(CondTerms),
    build_children_terms(Rest, NodesById, ChildMap, CtxMap, Visited1, Terms, VisitedOut).

build_children_terms([ChildId|Rest], NodesById, ChildMap, CtxMap,
                     Visited0, [Term|Terms], VisitedOut) :-
    lookup_node(ChildId, NodesById, node(ChildId, alternatives, _Label, _Body, _Lev, _Line, _IterOpt)),
    !,
    children_of(ChildId, ChildMap, AltIds),
    build_children_terms(AltIds, NodesById, ChildMap, CtxMap, Visited0, AltTerms, Visited1),
    Term = alternatives(AltTerms),
    build_children_terms(Rest, NodesById, ChildMap, CtxMap, Visited1, Terms, VisitedOut).

build_children_terms([ChildId|Rest], NodesById, ChildMap, CtxMap,
                     Visited0, [Term|Terms], VisitedOut) :-
    lookup_node(ChildId, NodesById,
                node(ChildId, goal, _Label, _Body, _Lev, _Line, _IterOpt)),
    !,
    build_goal_tree(ChildId, NodesById, ChildMap, CtxMap,
                    Visited0, Term, Visited1, []),
    build_children_terms(Rest, NodesById, ChildMap, CtxMap,
                         Visited1, Terms, VisitedOut).

build_children_terms([ChildId|Rest], NodesById, ChildMap, CtxMap,
                    Visited0, [Term|Terms], VisitedOut) :-
    lookup_node(ChildId, NodesById,
                node(ChildId, goal_ref, TargetAtom, _Body, _Lev, _Line, _IterOpt)),
    !,
    Term = goal_ref(TargetAtom),
    Visited1 = [ChildId|Visited0],
    build_children_terms(Rest, NodesById, ChildMap, CtxMap,
                         Visited1, Terms, VisitedOut).

build_children_terms([ChildId|Rest], NodesById, ChildMap, CtxMap,
                    Visited0, [Term|Terms], VisitedOut) :-
    lookup_node(ChildId, NodesById,
                node(ChildId, module_ref, LabelAtom, Body, _Lev, _Line, _IterOpt)),
    !,
    % Treat Module nodes as module references (pattern refs).
    % Accept both bracketed labels "[foo]" and plain labels "foo".
    atom_string(LabelAtom, LabelStr0),
    aco_core:string_trim(LabelStr0, LabelStr),
    ( parse_module_ref_label_any(LabelStr, Callee, Actuals)
    -> true
    ;  % If label is somehow empty/garbage, degrade gracefully:
        Callee = LabelAtom, Actuals = []
    ),
    % Prefer the indented body text as the visible label for the ref leaf.
    % If absent, fall back to the label itself.
    ( Body \= '', Body \= ""
    -> LabelP = Body
    ;  LabelP = LabelStr
    ),
    Term = ac_pattern_ref(ChildId, LabelP, Callee, Actuals),
    Visited1 = [ChildId|Visited0],
    build_children_terms(Rest, NodesById, ChildMap, CtxMap,
                        Visited1, Terms, VisitedOut).


% build_children_terms([ChildId|Rest], NodesById, ChildMap, CtxMap,
%                      Visited0, [Term|Terms], VisitedOut) :-
%     lookup_node(ChildId, NodesById,
%                 node(ChildId, module, LabelAtom, _Body, _Lev, _Line)),
%     !,
%     % Module node under a goal/module is treated as a module reference if
%     % its label is bracketed: [foo] or [foo({A},{B})]
%     atom_string(LabelAtom, LabelStr),
%     ( parse_module_ref_label(LabelStr, Callee, Actuals)
%     -> Term = ac_pattern_ref(ChildId, LabelAtom, Callee, Actuals),
%        Visited1 = [ChildId|Visited0]
%     ;  % otherwise, treat it like an ordinary goal-ish node (fallback)
%        build_goal_tree(ChildId, NodesById, ChildMap, CtxMap,
%                        Visited0, Term, Visited1, [])
%     ),
%     build_children_terms(Rest, NodesById, ChildMap, CtxMap,
%                          Visited1, Terms, VisitedOut).

build_children_terms([ChildId|Rest], NodesById, ChildMap, CtxMap,
                     Visited0, [Term|Terms], VisitedOut) :-
    lookup_node(ChildId, NodesById,
				node(ChildId, strategy, LabelAtom, Body, _Lev, _Line, IterOpt)),
    !,
		build_strategy_tree(ChildId, LabelAtom, Body, IterOpt, NodesById, ChildMap, CtxMap,
                        Visited0, Term, Visited1),
    build_children_terms(Rest, NodesById, ChildMap, CtxMap,
                         Visited1, Terms, VisitedOut).

build_children_terms([ChildId|Rest], NodesById, ChildMap, CtxMap,
                     Visited0, [Term|Terms], VisitedOut) :-
    lookup_node(ChildId, NodesById,
                node(ChildId, evidence, Label, Body, _Lev, _Line, _IterOpt)),
    !,
    build_evidence_term(ChildId, Label, Body, NodesById, ChildMap, CtxMap, Term),
    Visited1 = [ChildId|Visited0],
    build_children_terms(Rest, NodesById, ChildMap, CtxMap,
                         Visited1, Terms, VisitedOut).

build_children_terms([ChildId|Rest], NodesById, ChildMap, CtxMap,
                     Visited0, Terms, VisitedOut) :-
    lookup_node(ChildId, NodesById,
                node(ChildId, Type, _Label, _Body, _Lev, _Line, _IterOpt)),
    (Type = context ; Type = assumption ; Type = justification),
    !,
    build_children_terms(Rest, NodesById, ChildMap, CtxMap,
                         Visited0, Terms, VisitedOut).

build_children_terms([ChildId|Rest], NodesById, ChildMap, CtxMap,
                     Visited0, Terms, VisitedOut) :-
    format(user_error,
           'apl-warning: skipping unsupported node type for id ~w~n',
           [ChildId]),
    build_children_terms(Rest, NodesById, ChildMap, CtxMap,
                         Visited0, Terms, VisitedOut).

if_condition_term(if(Cond), Cond) :- !.
if_condition_term(_, true).

branch_term_for_wrapper(WrapperId, NodesById, ChildMap, CtxMap, Visited0, Branch, VisitedOut) :-
    children_of(WrapperId, ChildMap, ChildIds),
    build_children_terms(ChildIds, NodesById, ChildMap, CtxMap, Visited0, Terms, VisitedOut),
    branch_from_terms(WrapperId, Terms, Branch).

branch_term_for_if_wrapper(IfId, NodesById, ChildMap, CtxMap,
                           Visited0, TrueBranch, MaybeFalseBranch, VisitedOut) :-
    children_of(IfId, ChildMap, ChildIds0),
    split_else_child_ids(ChildIds0, NodesById, ThenIds, ElseIds),
    build_children_terms(ThenIds, NodesById, ChildMap, CtxMap,
                         Visited0, ThenTerms, Visited1),
    branch_from_terms(IfId, ThenTerms, TrueBranch),
    (   ElseIds = [ElseId]
    ->  branch_term_for_wrapper(ElseId, NodesById, ChildMap, CtxMap,
                                Visited1, FalseBranch, VisitedOut),
        MaybeFalseBranch = some(FalseBranch)
    ;   MaybeFalseBranch = none,
        VisitedOut = Visited1
    ).

split_else_child_ids([], _NodesById, [], []).
split_else_child_ids([ChildId|Rest], NodesById, ThenIds, [ChildId]) :-
    lookup_node(ChildId, NodesById, node(ChildId, else, _Label, _Body, _Lev, _Line, _IterOpt)),
    !,
    ThenIds = Rest.
split_else_child_ids([ChildId|Rest], NodesById, [ChildId|ThenRest], ElseIds) :-
    split_else_child_ids(Rest, NodesById, ThenRest, ElseIds).

branch_from_terms(_WrapperId, [Only], Only) :- !.
branch_from_terms(WrapperId, [], goal(WrapperId, '', WrapperId, [], [])) :- !.
branch_from_terms(WrapperId, Terms, goal(WrapperId, '', WrapperId, [], Terms)).

build_conditional_group_terms([], _NodesById, _ChildMap, _CtxMap, Visited, [], Visited).
build_conditional_group_terms([ChildId|Rest], NodesById, ChildMap, CtxMap, Visited0, CondTerms, VisitedOut) :-
    lookup_node(ChildId, NodesById, node(ChildId, if, _Label, _Body, _Lev, _Line, IfIterOpt)),
    !,
    if_condition_term(IfIterOpt, Cond),
    branch_term_for_wrapper(ChildId, NodesById, ChildMap, CtxMap, Visited0, Branch, Visited1),
    CondTerms = [cond(Cond, Branch)|RestTerms],
    build_conditional_group_terms(Rest, NodesById, ChildMap, CtxMap, Visited1, RestTerms, VisitedOut).
build_conditional_group_terms([ChildId|Rest], NodesById, ChildMap, CtxMap, Visited0, CondTerms, VisitedOut) :-
    lookup_node(ChildId, NodesById, node(ChildId, else, _Label, _Body, _Lev, _Line, _IterOpt)),
    !,
    build_conditional_group_terms(Rest, NodesById, ChildMap, CtxMap, Visited0, CondTerms, VisitedOut).
build_conditional_group_terms([_ChildId|Rest], NodesById, ChildMap, CtxMap, Visited0, CondTerms, VisitedOut) :-
    build_conditional_group_terms(Rest, NodesById, ChildMap, CtxMap, Visited0, CondTerms, VisitedOut).

% Module reference label parsing:
%   "[foo]"                    -> Callee=foo, Actuals=[]
%   "[foo({A},{B})]"           -> Callee=foo, Actuals=[A,B]
% Spaces are ignored around tokens.
% Actuals are *names* (atoms) suitable for ac_pattern_ref/2, so "{A}" => A.

parse_module_ref_label(LabelStr0, Callee, Actuals) :-
    aco_core:string_trim(LabelStr0, LabelStr),
    string_length(LabelStr, L),
    L >= 2,
    sub_string(LabelStr, 0, 1, _, "["),
    sub_string(LabelStr, _, 1, 0, "]"),
    sub_string(LabelStr, 1, _, 1, Inner0),
    aco_core:string_trim(Inner0, Inner),
    Inner \= "",
    (   sub_string(Inner, P, _, _, "(")
    ->  sub_string(Inner, 0, P, _, Name0),
        aco_core:string_trim(Name0, Name),
        atom_string(Callee, Name),
        sub_string(Inner, P, _, 0, Tail),
        parse_paren_list(Tail, Args0),
        maplist(actual_from_string, Args0, Actuals)
    ;   atom_string(Callee, Inner),
        Actuals = []
    ).

% Accept either:
%   "[foo]" / "[foo({A},{B})]"   (existing bracketed syntax)
% or:
%   "foo" / "foo({A},{B})"       (plain syntax, used by "Module M1 foo:")
parse_module_ref_label_any(LabelStr0, Callee, Actuals) :-
    aco_core:string_trim(LabelStr0, LabelStr),
    (   parse_module_ref_label(LabelStr, Callee, Actuals)
    ->  true
    ;   parse_module_ref_label_plain(LabelStr, Callee, Actuals)
    ).

parse_module_ref_label_plain(Inner0, Callee, Actuals) :-
    aco_core:string_trim(Inner0, Inner),
    Inner \= "",
    (   sub_string(Inner, P, _, _, "(")
    ->  sub_string(Inner, 0, P, _, Name0),
        aco_core:string_trim(Name0, Name),
        atom_string(Callee, Name),
        sub_string(Inner, P, _, 0, Tail),
        parse_paren_list(Tail, Args0),
        maplist(actual_from_string, Args0, Actuals)
    ;   atom_string(Callee, Inner),
        Actuals = []
    ).

actual_from_string(S0, Atom) :-
    aco_core:string_trim(S0, S1),
    % accept {X} or X
    ( sub_string(S1, 0, 1, _, "{"),
      sub_string(S1, _, 1, 0, "}")
    -> sub_string(S1, 1, _, 1, Inner),
       aco_core:string_trim(Inner, X),
       atom_string(Atom, X)
    ; atom_string(Atom, S1)
    ).

build_strategy_tree(Id, LabelAtom, Body, IterOpt, NodesById, ChildMap, CtxMap,
                    Visited0, Strategy, VisitedOut) :-
    (   memberchk(Id, Visited0)
    ->  Strategy = strategy(Id, LabelAtom, 'Cyclic strategy (omitted)', [], []),
        VisitedOut = Visited0
    ;   Visited1 = [Id|Visited0],
        claim_text_from_body_or_id(Body, Id, ClaimText),
        contexts_for_node(Id, NodesById, ChildMap, CtxMap, Ctx),
        children_of(Id, ChildMap, ChildIds),
        build_children_terms(ChildIds, NodesById, ChildMap, CtxMap,
                             Visited1, BodyTerms, VisitedOut),
        (   IterOpt = iterate(_Var, _Category, _Iterand)
        ->  Strategy = strategy(ClaimText, IterOpt, Ctx, BodyTerms)
        ;   Strategy = strategy(Id, LabelAtom, ClaimText, Ctx, BodyTerms)
        )
    ).

build_evidence_term(Id, LabelAtom, Body, NodesById, ChildMap, CtxMap, Evidence) :-
    Category = LabelAtom,
    clean_evidence_body(Body, BodyClean),
    ( BodyClean \= '', BodyClean \= ""
    -> Desc0 = BodyClean
    ;  atom_string(LabelAtom, Desc0)
    ),
    Desc = Desc0,
    % contexts
    % (we keep existing behaviour)
    contexts_for_node(Id, NodesById, ChildMap, CtxMap, Ctx),
    Evidence = evidence(Id, LabelAtom, Category, Desc, Ctx).

contexts_for_node(Id, NodesById, ChildMap, CtxMap, ContextTerms) :-
    contexts_of(Id, CtxMap, CtxIds1),
    children_of(Id, ChildMap, ChildIds),
    findall(CId,
            ( member(CId, ChildIds),
              lookup_node(CId, NodesById,
                          node(CId, Type, _Label, _Body, _Lev, _Line, _IterOpt)),
              ( Type = context
              ; Type = assumption
              ; Type = justification
              )
            ),
            CtxIds2),
    append(CtxIds1, CtxIds2, CtxIdsAll0),
    sort(CtxIdsAll0, CtxIdsAll),
    build_context_terms(CtxIdsAll, NodesById, ContextTerms).

build_context_terms([], _NodesById, []).
build_context_terms([CtxId|Rest], NodesById, [Term|Terms]) :-
    lookup_node(CtxId, NodesById,
				node(CtxId, Type, LabelAtom, Body, _Level, _Line, _IterOpt)),
	context_term(Type, CtxId, LabelAtom, Body, Term),
    !,
    build_context_terms(Rest, NodesById, Terms).
build_context_terms([_CtxId|Rest], NodesById, Terms) :-
    build_context_terms(Rest, NodesById, Terms).

context_term(context,      Id, Label, Body, context(Id, Label, Text))       :- context_text(Body, Text).
context_term(assumption,   Id, Label, Body, assumption(Id, Label, Text))    :- context_text(Body, Text).
context_term(justification,Id, Label, Body, justification(Id, Label, Text)) :- context_text(Body, Text).

context_text(Body, Text) :-
    ( Body \= '',
      Body \= ""
    -> Text = Body
    ;  Text = ''
    ).
