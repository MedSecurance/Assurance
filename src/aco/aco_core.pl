:- module(aco_core, [
    % High-level string APIs
    translate_aco_string/4,      % +SourceName, +String, -AplTerms, -Messages
    canonicalize_aco_string/4,   % +SourceName, +String, -CanonicalString, -Messages

    % Shared internals
    aco_core_parse/15,           % internal pipeline
    compute_hierarchical_info/3,
    compute_hierarchical_id_messages/2,
    compute_undeveloped_and_stats/6,
    nodes_to_apl/3,

    % Utilities used by other modules
    string_trim/2
]).

:- use_module(library(lists)).
:- use_module(library(apply)).
:- use_module(library(pairs)).      % group_pairs_by_key/2

/*  High-level pipeline (string-based)
    -------------------
    translate_aco_string/4:
      1. Remove block comments /* ... */
      2. Split into raw lines with line numbers
      3. Strip shebang (line 1) and % line comments
      4. Detect indent/2 directive (if present)
      5. Classify lines as headers / bodies / relations / case header
      6. Build nodes (flat list) from headers + bodies
      7. Build edges from indentation + relations
      8. Run basic checks (duplicates, dangling refs, undeveloped)
      9. Map Node Model -> APL-ish terms (block/4 + supported_by/2 + in_context_of/2)
*/

% ----------------------------------------------------------------------
% Core parse pipeline
% ----------------------------------------------------------------------

aco_core_parse(_SourceName, Raw,
               IndentSpec, CaseHeaderOpt,
               Headers, Nodes0,
               TreeEdges, RelEdges, AllEdges,
               IndentMsg, BodyMsgs, NodeMsgs, IndentMsgs, RelMsgs0, RelMsgs1) :-
    string_codes(Raw, Codes0),
    remove_block_comments(Codes0, Codes1),
    string_codes(WithoutBlocks, Codes1),
    split_lines_with_numbers(WithoutBlocks, RawLines),
    strip_shebang(RawLines, _ShebangInfo, Lines1),
    strip_line_comments(Lines1, Lines2),
    detect_indent_spec(Lines2, _DefaultIndentSpec, IndentSpec, Lines3, IndentMsg),
    classify_lines(IndentSpec, Lines3, Classified0),
    extract_case_header(Classified0, CaseHeaderOpt, ClassifiedLines),
    partition(class_is_relation, ClassifiedLines, RelLines, NonRelLines),
    collect_headers_and_bodies(NonRelLines, Headers, BodyMsgs),
    build_nodes(Headers, Nodes0, NodeMsgs),
    build_edges_from_indent(Nodes0, TreeEdges, IndentMsgs),

    % relation parsing returns edges directly
    parse_relation_lines(RelLines, RelEdges, RelMsgs0),
    RelMsgs1 = [],

    append(TreeEdges, RelEdges, AllEdges).

% ----------------------------------------------------------------------
% Public API (string -> APL terms + messages)
% ----------------------------------------------------------------------

translate_aco_string(SourceName, Raw, AplTerms, Messages) :-
    aco_core_parse(SourceName, Raw,
                   _IndentSpec, CaseHeaderOpt,
                   _Headers, Nodes0,
                   TreeEdges, RelEdges, AllEdges,
                   IndentMsg, BodyMsgs, NodeMsgs, IndentMsgs, RelMsgs0, RelMsgs1),
    % undeveloped + statistics
    compute_undeveloped_and_stats(
        Nodes0, TreeEdges, RelEdges, AllEdges,
        UndevelopedMsgs, StatsMsg
    ),
    % hierarchical ID info & consistency messages
    compute_hierarchical_id_messages(Nodes0, HierarchyMsgs),
    % all messages
    append(
        [IndentMsg, BodyMsgs, NodeMsgs, IndentMsgs,
         RelMsgs0, RelMsgs1, UndevelopedMsgs, HierarchyMsgs, [StatsMsg]],
        MsgLists
    ),
    flatten(MsgLists, Messages),
    nodes_to_apl(Nodes0, AllEdges, NodeTerms0),
    prepend_case_header(CaseHeaderOpt, NodeTerms0, AplTerms).

% ----------------------------------------------------------------------
% Public API: canonicalise an ACO string (canonical IDs only)
% ----------------------------------------------------------------------

canonicalize_aco_string(SourceName, Raw, CanonicalRaw, Messages) :-
    aco_core_parse(SourceName, Raw,
                   IndentSpec, CaseHeaderOpt,
                   _Headers, Nodes0,
                   _TreeEdges, _RelEdges, AllEdges,
                   _IndentMsg, _BodyMsgs, _NodeMsgs,
                   _IndentMsgs, _RelMsgs0, _RelMsgs1),
    compute_hierarchical_info(Nodes0, Infos, HierMsgs),
    id_map_from_infos(Infos, IdMap),
    % canonical nodes
    canonicalize_nodes(IndentSpec, CaseHeaderOpt, Nodes0, IdMap, NodeLines),
    % canonical relations
    canonicalize_edges(AllEdges, IdMap, CanonEdges),
    canonicalize_relations(CanonEdges, RelationLines),

    append([NodeLines, [""], RelationLines], AllLineLists),
    flatten(AllLineLists, FlatLines),
    atomic_list_concat(FlatLines, '\n', CanonicalRaw),

    Messages = HierMsgs.

