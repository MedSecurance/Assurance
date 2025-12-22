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
    string_trim/2,
    is_relation_text/1
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
    rewrite_inline_after_colon(IndentSpec, Lines3, Lines3b, RewriteMsgs),
    classify_lines(IndentSpec, Lines3b, Classified0),
    extract_case_header(Classified0, CaseHeaderOpt, ClassifiedLines),

    % NL relations are unit-scoped trailers. We first split out the relation section
    % (if any) using *strict* syntactic recognition (no substring heuristics).
    split_unit_relations(ClassifiedLines, NonRelLines, RelLines, RelMsgs1),

    collect_headers_and_bodies(NonRelLines, Headers, BodyMsgs0),
    append(RewriteMsgs, BodyMsgs0, BodyMsgs),
    build_nodes(Headers, Nodes0, NodeMsgs),
    build_edges_from_indent(Nodes0, TreeEdges, IndentMsgs),

    % relation parsing is strict and requires that all referenced IDs are defined in this unit
    known_ids_in_unit(Nodes0, KnownIds),
    parse_relation_lines(RelLines, KnownIds, RelEdges, RelMsgs0),

    append(TreeEdges, RelEdges, AllEdges),
    !.

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


% ----------------------------------------------------------------------
% Canonicaliser convenience: rewrite header lines that have inline text
% after the trailing ':' into the 2-line form required by the v1.2 spec.
%
% Example:
%   Evidence E10 tlsPolicy: Enforce TLS 1.2+ ...
% becomes:
%   Evidence E10 tlsPolicy:
%     Enforce TLS 1.2+ ...
% ----------------------------------------------------------------------

rewrite_inline_after_colon(IndentSpec, LinesIn, LinesOut, Messages) :-
    indent_unit_string(IndentSpec, Unit),
    rewrite_inline_after_colon_1(Unit, LinesIn, [], RevLines, [], RevMsgs),
    reverse(RevLines, LinesOut),
    reverse(RevMsgs, Messages).

rewrite_inline_after_colon_1(_Unit, [], LinesAcc, LinesAcc, MsgsAcc, MsgsAcc).
rewrite_inline_after_colon_1(Unit, [line(N,S0)|Rest], LinesAcc0, LinesAcc, MsgsAcc0, MsgsAcc) :-
    (   rewrite_inline_after_colon_line(Unit, S0, S1, S2, TypeWord, InlineText)
    ->  LinesAcc1 = [line(N,S2), line(N,S1)|LinesAcc0],
        MsgsAcc1  = [rewrote_inline_after_colon(N, TypeWord, InlineText)|MsgsAcc0]
    ;   LinesAcc1 = [line(N,S0)|LinesAcc0],
        MsgsAcc1  = MsgsAcc0
    ),
    rewrite_inline_after_colon_1(Unit, Rest, LinesAcc1, LinesAcc, MsgsAcc1, MsgsAcc).

% S0 is rewritten into S1 (header-only, ends with ':') and S2 (body line).
rewrite_inline_after_colon_line(Unit, S0, S1, S2, TypeWord, InlineText) :-
    string_codes(S0, Codes),
    % Split into leading whitespace WS and the remainder Rest0.
    % We must use phrase/3 here so Rest0 is returned as the remaining input;
    % a DCG that "returns" the rest as a nonterminal will raise instantiation
    % errors when Rest is a variable.
    phrase(leading_ws(WS), Codes, Rest0),
    string_codes(RestStr0, Rest0),
    string_trim(RestStr0, RestTrim),
    % do not touch explicit relation lines
    \+ is_relation_text(RestTrim),
    starts_with_node_type(RestTrim, TypeWord),
    % split on the first ':' (outside of any attempt to parse quoted labels)
    sub_string(RestTrim, BeforeLen, 1, AfterLen, ":"),
    AfterLen > 0,
    sub_string(RestTrim, 0, BeforeLen, _, Left0),
    sub_string(RestTrim, _, AfterLen, 0, Right0),
    string_trim(Right0, RightTrim),
    RightTrim \= "",
    string_trim(Left0, LeftTrim),
    % rebuild: header-only line, plus an indented body line
    format(string(S1), "~s~s:", [WS, LeftTrim]),
    format(string(S2), "~s~s~s", [WS, Unit, RightTrim]),
    InlineText = RightTrim.