% ----------------------------------------------------------------------
% Comment handling
% ----------------------------------------------------------------------

/* remove_block_comments(+CodesIn, -CodesOut)
   Remove /* ... */ while preserving newlines.
*/

remove_block_comments([], []).
remove_block_comments([0'/,0'*|Rest], Out) :-  % "/*"
    !,
    skip_block_comment(Rest, RestAfter, Newlines),
    remove_block_comments(RestAfter, OutRest),
    append(Newlines, OutRest, Out).
remove_block_comments([C|Rest], [C|OutRest]) :-
    remove_block_comments(Rest, OutRest).

skip_block_comment([], [], []).
skip_block_comment([0'*,0'/|Rest], Rest, []) :- !.  % "*/"
skip_block_comment([0'\n|Rest], RestAfter, [0'\n|NLRest]) :-
    !,
    skip_block_comment(Rest, RestAfter, NLRest).
skip_block_comment([_|Rest], RestAfter, Newlines) :-
    skip_block_comment(Rest, RestAfter, Newlines).

% ----------------------------------------------------------------------
% Line splitting and basic stripping
% ----------------------------------------------------------------------

/* split_lines_with_numbers(+String, -Lines)
   Lines = [line(LineNo, Text), ...]
*/

split_lines_with_numbers(String, Lines) :-
    split_string(String, "\n", "", RawLines),
    number_strings(RawLines, 1, Lines).

number_strings([], _N, []).
number_strings([S|Ss], N, [line(N, S)|Rest]) :-
    N1 is N + 1,
    number_strings(Ss, N1, Rest).

/* strip_shebang(+LinesIn, -ShebangInfo, -LinesOut)
   If first line starts with "#!", treat it as shebang and blank it.
*/

strip_shebang([line(1, S)|Rest], shebang(1, S), [line(1, "")|Rest]) :-
    sub_string(S, 0, 2, _, "#!"),
    !.
strip_shebang(Lines, none, Lines).

/* strip_line_comments(+LinesIn, -LinesOut)
   Remove '%' to end-of-line, preserving leading text and line numbers.
*/

strip_line_comments([], []).
strip_line_comments([line(N, S0)|Rest], [line(N, S)|OutRest]) :-
    strip_percent_comment(S0, S),
    strip_line_comments(Rest, OutRest).

strip_percent_comment(S0, S) :-
    ( sub_string(S0, Pos, _, _, "%")
    -> sub_string(S0, 0, Pos, _, Before),
       strip_trailing_spaces(Before, S)
    ;  strip_trailing_spaces(S0, S)
    ).

strip_trailing_spaces(S0, S) :-
    string_codes(S0, Codes0),
    strip_trailing_spaces_codes(Codes0, Codes),
    string_codes(S, Codes).

strip_trailing_spaces_codes(Codes0, Codes) :-
    reverse(Codes0, Rev0),
    drop_leading_spaces(Rev0, Rev),
    reverse(Rev, Codes).

drop_leading_spaces([C|Cs], Rest) :-
    char_type(C, space),
    !,
    drop_leading_spaces(Cs, Rest).
drop_leading_spaces(L, L).

% ----------------------------------------------------------------------
% Indent directive detection
% ----------------------------------------------------------------------

/* detect_indent_spec(+LinesIn, +Default, -IndentSpec, -LinesOut, -Messages)
   Default is indent_spec(2, space).
*/

detect_indent_spec(LinesIn, DefaultIndentSpec, IndentSpec, LinesOut, Messages) :-
    DefaultIndentSpec = indent_spec(2, space),
    (   select(line(N, S), LinesIn, LinesTmp),
        trim_left(S, Trim),
        sub_string(Trim, 0, _, _, "indent("),
        !,
        (   parse_indent_directive(Trim, Spec)
        ->  IndentSpec = Spec,
            LinesOut   = [line(N, "")|LinesTmp],
            Messages   = [indent_directive(N, Spec)]
        ;   IndentSpec = DefaultIndentSpec,
            LinesOut   = [line(N, "")|LinesTmp],
            Messages   = [indent_directive_error(N, Trim)]
        )
    ;   IndentSpec = DefaultIndentSpec,
        LinesOut   = LinesIn,
        Messages   = []
    ).

trim_left(S0, S) :-
    string_codes(S0, Codes0),
    drop_leading_spaces(Codes0, Codes),
    string_codes(S, Codes).

string_trim(S0, S) :-
    trim_left(S0, Tmp),
    strip_trailing_spaces(Tmp, S).

parse_indent_directive(Line, indent_spec(N, Kind)) :-
    (   sub_string(Line, 0, _, _, "indent(")
    ->  remove_trailing_dot(Line, L1),
        catch(read_term_from_atom(L1, Term, []), _, fail),
        Term =.. [indent, N, KindAtom],
        integer(N), N > 0,
        ( KindAtom == space ; KindAtom == tab ),
        Kind = KindAtom
    ;   fail
    ).

remove_trailing_dot(Line, Clean) :-
    strip_trailing_spaces(Line, L1),
    (   sub_string(L1, _, 1, 0, ".")
    ->  sub_string(L1, 0, _, 1, Clean)
    ;   Clean = L1
    ).

% ----------------------------------------------------------------------
% Classification: header / body / relation / case header
% ----------------------------------------------------------------------

/* Classified line record:

   cl_case(Line, Title, Scope)
   cl_header(Line, Level, TypeAtom, IdOpt, LabelAtom)
   cl_body(Line, Level, Text)
   cl_relation(Line, Text)
   cl_blank(Line)
*/

class_is_relation(cl_relation(_, _)).

classify_lines(IndentSpec, Lines, Classified) :-
    maplist(classify_line(IndentSpec), Lines, Classified).

classify_line(_IndentSpec, line(N, S), cl_blank(N)) :-
    ( S = "" ; S = " " ; S = "\t" ),
    !.
classify_line(IndentSpec, line(N, S0), Class) :-
    string_codes(S0, Codes0),
    count_indent(IndentSpec, Codes0, Level, RestCodes),
    string_codes(S, RestCodes),
    (   S = ""
    ->  Class = cl_blank(N)
    ;   maybe_case_header(S, Title, Scope)
    ->  Class = cl_case(N, Title, Scope)
    ;   maybe_header(S, TypeAtom, IdOpt, LabelAtom)
    ->  Class = cl_header(N, Level, TypeAtom, IdOpt, LabelAtom)
    ;   is_relation_text(S)
    ->  Class = cl_relation(N, S)
    ;   Class = cl_body(N, Level, S)
    ).

count_indent(indent_spec(Width, Kind), Codes0, Level, Rest) :-
    count_indent_codes(Codes0, Width, Kind, 0, SpacesUsed, Rest),
    ( Width > 0
    -> Level is SpacesUsed // Width
    ;  Level = 0
    ).

count_indent_codes([C|Cs], Width, space, Acc, SpacesUsed, Rest) :-
    char_type(C, space),
    !,
    Acc1 is Acc + 1,
    count_indent_codes(Cs, Width, space, Acc1, SpacesUsed, Rest).
count_indent_codes([C|Cs], Width, tab, Acc, SpacesUsed, Rest) :-
    char_type(C, space),
    !,
    Acc1 is Acc + 1,
    count_indent_codes(Cs, Width, tab, Acc1, SpacesUsed, Rest).
count_indent_codes(Rest, _Width, _Kind, SpacesUsed, SpacesUsed, Rest).

extract_case_header(Classified0, CaseHeaderOpt, ClassifiedLines) :-
    (   select(cl_case(_N, Title, Scope), Classified0, Rest)
    ->  CaseHeaderOpt = some(case_header(Title, Scope)),
        ClassifiedLines = Rest
    ;   CaseHeaderOpt = none,
        ClassifiedLines = Classified0
    ).

prepend_case_header(none, Terms, Terms).
prepend_case_header(some(case_header(Title, Scope)), Terms,
                    [case_header(Title, Scope)|Terms]).