% leading whitespace (spaces or tabs) as codes
leading_ws([C|Ws]) -->
    [C],
    { (code_type(C, space) ; C =:= 0'\t) },
    !,
    leading_ws(Ws).
leading_ws([]) -->
    [].

starts_with_node_type(S, TypeWord) :-
    (   sub_string(S, 0, _, _, "Goal ")          -> TypeWord = 'Goal'
    ;   sub_string(S, 0, _, _, "Strategy ")      -> TypeWord = 'Strategy'
    ;   sub_string(S, 0, _, _, "Context ")       -> TypeWord = 'Context'
    ;   sub_string(S, 0, _, _, "Assumption ")    -> TypeWord = 'Assumption'
    ;   sub_string(S, 0, _, _, "Justification ") -> TypeWord = 'Justification'
    ;   sub_string(S, 0, _, _, "Evidence ")      -> TypeWord = 'Evidence'
    ;   sub_string(S, 0, _, _, "Module ")        -> TypeWord = 'Module'
    ),
    !.

indent_unit_string(indent_spec(N, space), Unit) :-
    N > 0, !,
    length(Chars, N),
    maplist(=(' '), Chars),
    string_chars(Unit, Chars).
indent_unit_string(indent_spec(N, tab), Unit) :-
    N > 0, !,
    length(Codes, N),
    maplist(=(0'	), Codes),
    string_codes(Unit, Codes).
indent_unit_string(_Other, "  ").  % fallback (should not happen)


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
    % Accept headers with possibly-quoted multi-word labels, e.g.:
    %   Context C0 "Tiny multi-unit demo":
    %   Strategy S0 "Decompose the top claim into security and operations":
    % Also accept (robustly) unquoted multi-word labels by joining tokens,
    % but canonicalisation should rewrite those into conformant quoted form.
    strip_trailing_spaces(S, S1),
    sub_string(S1, 0, _, After, Prefix),
    sub_string(S1, _, After, 0, ":"),
    !,
    tokenize_header_prefix(Prefix, Tokens),
    Tokens = [TypeToken|Rest0],
    header_type(TypeToken, TypeAtom),
    (   Rest0 = []
    ->  % ill-formed; treat as not-a-header by failing
        fail
    ;   Rest0 = [Only]
    ->  % No explicit ID
        IdOpt = none,
        LabelAtom = Only
    ;   Rest0 = [IdToken0|LabelTokens]
    ->  strip_trailing_comma(IdToken0, IdClean),
        (   valid_id_token(IdClean)
        ->  IdOpt = some(IdClean),
            join_tokens_as_label(LabelTokens, LabelAtom)
        ;   % No ID; label is everything after the type
            IdOpt = none,
            join_tokens_as_label(Rest0, LabelAtom)
        )
    ).

% Tokenize the part before the ':' in a header line.
% - Splits on whitespace unless inside double quotes.
% - Supports simple escapes inside quotes: \" and \\.
% - Removes surrounding quotes from quoted tokens.
tokenize_header_prefix(Prefix0, Tokens) :-
    string_trim(Prefix0, Prefix),
    string_codes(Prefix, Codes),
    tokenize_codes(Codes, outside, [], [], Rev),
    reverse(Rev, Tokens).

tokenize_codes([], _State, Curr, Acc, Out) :-
    flush_token(Curr, Acc, Out).
tokenize_codes([C|Rest], State, Curr, Acc, Out) :-
    (   State = outside,
        char_type(C, space)
    ->  flush_token(Curr, Acc, Acc1),
        tokenize_codes(Rest, outside, [], Acc1, Out)
    ;   State = outside,
        C == 0'"             % begin quote
    ->  tokenize_codes(Rest, inside, Curr, Acc, Out)
    ;   State = inside,
        C == 0'\\,            % escape - added second backslash
        Rest = [Next|Rest2],
        ( Next == 0'" ; Next == 0'\\)
    ->  tokenize_codes(Rest2, inside, [Next|Curr], Acc, Out)
    ;   State = inside,
        C == 0'"             % end quote
    ->  tokenize_codes(Rest, outside, Curr, Acc, Out)
    ;   % ordinary char
        tokenize_codes(Rest, State, [C|Curr], Acc, Out)
    ).

flush_token([], Acc, Acc) :- !.
flush_token(CurrRev, Acc, [Atom|Acc]) :-
    reverse(CurrRev, Codes),
    Codes \= [],
    string_codes(S, Codes),
    atom_string(Atom, S).

join_tokens_as_label([], '').
join_tokens_as_label([One], One) :- !.
join_tokens_as_label(Toks, LabelAtom) :-
    maplist(atom_string, Toks, Strs),
    atomic_list_concat(Strs, " ", LabelStr),
    atom_string(LabelAtom, LabelStr).



header_type('Goal',          goal).
header_type('Strategy',      strategy).
header_type('Context',       context).
header_type('Assumption',    assumption).
header_type('Justification', justification).
header_type('Evidence',      evidence).
header_type('Module',        module).

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


% ----------------------------------------------------------------------
% Unit-scoped NL relation section handling
% ----------------------------------------------------------------------

% split_unit_relations(+ClassifiedLines, -NonRelLines, -RelLines, -Messages)
%
% Relation sentences (if present) form a trailer section for the unit.
% Once the first relation sentence is encountered, subsequent non-blank
% lines are expected to be relation sentences as well; anything else is
% reported and ignored.
%
% NOTE: We do not attempt semantic checks here (defined IDs). Those occur
% later in parse_relation_lines/4 once Nodes are available.
split_unit_relations(ClassifiedLines, NonRelLines, RelLines, Messages) :-
    split_unit_relations(ClassifiedLines, before, [], NonRelRev, [], RelRev, [], MsgRev),
    reverse(NonRelRev, NonRelLines),
    reverse(RelRev, RelLines),
    reverse(MsgRev, Messages).

split_unit_relations([], _State, NonRelAcc, NonRelAcc, RelAcc, RelAcc, MsgAcc, MsgAcc) :- !.
split_unit_relations([CL|Rest], State, NonRelAcc0, NonRelAcc, RelAcc0, RelAcc, MsgAcc0, MsgAcc) :-
    (   State == before
    ->  (   is_relation_candidate(CL, Rel)
        ->  split_unit_relations(Rest, in_rel, NonRelAcc0, NonRelAcc, [Rel|RelAcc0], RelAcc, MsgAcc0, MsgAcc)
        ;   split_unit_relations(Rest, before, [CL|NonRelAcc0], NonRelAcc, RelAcc0, RelAcc, MsgAcc0, MsgAcc)
        )
    ;   % State == in_rel
        (   CL = cl_blank(_)
        ->  split_unit_relations(Rest, in_rel, NonRelAcc0, NonRelAcc, RelAcc0, RelAcc, MsgAcc0, MsgAcc)
        ;   is_relation_candidate(CL, Rel)
        ->  split_unit_relations(Rest, in_rel, NonRelAcc0, NonRelAcc, [Rel|RelAcc0], RelAcc, MsgAcc0, MsgAcc)
        ;   relation_section_unexpected_line(CL, Msg),
            split_unit_relations(Rest, in_rel, NonRelAcc0, NonRelAcc, RelAcc0, RelAcc, [Msg|MsgAcc0], MsgAcc)
        )
    ).

% A relation candidate must be a level-0 body line that matches a strict relation form.
is_relation_candidate(cl_body(N, 0, S0), cl_relation(N, S)) :-
    string_trim(S0, S),
    S \= "",
    is_relation_text(S),
    !.
is_relation_candidate(_, _) :- fail.

relation_section_unexpected_line(cl_header(N, _Level, Type, _IdOpt, _Label), relation_unexpected_header_in_relation_section(N, Type)).
relation_section_unexpected_line(cl_body(N, Level, S0), relation_unexpected_nonrelation_in_relation_section(N, Level, S)) :-
    string_trim(S0, S).
relation_section_unexpected_line(Other, relation_unexpected_line_in_relation_section(Other)).

known_ids_in_unit(Nodes, KnownIds) :-
    findall(Id, member(node(Id, _Type, _Label, _Body, _Level, _Line), Nodes), Ids0),
    sort(Ids0, KnownIds).


parse_relation_lines(RelLines, KnownIds, Edges, Messages) :-
    maplist(parse_relation_line(KnownIds), RelLines, Results),
    partition(is_relation_error, Results, ErrorTerms, EdgeLists),
    Messages = ErrorTerms,
    flatten(EdgeLists, Edges).

is_relation_error(relation_parse_error(_, _)).
is_relation_error(relation_undefined_ids(_, _, _)).

parse_relation_line(KnownIds, cl_relation(N, S0), EdgesOrErr) :-
    string_trim(S0, S),
    (   relation_supported_by_checked(KnownIds, S, GoalIds, SupporterIds, Undef)
    ->  (   Undef == [],
            GoalIds \= [],
            SupporterIds \= []
        ->  findall(supported_by(Goal, Supporter),
                    ( member(Goal, GoalIds),
                      member(Supporter, SupporterIds)
                    ),
                    Edges),
            EdgesOrErr = Edges
        ;   sort(Undef, UndefSorted),
            EdgesOrErr = relation_undefined_ids(N, UndefSorted, S)
        )
    ;   relation_supports_checked(KnownIds, S, SupporterIds, GoalIds, Undef)
    ->  (   Undef == [],
            GoalIds \= [],
            SupporterIds \= []
        ->  findall(supported_by(Goal, Supporter),
                    ( member(Goal, GoalIds),
                      member(Supporter, SupporterIds)
                    ),
                    Edges),
            EdgesOrErr = Edges
        ;   sort(Undef, UndefSorted),
            EdgesOrErr = relation_undefined_ids(N, UndefSorted, S)
        )
    ;   relation_in_context_checked(KnownIds, S, GoalIds, CtxIds, Undef)
    ->  (   Undef == [],
            GoalIds \= [],
            CtxIds \= []
        ->  findall(in_context_of(Goal, Ctx),
                    ( member(Goal, GoalIds),
                      member(Ctx, CtxIds)
                    ),
                    Edges),
            EdgesOrErr = Edges
        ;   sort(Undef, UndefSorted),
            EdgesOrErr = relation_undefined_ids(N, UndefSorted, S)
        )
    ;   relation_context_for_checked(KnownIds, S, CtxIds, GoalIds, Undef)
    ->  (   Undef == [],
            GoalIds \= [],
            CtxIds \= []
        ->  findall(in_context_of(Goal, Ctx),
                    ( member(Goal, GoalIds),
                      member(Ctx, CtxIds)
                    ),
                    Edges),
            EdgesOrErr = Edges
        ;   sort(Undef, UndefSorted),
            EdgesOrErr = relation_undefined_ids(N, UndefSorted, S)
        )
    ;   EdgesOrErr = relation_parse_error(N, S)
    ).

% Checked relation parsers
%
% These parsers avoid constructing bogus edges by:
%   (1) only operating on strict relation sentence templates, and
%   (2) extracting IDs by intersecting tokens with KnownIds.
%
% They return:
%   - Parsed IDs (GoalIds / SupporterIds / CtxIds)
%   - Undef: any non-separator tokens that were *not* found in KnownIds

relation_supported_by_checked(KnownIds, S0, GoalIds, SupporterIds, Undef) :-
    string_trim(S0, S1),
    strip_final_dot(S1, NoDot),
    split_string(NoDot, " ", " ", Tokens0),
    exclude(=(""), Tokens0, Tokens),
    (   append(LHSTokens, ["is","supported","by"|RHSTokens], Tokens)
    ;   append(LHSTokens, ["are","supported","by"|RHSTokens], Tokens)
    ),
    parse_id_tokens(KnownIds, LHSTokens, GoalIds, Undef0),
    parse_id_tokens(KnownIds, RHSTokens, SupporterIds, Undef1),
    append(Undef0, Undef1, Undef),
    (GoalIds \= [] ; SupporterIds \= []),
    !.

relation_supports_checked(KnownIds, S0, SupporterIds, GoalIds, Undef) :-
    string_trim(S0, S1),
    strip_final_dot(S1, NoDot),
    split_string(NoDot, " ", " ", Tokens0),
    exclude(=(""), Tokens0, Tokens),
    (   append(LHSTokens, ["support"|RHSTokens],  Tokens)
    ;   append(LHSTokens, ["supports"|RHSTokens], Tokens)
    ),
    parse_id_tokens(KnownIds, LHSTokens, SupporterIds, Undef0),
    parse_id_tokens(KnownIds, RHSTokens, GoalIds, Undef1),
    append(Undef0, Undef1, Undef),
    (SupporterIds \= [] ; GoalIds \= []),
    !.

relation_in_context_checked(KnownIds, S0, GoalIds, CtxIds, Undef) :-
    string_trim(S0, S1),
    strip_final_dot(S1, NoDot),
    split_string(NoDot, " ", " ", Tokens0),
    exclude(=(""), Tokens0, Tokens),
    (   append(LHSTokens, ["is","in","context","of"|RHSTokens], Tokens)
    ;   append(LHSTokens, ["are","in","context","of"|RHSTokens], Tokens)
    ),
    parse_id_tokens(KnownIds, LHSTokens, GoalIds, Undef0),
    parse_id_tokens(KnownIds, RHSTokens, CtxIds, Undef1),
    append(Undef0, Undef1, Undef),
    (GoalIds \= [] ; CtxIds \= []),
    !.

relation_context_for_checked(KnownIds, S0, CtxIds, GoalIds, Undef) :-
    string_trim(S0, S1),
    strip_final_dot(S1, NoDot),
    split_string(NoDot, " ", " ", Tokens0),
    exclude(=(""), Tokens0, Tokens),
    (   append(LHSTokens, ["is","context","for"|RHSTokens], Tokens)
    ;   append(LHSTokens, ["are","context","for"|RHSTokens], Tokens)
    ),
    parse_id_tokens(KnownIds, LHSTokens, CtxIds, Undef0),
    parse_id_tokens(KnownIds, RHSTokens, GoalIds, Undef1),
    append(Undef0, Undef1, Undef),
    (CtxIds \= [] ; GoalIds \= []),
    !.

parse_id_tokens(KnownIds, Tokens, Ids, Unknowns) :-
    findall(Id,
        ( member(T0, Tokens),
          normalize_relation_token(T0, T),
          T \= "",
          atom_string(Id, T),
          memberchk(Id, KnownIds)
        ),
        Ids0),
    findall(Unknown,
        ( member(T0, Tokens),
          normalize_relation_token(T0, T),
          T \= "",
          atom_string(Unknown, T),
          \+ memberchk(Unknown, KnownIds)
        ),
        Unknowns0),
    sort(Ids0, Ids),
    sort(Unknowns0, Unknowns).


% ----------------------------------------------------------------------
% Strict relation syntax recognition (no substring heuristics)
% ----------------------------------------------------------------------

is_relation_text(S0) :-
    string_trim(S0, S),
    (   relation_supported_by_raw(S, _GoalIds, _SupporterIds)
    ;   relation_supports_raw(S, _SupporterIds, _GoalIds)
    ;   relation_in_context_raw(S, _GoalIds, _CtxIds)
    ;   relation_context_for_raw(S, _CtxIds, _GoalIds)
    ),
    !.

relation_supported_by_raw(S0, GoalIds, SupporterIds) :-
    string_trim(S0, S1),
    strip_final_dot(S1, NoDot),
    split_string(NoDot, " ", " ", Tokens0),
    exclude(=(""), Tokens0, Tokens),
    (   append(LHSTokens, ["is","supported","by"|RHSTokens], Tokens)
    ;   append(LHSTokens, ["are","supported","by"|RHSTokens], Tokens)
    ),
    ids_from_tokens(LHSTokens, GoalIds),
    ids_from_tokens(RHSTokens, SupporterIds),
    GoalIds \= [],
    SupporterIds \= [].

% Interprets “X supports Y” as: Y is supported by X (i.e., supported_by(Y, X)).
relation_supports_raw(S0, SupporterIds, GoalIds) :-
    string_trim(S0, S1),
    strip_final_dot(S1, NoDot),
    split_string(NoDot, " ", " ", Tokens0),
    exclude(=(""), Tokens0, Tokens),
    (   append(LHSTokens, ["support"|RHSTokens],  Tokens)
    ;   append(LHSTokens, ["supports"|RHSTokens], Tokens)
    ),
    ids_from_tokens(LHSTokens, SupporterIds),
    ids_from_tokens(RHSTokens, GoalIds),
    GoalIds \= [],
    SupporterIds \= [].

relation_in_context_raw(S0, GoalIds, CtxIds) :-
    string_trim(S0, S1),
    strip_final_dot(S1, NoDot),
    split_string(NoDot, " ", " ", Tokens0),
    exclude(=(""), Tokens0, Tokens),
    append(LHSTokens, ["is","in","context","of"|RHSTokens], Tokens),
    ids_from_tokens(LHSTokens, GoalIds),
    ids_from_tokens(RHSTokens, CtxIds),
    GoalIds \= [],
    CtxIds \= [].

relation_context_for_raw(S0, CtxIds, GoalIds) :-
    string_trim(S0, S1),
    strip_final_dot(S1, NoDot),
    split_string(NoDot, " ", " ", Tokens0),
    exclude(=(""), Tokens0, Tokens),
    (   append(LHSTokens, ["provides","context","for"|RHSTokens], Tokens)
    ;   append(LHSTokens, ["provide","context","for"|RHSTokens],  Tokens)
    ),
    ids_from_tokens(LHSTokens, CtxIds),
    ids_from_tokens(RHSTokens, GoalIds),
    CtxIds \= [],
    GoalIds \= [].

% ----------------------------------------------------------------------
% Token → ID extraction and defined-ID checking
% ----------------------------------------------------------------------

ids_from_tokens(Tokens, Ids) :-
    findall(Id,
        ( member(T0, Tokens),
          normalize_relation_token(T0, T),
          T \= "",
          atom_string(Id, T)
        ),
        Ids0),
    sort(Ids0, Ids).

normalize_relation_token(T0, T) :-
    strip_trailing_punct(T0, T1),
    string_trim(T1, T2),
    (   T2 == ""
    ->  T = ""
    ;   T2 == "and"
    ->  T = ""
    ;   T = T2
    ).

strip_trailing_punct(Token0, Clean) :-
    % remove trailing commas/colons (final dot is handled earlier)
    ( sub_string(Token0, _, 1, 0, ",")
    -> sub_string(Token0, 0, _, 1, T1)
    ;  T1 = Token0
    ),
    ( sub_string(T1, _, 1, 0, ":")
    -> sub_string(T1, 0, _, 1, Clean)
    ;  Clean = T1
    ).



% strip_trailing_comma(+Token0, -Clean)
strip_trailing_comma(Token0, Clean) :-
    ( sub_string(Token0, _, 1, 0, ",")
    -> sub_string(Token0, 0, _, 1, Clean)
    ;  Clean = Token0
    ).

% valid_id_token(+TokenString)
%
% This is a *lexical* check used only to disambiguate node headers of the form:
%   "Goal <Id> <Label>:"
% from:
%   "Goal <Label>:"
%
% It is intentionally permissive: it accepts common ID forms including dotted
% canonical IDs, underscores, and hyphens, but rejects tokens that clearly
% cannot be IDs in this grammar (empty tokens or tokens containing whitespace).
valid_id_token(S) :-
    % Accept either a string or an atom token.
    (   string(S)
    ->  T = S
    ;   atom(S)
    ->  atom_string(S, T)
    ),
    T \= "",
    \+ sub_string(T, _, 1, _, " "),
    \+ sub_string(T, _, 1, _, "\t"),
    % Disallow obvious header terminators inside the token.
    \+ sub_string(T, _, 1, _, ":"),
    % Disallow a trailing ':' (already handled by strip_trailing_punct/2 in other contexts).
    \+ sub_string(T, _, 1, 0, ":"),
    % Require at least one alphanumeric character.
    string_codes(T, Codes),
    member(C, Codes),
    code_type(C, alnum),
    !.

check_defined_ids(_Known, [], [], []) :- !.
check_defined_ids(KnownIds, [Id|Rest], [Id|Keep], Undef) :-
    memberchk(Id, KnownIds),
    !,
    check_defined_ids(KnownIds, Rest, Keep, Undef).
check_defined_ids(KnownIds, [Id|Rest], Keep, [Id|Undef]) :-
    check_defined_ids(KnownIds, Rest, Keep, Undef).

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

    % Cross-branch edges (explicit relations not already implied by indentation):
    %   Count only *explicit* relation edges that are not already implied by
    %   indentation (TreeEdges). This prevents structural supported_by /
    %   in_context_of edges (from indentation) from being double-counted.
    exclude({TreeEdges}/[E]>>memberchk(E, TreeEdges), RelEdges, RelOnlyEdges),
    findall(E,
        ( member(E, RelOnlyEdges),
          ( E = supported_by(P, C)
          ; E = in_context_of(P, C)
          ),
          \+ reachable_in_tree(P, C, TreeEdges)
        ),
        CrossEdges0),
    sort(CrossEdges0, CrossEdges),
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

count_nodes_of_type(Type, Nodes, Count) :-
    include(node_of_type(Type), Nodes, Filtered),
    length(Filtered, Count).

node_of_type(Type, node(_, Type, _, _, _, _)).

% reachable_in_tree(+Parent, +Child, +TreeEdges)
% True if Child is reachable from Parent following indentation-derived tree edges.
reachable_in_tree(Parent, Child, TreeEdges) :-
    reachable_in_tree_(Parent, Child, TreeEdges, [Parent]).

reachable_in_tree_(Parent, Child, TreeEdges, _Visited) :-
    tree_edge(Parent, Child, TreeEdges),
    !.
reachable_in_tree_(Parent, Child, TreeEdges, Visited) :-
    tree_edge(Parent, Mid, TreeEdges),
    \+ memberchk(Mid, Visited),
    reachable_in_tree_(Mid, Child, TreeEdges, [Mid|Visited]).

tree_edge(P, C, TreeEdges) :-
    (   memberchk(supported_by(P, C), TreeEdges)
    ;   memberchk(in_context_of(P, C), TreeEdges)
    ).

cycle_detected(P, C, TreeEdges) :-
    reachable_in_tree(C, P, TreeEdges).

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

% Remove a final '.' if present (sentence terminator), but leave
% internal dots in IDs like "G1." or "A1.1".
strip_final_dot(S0, S) :-
    ( sub_string(S0, _, 1, 0, ".")
    -> sub_string(S0, 0, _, 1, S)
    ;  S = S0
    ).

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
    maplist(=(0' ), Codes), % all spaces
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

%------------------------- DIAGNOSTICS
diag0 :-
    read_file_to_string('../TEST/ACO/bio_v4.aco', S, []),
    once( aco_core:aco_core_parse('bio_v4.aco', S,
        _IndentSpec, _CaseHeaderOpt,
        _Headers, _Nodes,
        TreeEdges, RelEdges, AllEdges,
        _IndentMsg, _BodyMsgs, _NodeMsgs,
        _IndentMsgs, RelMsgs0, RelMsgs1)
        ),

    length(TreeEdges, NT),
    length(RelEdges, NR),
    length(AllEdges, NA),
    length(RelMsgs0, NRM0),
    length(RelMsgs1, NRM1),

    format("TreeEdges=~w  RelEdges=~w  AllEdges=~w~n", [NT,NR,NA]),
    format("RelMsgs0=~w  RelMsgs1=~w~n", [NRM0,NRM1]),

    % show a few sample relation edges
    %take(20, RelEdges, SampleRel),
    %writeln(sample_rel_edges=SampleRel).
    forall((nth1(I,RelEdges,E), I =< 20), writeln(E)).

%------------------------- DIAGNOSTICS
% diag1: op_plane edge breakdown (TreeEdges vs RelEdges vs RelOnly)
diag1 :-
    read_file_to_string('../TEST/ACO/op_plane.aco', S, []),
    once( aco_core:aco_core_parse('op_plane.aco', S,
        _IndentSpec, _CaseHeaderOpt,
        _Headers, _Nodes,
        TreeEdges, RelEdges, _AllEdges,
        _IndentMsg, _BodyMsgs, _NodeMsgs,
        _IndentMsgs, _RelMsgs0, _RelMsgs1)
    ),
    exclude({TreeEdges}/[E]>>memberchk(E, TreeEdges), RelEdges, RelOnlyEdges),
    format('tree_edges=~w~n', [TreeEdges]),
    format('rel_edges=~w~n', [RelEdges]),
    format('rel_only=~w~n', [RelOnlyEdges]).