maybe_case_header(S0, Title, Scope) :-
    trim_left(S0, S1),
    (   sub_string(S1, 0, 5, _, "Case:")
    ;   sub_string(S1, 0, 5, _, "CASE:")
    ),
    !,
    sub_string(S1, 5, _, 0, After),
    strip_trailing_spaces(After, AfterTrim),
    string_trim(AfterTrim, Content0),
    (   Content0 = ""
    ->  Title = '',
        Scope = ''
    ;   split_title_scope(Content0, Title, Scope)
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
    string_trim(T0, TitleStr),
    string_trim(S0, ScopeStr),
    atom_string(Title, TitleStr),
    atom_string(Scope, ScopeStr).
split_title_scope(Content, Title, '') :-
    string_trim(Content, TitleStr),
    atom_string(Title, TitleStr).

/* maybe_header(+Trimmed, -TypeAtom, -IdOpt, -LabelAtom)

   Header syntax:  Type [ID] Label:

   Type   = Goal | Strategy | Context | Assumption | Justification | Evidence | Module
   ID     = single token, often like G0, C1, etc. (optional)
   Label  = single token (no spaces)
*/

maybe_header(S, TypeAtom, IdOpt, LabelAtom) :-
    strip_trailing_spaces(S, S1),
    sub_string(S1, 0, _, After, Prefix),
    sub_string(S1, _, After, 0, ":"),
    !,
    atom_string(Atom, Prefix),
    atomic_list_concat(Tokens, ' ', Atom),
    Tokens = [TypeToken|Rest],
    header_type(TypeToken, TypeAtom),
    (   Rest = [IdToken0, LabelToken]
    ->  strip_trailing_comma(IdToken0, IdClean),
        IdOpt     = some(IdClean),
        LabelAtom = LabelToken
    ;   Rest = [LabelToken]
    ->  IdOpt     = none,
        LabelAtom = LabelToken
    ).

header_type('Goal',          goal).
header_type('Strategy',      strategy).
header_type('Context',       context).
header_type('Assumption',    assumption).
header_type('Justification', justification).
header_type('Evidence',      evidence).
header_type('Module',        module).

is_relation_text(S) :-
    (   parse_supported_by(S, _)
    ;   parse_supports(S, _)
    ;   parse_in_context(S, _)
    ;   parse_context_for(S, _)
    ).

% ----------------------------------------------------------------------
% Collect headers and their bodies
% ----------------------------------------------------------------------

collect_headers_and_bodies(Classified, Headers, Messages) :-
    collect_headers_and_bodies(Classified, none, [], RevHeaders, [], RevMsgs),
    reverse(RevHeaders, Headers),
    reverse(RevMsgs, Messages).

collect_headers_and_bodies([], none, HAcc, HAcc, MAcc, MAcc).
collect_headers_and_bodies([], some(Current), HAcc, [Current|HAcc], MAcc, MAcc).

collect_headers_and_bodies([cl_blank(_)|Rest], Current, HAcc, HOut, MAcc, MOut) :-
    collect_headers_and_bodies(Rest, Current, HAcc, HOut, MAcc, MOut).

collect_headers_and_bodies([cl_header(N, Lev, Type, IdOpt, Label)|Rest],
                           none, HAcc, HOut, MAcc, MOut) :-
    New = header(N, Lev, Type, IdOpt, Label, []),
    collect_headers_and_bodies(Rest, some(New), HAcc, HOut, MAcc, MOut).

collect_headers_and_bodies([cl_header(N, Lev, Type, IdOpt, Label)|Rest],
                           some(Current), HAcc, HOut, MAcc, MOut) :-
    Current = header(_, _, _, _, _, _),
    HAcc1   = [Current|HAcc],
    New     = header(N, Lev, Type, IdOpt, Label, []),
    collect_headers_and_bodies(Rest, some(New), HAcc1, HOut, MAcc, MOut).

collect_headers_and_bodies([cl_body(N, Lev, Text)|Rest],
                           none, HAcc, HOut, MAcc, MOut) :-
    MAcc1 = [orphan_body_line(N, Lev, Text)|MAcc],
    collect_headers_and_bodies(Rest, none, HAcc, HOut, MAcc1, MOut).

collect_headers_and_bodies([cl_body(N, Lev, Text)|Rest],
                           some(Current), HAcc, HOut, MAcc, MOut) :-
    Current = header(HN, HLev, HType, HIdOpt, HLabel, Body0),
    (   Lev > HLev
    ->  Body1 = Body0,
        append(Body1, [(N, Text)], Body)
    ;   Body1 = Body0,
        append(Body1, [(N, Text)], Body)
    ),
    NewCurrent = header(HN, HLev, HType, HIdOpt, HLabel, Body),
    collect_headers_and_bodies(Rest, some(NewCurrent), HAcc, HOut, MAcc, MOut).

% ----------------------------------------------------------------------
% Node Model construction
% ----------------------------------------------------------------------

build_nodes(Headers, Nodes, Messages) :-
    build_nodes(Headers, 0, [], RevNodes, [], RevMsgs),
    reverse(RevNodes, Nodes),
    reverse(RevMsgs, Messages).

build_nodes([], _Counter, NAcc, NAcc, MAcc, MAcc).
build_nodes([header(Line, Level, Type, IdOpt, Label, BodyLines)|Rest],
            Counter, NAcc, NOut, MAcc, MOut) :-
    (   IdOpt = some(IdAtom)
    ->  Id = IdAtom
    ;   format(atom(Id), '~w_~d', [Type, Counter])
    ),
    Counter1 is Counter + 1,
    body_lines_to_string(BodyLines, BodyStr),
    Node = node(Id, Type, Label, BodyStr, Level, Line),
    build_nodes(Rest, Counter1, [Node|NAcc], NOut, MAcc, MOut).

body_lines_to_string([], "").
body_lines_to_string(Pairs, S) :-
    findall(T,
        ( member((_N, T), Pairs),
          T \= ""
        ),
        Texts),
    atomic_list_concat(Texts, '\n', S).

% ----------------------------------------------------------------------
% Edges from indentation
% ----------------------------------------------------------------------

build_edges_from_indent(Nodes, Edges, Messages) :-
    sort(6, @=<, Nodes, SortedByLine),
    build_edges_from_indent_1(SortedByLine, [], [], Edges, [], Messages).

build_edges_from_indent_1([], _Stack, EAcc, EAcc, MAcc, MAcc).
build_edges_from_indent_1([node(Id, Type, _Label, _Body, Level, Line)|Rest],
                          Stack, EAcc, EOut, MAcc, MOut) :-
    adjust_stack(Level, Line, Stack, NewStack, ParentOpt, IndentMsg),
    (   ParentOpt == none
    ->  EAcc1 = EAcc
    ;   ParentOpt = some(ParentId),
        edge_for_type(Type, ParentId, Id, Line, EdgeTerm),
        EAcc1 = [EdgeTerm|EAcc]
    ),
    (IndentMsg == none -> MAcc1 = MAcc ; MAcc1 = [IndentMsg|MAcc]),
    build_edges_from_indent_1(
        Rest,
        [frame(Level, Id, Line)|NewStack],
        EAcc1, EOut,
        MAcc1, MOut).

adjust_stack(Level, _Line, [], [], none, none) :-
    Level =:= 0, !.
adjust_stack(Level, _Line, [], [], none, indentation_jump(Level)) :-
    Level > 0, !.
adjust_stack(Level, Line, Stack, NewStack, ParentOpt, Msg) :-
    pop_until_lower(Level, Stack, Popped, ParentFrameOpt),
    (   ParentFrameOpt = none
    ->  ( Level =:= 0
        -> ParentOpt = none,
           Msg = none,
           NewStack = Popped
        ;  ParentOpt = none,
           Msg = indentation_jump(Line-Level),
           NewStack = Popped
        )
    ;   ParentFrameOpt = some(frame(_LevP, ParentId, _LineP)),
        ParentOpt = some(ParentId),
        Msg = none,
        NewStack = Popped
    ).

pop_until_lower(_Level, [], [], none).
pop_until_lower(Level, [frame(L, Id, Line)|Rest], NewStack, ParentOpt) :-
    (   L < Level
    ->  NewStack     = [frame(L, Id, Line)|Rest],
        ParentOpt    = some(frame(L, Id, Line))
    ;   pop_until_lower(Level, Rest, NewStack, ParentOpt)
    ).

edge_for_type(context, ParentId, Id, _Line, in_context_of(ParentId, Id)).
edge_for_type(Type, ParentId, Id, _Line, supported_by(ParentId, Id)) :-
    Type \= context.

% ----------------------------------------------------------------------
% Relation lines
% ----------------------------------------------------------------------

/* We support:
   G0 is supported by G1, G2, C0 and M0.
   G1, G2, C0 and M0 support G0.
   G0 is in context of C0.
   C0 provides context for G0.
*/

parse_relation_lines(RelLines, Edges, Messages) :-
    maplist(parse_relation_line, RelLines, Results),
    partition(is_relation_error, Results, ErrorTerms, EdgeLists),
    Messages = ErrorTerms,
    flatten(EdgeLists, Edges).

is_relation_error(relation_parse_error(_, _)).

parse_relation_line(cl_relation(N, S), EdgesOrErr) :-
    (   parse_supported_by(S, Es)
    ->  EdgesOrErr = Es
    ;   parse_supports(S, Es)
    ->  EdgesOrErr = Es
    ;   parse_in_context(S, Es)
    ->  EdgesOrErr = Es
    ;   parse_context_for(S, Es)
    ->  EdgesOrErr = Es
    ;   EdgesOrErr = relation_parse_error(N, S)
    ).

parse_supported_by(S, Edges) :-
    (   sub_string(S, _, _, _, " supported by ")
    ;   sub_string(S, _, _, _, " supported by")
    ),
    !,
    split_string(S, ".", ".", [NoDot|_]),
    split_string(NoDot, " ", " ", Tokens0),
    exclude(=(""), Tokens0, Tokens),
    (   append(LHSTokens, ["is","supported","by"|RHSTokens], Tokens)
    ;   append(LHSTokens, ["are","supported","by"|RHSTokens], Tokens)
    ),
    ids_from_list(LHSTokens, LHSIds),
    ids_from_list(RHSTokens, RHSIds),
    LHSIds \= [], RHSIds \= [],
    findall(supported_by(Goal, Support),
            ( member(Goal,   LHSIds),
              member(Support, RHSIds)
            ),
            Edges).

parse_supports(S, Edges) :-
    (   sub_string(S, _, _, _, " support ")
    ;   sub_string(S, _, _, _, " supports ")
    ),
    !,
    split_string(S, ".", ".", [NoDot|_]),
    split_string(NoDot, " ", " ", Tokens0),
    exclude(=(""), Tokens0, Tokens),
    (   append(LHSTokens, ["support"|RHSTokens],  Tokens)
    ;   append(LHSTokens, ["supports"|RHSTokens], Tokens)
    ),
    ids_from_list(LHSTokens, SupporterIds),
    ids_from_list(RHSTokens, GoalIds),
    SupporterIds \= [], GoalIds \= [],
    findall(supported_by(Goal, Supporter),
            ( member(Goal,     GoalIds),
              member(Supporter, SupporterIds)
            ),
            Edges).

parse_in_context(S, Edges) :-
    sub_string(S, _, _, _, "in context of"),
    !,
    split_string(S, ".", ".", [NoDot|_]),
    split_string(NoDot, " ", " ", Tokens0),
    exclude(=(""), Tokens0, Tokens),
    (   append(LHSTokens, ["is","in","context","of"|RHSTokens],  Tokens)
    ;   append(LHSTokens, ["are","in","context","of"|RHSTokens], Tokens)
    ),
    ids_from_list(LHSTokens, GoalIds),
    ids_from_list(RHSTokens, CtxIds),
    GoalIds \= [], CtxIds \= [],
    findall(in_context_of(Goal, Ctx),
            ( member(Goal, GoalIds),
              member(Ctx,  CtxIds)
            ),
            Edges).

parse_context_for(S, Edges) :-
    sub_string(S, _, _, _, "context for"),
    !,
    split_string(S, ".", ".", [NoDot|_]),
    split_string(NoDot, " ", " ", Tokens0),
    exclude(=(""), Tokens0, Tokens),
    (   append(LHSTokens, ["provides","context","for"|RHSTokens], Tokens)
    ;   append(LHSTokens, ["provide","context","for"|RHSTokens],  Tokens)
    ),
    ids_from_list(LHSTokens, CtxIds),
    ids_from_list(RHSTokens, GoalIds),
    CtxIds \= [], GoalIds \= [],
    findall(in_context_of(Goal, Ctx),
            ( member(Goal, GoalIds),
              member(Ctx,  CtxIds)
            ),
            Edges).

ids_from_list(Tokens, Ids) :-
    include(valid_id_token, Tokens, CleanTokens),
    maplist(strip_trailing_comma, CleanTokens, Ids).

valid_id_token(Token) :-
    Token \= "and",
    sub_string(Token, 0, 1, _, First),
    char_type(First, alpha).

strip_trailing_comma(Token, Clean) :-
    ( sub_string(Token, _, 1, 0, ",")
    -> sub_string(Token, 0, _, 1, Clean)
    ;  Clean = Token
    ).

% ----------------------------------------------------------------------
% undeveloped nodes + statistics (with Evidence)
% ----------------------------------------------------------------------

compute_undeveloped_and_stats(
    Nodes, TreeEdges, RelEdges, AllEdges,
    UndevelopedMsgs, StatsMsg
) :-
    % Node counts by type
    length(Nodes, TotalNodes),
    count_nodes_of_type(goal,          Nodes, NumGoals),
    count_nodes_of_type(strategy,      Nodes, NumStrategies),
    count_nodes_of_type(context,       Nodes, NumContexts),
    count_nodes_of_type(assumption,    Nodes, NumAssumptions),
    count_nodes_of_type(justification, Nodes, NumJustifications),
    count_nodes_of_type(evidence,      Nodes, NumEvidence),
    count_nodes_of_type(module,        Nodes, NumModules),

    % Undeveloped goals and modules: no supported_by/2 children at all
    findall(undeveloped_goal(Id, Label, Line),
        ( member(node(Id, goal,   Label, _Bodyg, _Levg, Line), Nodes),
          \+ member(supported_by(Id, _), AllEdges)
        ),
        UndevGoals),
    findall(undeveloped_module(Id, Label, Line),
        ( member(node(Id, module, Label, _Bodym, _Levm, Line), Nodes),
          \+ member(supported_by(Id, _), AllEdges)
        ),
        UndevModules),

    length(UndevGoals,   NumUndevGoals),
    length(UndevModules, NumUndevModules),

    % Edge statistics
    findall(1, member(supported_by(_, _), TreeEdges), LTreeSB),
    length(LTreeSB, NumTreeSupported),

    findall(1, member(supported_by(_, _), RelEdges), LRelSB),
    length(LRelSB, NumRelSupported),

    findall(1, member(in_context_of(_, _), TreeEdges), LTreeCtx),
    length(LTreeCtx, NumTreeContexts),

    findall(1, member(in_context_of(_, _), RelEdges), LRelCtx),
    length(LRelCtx, NumRelContexts),

    % Cross-branch edges (explicit relations that don't follow the tree)
    findall(E,
        ( member(E, RelEdges),
          ( E = supported_by(P, C)
          ; E = in_context_of(P, C)
          ),
          \+ descendant(P, C, TreeEdges)
        ),
        CrossEdges),
    length(CrossEdges, NumCrossRelations),

    append(UndevGoals, UndevModules, UndevelopedMsgs),

    % Extended stats_summary/15 (added NumEvidence just before NumModules)
    StatsMsg = stats_summary(
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
               ).

/*
compute_undeveloped_and_stats(
    Nodes, TreeEdges, RelEdges, AllEdges,
    UndevelopedMsgs, StatsMsg
) :-
    length(Nodes, TotalNodes),
    count_nodes_of_type(goal,        Nodes, NumGoals),
    count_nodes_of_type(strategy,    Nodes, NumStrategies),
    count_nodes_of_type(context,     Nodes, NumContexts),
    count_nodes_of_type(assumption,  Nodes, NumAssumptions),
    count_nodes_of_type(justification, Nodes, NumJustifications),
    count_nodes_of_type(evidence,    Nodes, NumEvidence),
    count_nodes_of_type(module,      Nodes, NumModules),

    findall(undeveloped_goal(Id, Label, Line),
        ( member(node(Id, goal, Label, _Bodyg, _Levg, Line), Nodes),
          \+ member(supported_by(Id, _), AllEdges)
        ),
        UndevGoals),
    findall(undeveloped_module(Id, Label, Line),
        ( member(node(Id, module, Label, _Bodym, _Levm, Line), Nodes),
          \+ member(supported_by(Id, _), AllEdges)
        ),
        UndevModules),

    length(UndevGoals,   NumUndevGoals),
    length(UndevModules, NumUndevModules),

    findall(1, member(supported_by(_, _), TreeEdges), LTreeSB),
    length(LTreeSB, NumTreeSupported),

    findall(1, member(supported_by(_, _), RelEdges), LRelSB),
    length(LRelSB, NumRelSupported),

    findall(1, member(in_context_of(_, _), TreeEdges), LTreeCtx),
    length(LTreeCtx, NumTreeContexts),

    findall(1, member(in_context_of(_, _), RelEdges), LRelCtx),
    length(LRelCtx, NumRelContexts),

    findall(E,
        ( member(E, RelEdges),
          ( E = supported_by(P, C)
          ; E = in_context_of(P, C)
          ),
          \+ descendant(P, C, TreeEdges)
        ),
        CrossEdges),
    length(CrossEdges, NumCrossRelations),

    append(UndevGoals, UndevModules, UndevelopedMsgs),

    StatsMsg = stats_summary(
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
               ).
*/

count_nodes_of_type(Type, Nodes, Count) :-
    include(node_of_type(Type), Nodes, Filtered),
    length(Filtered, Count).

node_of_type(Type, node(_, Type, _, _, _, _)).

descendant(Parent, Child, TreeEdges) :-
    descendant(Parent, Child, TreeEdges, []).

descendant(Parent, Child, Edges, _Visited) :-
    member(supported_by(Parent, Child), Edges),
    !.
descendant(Parent, Child, Edges, Visited) :-
    member(supported_by(Parent, Mid), Edges),
    \+ member(Mid, Visited),
    descendant(Mid, Child, Edges, [Mid|Visited]).

% ----------------------------------------------------------------------
% hierarchical ID analysis and consistency checks
% ----------------------------------------------------------------------

compute_hierarchical_info(Nodes, Infos, Messages) :-
    sort(6, @=<, Nodes, SortedByLine),
    compute_hierarchical_info_1(SortedByLine, -1, [], [], [], InfosRev, MsgsRev),
    reverse(InfosRev, Infos),
    reverse(MsgsRev, Messages).

compute_hierarchical_info_1([], _PrevLevel, _PrevPath,
                            InfosAcc, MsgAcc, InfosAcc, MsgAcc).
compute_hierarchical_info_1(
    [node(Id, Type, _Label, _Body, Level, Line)|Rest],
    PrevLevel, PrevPath,
    InfosAcc0, MsgAcc0,
    InfosOut, MsgOut
) :-
    next_hier_path(Level, PrevLevel, PrevPath, Path1),
    canonical_id_for_node(Type, Path1, CanonId),
    Info = hier_info(Id, CanonId, Type, Level, Line, Path1),
    Msg1 = hierarchical_id(Line, Id, CanonId),
    (   non_auto_dotted_id(Id, Type),
        Id \== CanonId
    ->  MsgAcc1 = [hierarchical_id_mismatch(Line, Id, CanonId), Msg1|MsgAcc0]
    ;   MsgAcc1 = [Msg1|MsgAcc0]
    ),
    InfosAcc1 = [Info|InfosAcc0],
    compute_hierarchical_info_1(Rest, Level, Path1,
                                InfosAcc1, MsgAcc1,
                                InfosOut, MsgOut).

compute_hierarchical_id_messages(Nodes, Messages) :-
    compute_hierarchical_info(Nodes, _Infos, Messages).

next_hier_path(Level, PrevLevel, PrevPath, Path1) :-
    (   PrevLevel < 0
    ->  Path1 = [1]
    ;   Level =:= PrevLevel
    ->  inc_last(PrevPath, Path1)
    ;   Level =:= PrevLevel + 1
    ->  append(PrevPath, [1], Path1)
    ;   Level < PrevLevel
    ->  Len is Level + 1,
        prefix_n(Len, PrevPath, Prefix),
        inc_last(Prefix, Path1)
    ;   append(PrevPath, [1], Path1)
    ).

inc_last([], [1]) :- !.
inc_last(Path, NextPath) :-
    append(Prefix, [Last], Path),
    NewLast is Last + 1,
    append(Prefix, [NewLast], NextPath).

prefix_n(N, List, Prefix) :-
    prefix_n(N, List, [], Prefix).

prefix_n(0, _List, Acc, Prefix) :-
    reverse(Acc, Prefix), !.
prefix_n(_N, [], Acc, Prefix) :-
    reverse(Acc, Prefix), !.
prefix_n(N, [X|Xs], Acc, Prefix) :-
    N > 0,
    N1 is N - 1,
    prefix_n(N1, Xs, [X|Acc], Prefix).

% ----------------------------------------------------------------------
% Canonical ID mapping helpers (incl. Evidence)
% ----------------------------------------------------------------------

canonical_id_for_node(Type, [First|Rest], CanonId) :-
    type_prefix(Type, PrefixAtom),
    number_string(First, FirstStr),
    (   Rest == []
    ->  atom_concat(PrefixAtom, FirstStr, Base),
        atom_concat(Base, '.', CanonId)
    ;   maplist(number_string, Rest, RestStrs),
        atomic_list_concat(RestStrs, '.', RestNums),
        format(atom(NumAtom), '~w.~w', [FirstStr, RestNums]),
        atom_concat(PrefixAtom, NumAtom, CanonId)
    ).

type_prefix(goal,          'G').
type_prefix(strategy,      'S').
type_prefix(context,       'C').
type_prefix(assumption,    'A').
type_prefix(justification, 'J').
type_prefix(evidence,      'E').
type_prefix(module,        'M').

non_auto_dotted_id(Id, Type) :-
    \+ auto_generated_id(Id, Type),
    atom_string(Id, S),
    sub_string(S, _, 1, _, ".").

auto_generated_id(Id, Type) :-
    atom_concat(Type, '_', Prefix),
    atom_concat(Prefix, _N, Id).

id_map_from_infos(Infos, IdMap) :-
    findall(Old-Canon,
            member(hier_info(Old, Canon, _Type, _Level, _Line, _Path), Infos),
            IdMap).

map_id(Id, IdMap, CanonId) :-
    (   member(Id-Canon0, IdMap)
    ->  CanonId = Canon0
    ;   CanonId = Id
    ).

indent_prefix(indent_spec(Width, space), Level, Prefix) :-
    Count is Width * Level,
    length(Codes, Count),
    maplist(=(0' ), Codes),
    string_codes(Prefix, Codes).
indent_prefix(indent_spec(_Width, tab), Level, Prefix) :-
    length(Codes, Level),
    maplist(=(0'\t), Codes),
    string_codes(Prefix, Codes).

type_name(goal,          "Goal").
type_name(strategy,      "Strategy").
type_name(context,       "Context").
type_name(assumption,    "Assumption").
type_name(justification, "Justification").
type_name(evidence,      "Evidence").
type_name(module,        "Module").

body_to_lines(_IndentSpec, _Level, "", []) :- !.
body_to_lines(IndentSpec, Level, Body, Lines) :-
    split_string(Body, "\n", "\r", RawLines),
    exclude(=(""), RawLines, NonEmpty),
    indent_prefix(IndentSpec, Level + 1, BPrefix),
    findall(LineStr,
            ( member(T, NonEmpty),
              string_trim(T, TextTrim),
              format(string(LineStr), "~s~s", [BPrefix, TextTrim])
            ),
            Lines).

canonicalize_nodes(IndentSpec, CaseHeaderOpt, Nodes, IdMap, Lines) :-
    (   CaseHeaderOpt = some(case_header(Title, Scope))
    ->  atom_string(Title, TitleStr),
        atom_string(Scope, ScopeStr),
        (   ScopeStr = ""
        ->  format(string(CaseLine), "Case: ~s", [TitleStr])
        ;   format(string(CaseLine), "Case: ~s - ~s", [TitleStr, ScopeStr])
        ),
        CaseLines = [CaseLine, ""]
    ;   CaseLines = []
    ),
    sort(6, @=<, Nodes, SortedNodes),
    canonicalize_nodes_1(SortedNodes, IndentSpec, IdMap, NodeLines),
    append(CaseLines, NodeLines, Lines).

canonicalize_nodes_1([], _IndentSpec, _IdMap, []).

canonicalize_nodes_1(
    [node(Id, Type, Label, Body, Level, _Line)|Rest],
    IndentSpec, IdMap,
    LinesOut
) :-
    map_id(Id, IdMap, CanonId),
    type_name(Type, TypeWord),
    atom_string(Label, LabelStr),
    atom_string(CanonId, CanonStr),
    indent_prefix(IndentSpec, Level, Prefix),
    format(string(HeaderLine),
           "~s~s ~s ~s:",
           [Prefix, TypeWord, CanonStr, LabelStr]),
    body_to_lines(IndentSpec, Level, Body, BodyLines),
    canonicalize_nodes_1(Rest, IndentSpec, IdMap, RestLines),
    append([HeaderLine|BodyLines], RestLines, LinesOut).

canonicalize_edges(EdgesIn, IdMap, EdgesOut) :-
    findall(ECanon,
            ( member(E, EdgesIn),
              canonicalize_edge(E, IdMap, ECanon)
            ),
            EdgesTmp),
    sort(EdgesTmp, EdgesOut).

canonicalize_edge(supported_by(P, C), IdMap, supported_by(P1, C1)) :-
    map_id(P, IdMap, P1),
    map_id(C, IdMap, C1).
canonicalize_edge(in_context_of(G, Ctx), IdMap, in_context_of(G1, Ctx1)) :-
    map_id(G, IdMap, G1),
    map_id(Ctx, IdMap, Ctx1).

relation_line_for_edge(supported_by(Goal, Support), Line) :-
    format(string(Line), "~w is supported by ~w.", [Goal, Support]).
relation_line_for_edge(in_context_of(Goal, Ctx), Line) :-
    format(string(Line), "~w is in context of ~w.", [Goal, Ctx]).

canonicalize_relations(Edges, RelLines) :-
    findall(LineStr,
            ( member(E, Edges),
              relation_line_for_edge(E, LineStr)
            ),
            RelLines).

% ----------------------------------------------------------------------
% Node Model -> APL-ish terms
% ----------------------------------------------------------------------

nodes_to_apl(Nodes, Edges, AplTerms) :-
    findall(block(Id, Type, Label, Body),
            member(node(Id, Type, Label, Body, _Lev, _Line), Nodes),
            BlockTerms),
    append(BlockTerms, Edges, AplTerms).
