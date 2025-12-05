:- module(aco_apl,
    [
        aco_string_to_apl_pattern/4,   % +SourceName,+String,-Pattern,-Messages
        aco_file_to_apl_pattern/3,     % +ACOFile,-Pattern,-Messages
        aco_file_to_apl_file/2         % +ACOFile,+APLFile
    ]).

/*  ACO → APL translation
    ----------------------

    This module turns an ACO outline into a *nested* APL pattern of the form:

        ac_pattern(PatternId, [], GoalTree).

    where GoalTree is a standard APL term:

        goal(Id, ClaimText, ContextList, BodyList)

    and BodyList may contain:

        - goal/4       (subgoals)
        - strategy/3   (Claim, Contexts, Body)
        - evidence/3   (Category, Description, Contexts)

    The translator:

      * Reuses the existing ACO pipeline via aco_core:aco_core_parse/15.
      * Uses only indentation-tree edges (supported_by/2 from indent) for structure.
      * Uses in_context_of/2 edges to collect context/assumption/justification items.
      * Keeps ACO node IDs (for goals/modules) unchanged.
      * Derives the pattern id from the Case: header title, keeping case, but
        normalising spaces/punctuation to '_' and returning a quoted atom.
*/

:- use_module(library(readutil)).
:- use_module(library(lists)).
:- use_module(library(pairs)).

:- use_module(aco_core).   % must export aco_core_parse/15
:- use_module(aco_processor, [canonicalize_aco_string/4]).

% ----------------------------------------------------------------------
% Public API
% ----------------------------------------------------------------------

/*
%% aco_file_to_apl_pattern(+ACOFile,-Pattern,-Messages)
%
%  Read an .aco file and translate to a single ac_pattern/3 term.

aco_file_to_apl_pattern(ACOFile, Pattern, Messages) :-
    read_file_to_string(ACOFile, Raw, [newline(detect)]),
    aco_string_to_apl_pattern(ACOFile, Raw, Pattern, Messages).
*/

%% aco_file_to_apl_pattern(+ACOFile,-Pattern,-Messages)
%
%  Read an .aco file, canonicalise it, and translate the canonical
%  version to a single ac_pattern/3 term.

aco_file_to_apl_pattern(ACOFile, Pattern, Messages) :-
    read_file_to_string(ACOFile, Raw, [newline(detect)]),
    % Step 1: canonicalise the ACO (IDs, ordering, relations)
    canonicalize_aco_string(ACOFile, Raw, CanonRaw, CanonMsgs),
    % Step 2: run the APL translation on the canonical text
    aco_string_to_apl_pattern(ACOFile, CanonRaw, Pattern, AplMsgs),
    % Step 3: combine messages (canonicalisation + APL layer)
    append(CanonMsgs, AplMsgs, Messages).

/*
%% aco_file_to_apl_file(+ACOFile,+APLFile)
%
%  Convenience wrapper: read ACO, translate to APL, pretty-print to file.

aco_file_to_apl_file(ACOFile, APLFile) :-
    aco_file_to_apl_pattern(ACOFile, Pattern, Messages),
    print_apl_messages(Messages),
    setup_call_cleanup(
        open(APLFile, write, Out),
        portray_clause(Out, Patter),
        close(Out)
    ).

aco_file_to_apl_file(ACOFile, APLFile) :-
    aco_file_to_apl_pattern(ACOFile, Pattern, Messages),
    print_apl_messages(Messages),
    setup_call_cleanup(
        open(APLFile, write, Out),
        print_apl_pattern(Out, Pattern),
        close(Out)
    ).
*/

%% aco_file_to_apl_file(+ACOFile,+APLFile)
%
%  Convenience wrapper: read ACO, translate to APL, pretty-print to file.
%  Output style is similar to KB/PATTERNS patterns_MILS.pl.

aco_file_to_apl_file(ACOFile, APLFile) :-
    aco_file_to_apl_pattern(ACOFile, Pattern, Messages),
    print_apl_messages(Messages),
    setup_call_cleanup(
        open(APLFile, write, Out),
        print_apl_pattern(Out, Pattern),
        close(Out)
    ).

% ----------------------------------------------------------------------
% Pretty-printing APL (ac_pattern/3, goal/4, strategy/3, evidence/3)
% ----------------------------------------------------------------------

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

% ---------------- goals / strategies / evidence ----------------

pp_goal(Stream, Indent, goal(Id, Claim, Contexts, Body)) :-
    format(Stream, "goal(~q,~n", [Id]),
    Ind1 is Indent + 4,

    % Claim
    indent(Stream, Ind1),
    format(Stream, "~q,~n", [Claim]),

    % Context list
    indent(Stream, Ind1),
    pp_list(Stream, Ind1, Contexts),
    format(Stream, ",~n", []),

    % Body list
    indent(Stream, Ind1),
    pp_list(Stream, Ind1, Body),
    nl(Stream),
    indent(Stream, Indent),
    format(Stream, ")", []).

pp_strategy(Stream, Indent, strategy(Claim, Contexts, Body)) :-
    format(Stream, "strategy(~q,~n", [Claim]),
    Ind1 is Indent + 4,

    % Context list
    indent(Stream, Ind1),
    pp_list(Stream, Ind1, Contexts),
    format(Stream, ",~n", []),

    % Body list
    indent(Stream, Ind1),
    pp_list(Stream, Ind1, Body),
    nl(Stream),
    indent(Stream, Indent),
    format(Stream, ")", []).

pp_evidence(Stream, Indent, evidence(Category, Desc, Contexts)) :-
    format(Stream, "evidence(~q,~n", [Category]),
    Ind1 is Indent + 4,

    % Description
    indent(Stream, Ind1),
    format(Stream, "~q,~n", [Desc]),

    % Context list
    indent(Stream, Ind1),
    pp_list(Stream, Ind1, Contexts),
    nl(Stream),
    indent(Stream, Indent),
    format(Stream, ")", []).

% ---------------- generic list + term printers ----------------

% pp_list(+Stream,+Indent,+List)
% Prints [ ... ] with each element on its own line, indented.

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

% pp_term: dispatch on the main APL constructors we generate.
% Anything else falls back to write_term/3 with quoting.

pp_term(Stream, Indent, goal(Id, Claim, Ctx, Body)) :-
    pp_goal(Stream, Indent, goal(Id, Claim, Ctx, Body)).
pp_term(Stream, Indent, strategy(Claim, Ctx, Body)) :-
    pp_strategy(Stream, Indent, strategy(Claim, Ctx, Body)).
pp_term(Stream, Indent, evidence(Cat, Desc, Ctx)) :-
    pp_evidence(Stream, Indent, evidence(Cat, Desc, Ctx)).
pp_term(Stream, _Indent, Term) :-
    % Generic fallback, for context/assumption/justification/etc.
    write_term(Stream, Term, [quoted(true)]).

% ---------------- indentation helper ----------------

indent(_Stream, 0) :- !.
indent(Stream, N) :-
    N > 0,
    put_char(Stream, ' '),
    N1 is N - 1,
    indent(Stream, N1).%% aco_file_to_apl_file(+ACOFile,+APLFile)

/*
%
%  Convenience wrapper: read ACO, translate to APL, pretty-print to file.
%  Output style is similar to KB/PATTERNS patterns_MILS.pl.

% ----------------------------------------------------------------------
% Pretty-printing APL (ac_pattern/3, goal/4, strategy/3, evidence/3)
% ----------------------------------------------------------------------

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
*/

% ---------------- goals / strategies / evidence ----------------
/*
pp_goal(Stream, Indent, goal(Id, Claim, Contexts, Body)) :-
    format(Stream, "goal(~q,~n", [Id]),
    Ind1 is Indent + 4,

    % Claim
    indent(Stream, Ind1),
    format(Stream, "~q,~n", [Claim]),

    % Context list
    indent(Stream, Ind1),
    pp_list(Stream, Ind1, Contexts),

    format(Stream, ",~n", []),

    % Body list
    indent(Stream, Ind1),
    pp_list(Stream, Ind1, Body),
    nl(Stream),
    indent(Stream, Indent),
    format(Stream, ")", []).

pp_strategy(Stream, Indent, strategy(Claim, Contexts, Body)) :-
    format(Stream, "strategy(~q,~n", [Claim]),
    Ind1 is Indent + 4,

    % Context list
    indent(Stream, Ind1),
    pp_list(Stream, Ind1, Contexts),
    format(Stream, ",~n", []),

    % Body list
    indent(Stream, Ind1),
    pp_list(Stream, Ind1, Body),
    nl(Stream),
    indent(Stream, Indent),
    format(Stream, ")", []).

pp_evidence(Stream, Indent, evidence(Category, Desc, Contexts)) :-
    format(Stream, "evidence(~q,~n", [Category]),
    Ind1 is Indent + 4,

    % Description
    indent(Stream, Ind1),
    format(Stream, "~q,~n", [Desc]),

    % Context list
    indent(Stream, Ind1),
    pp_list(Stream, Ind1, Contexts),
    nl(Stream),
    indent(Stream, Indent),
    format(Stream, ")", []).
% ---------------- generic list + term printers ----------------

% pp_list(+Stream,+Indent,+List)
% Prints [ ... ] with each element on its own line, indented.

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

% pp_term: dispatch on the main APL constructors we generate.
% Anything else falls back to write_term/3 with quoting.

pp_term(Stream, Indent, goal(Id, Claim, Ctx, Body)) :-
    pp_goal(Stream, Indent, goal(Id, Claim, Ctx, Body)).
pp_term(Stream, Indent, strategy(Claim, Ctx, Body)) :-
    pp_strategy(Stream, Indent, strategy(Claim, Ctx, Body)).
pp_term(Stream, Indent, evidence(Cat, Desc, Ctx)) :-
    pp_evidence(Stream, Indent, evidence(Cat, Desc, Ctx)).
pp_term(Stream, _Indent, Term) :-
    % Generic fallback, for context/assumption/justification/etc.
    write_term(Stream, Term, [quoted(true)]).

% ---------------- indentation helper ----------------

indent(_Stream, 0) :- !.
indent(Stream, N) :-
    N > 0,
    put_char(Stream, ' '),
    N1 is N - 1,
    indent(Stream, N1).
*/


%% aco_string_to_apl_pattern(+SourceName,+Raw,-Pattern,-Messages)
%
%  Core entry: given an ACO source string, produce one ac_pattern/3 term.

aco_string_to_apl_pattern(SourceName, Raw, Pattern, Messages) :-
    aco_core_parse(SourceName, Raw,
                   _IndentSpec, CaseHeaderOpt,
                   _Headers, Nodes0,
                   TreeEdges, _RelEdges, _AllEdges,
                   IndentMsg, BodyMsgs, NodeMsgs,
                   IndentMsgs, RelMsgs0, RelMsgs1),

    % Build lookup structures from Nodes0 + TreeEdges
    build_node_index(Nodes0, NodesById),
    build_child_map(TreeEdges, ChildMap),
    build_context_map(TreeEdges, CtxMap),

    % Choose the root node to become the pattern's top goal
    choose_root(Nodes0, ChildMap, RootId, RootMessages),

    % Case header -> pattern id + optional extra context
    pattern_id_from_case(CaseHeaderOpt, PatternId, CaseCtx),

    % Build nested Goal tree starting from RootId
    build_goal_tree(RootId, NodesById, ChildMap, CtxMap,
                    [], GoalTree, _VisitedFinal, CaseCtx),

    % Final APL pattern (no top-level pattern arguments for now)
    Pattern = ac_pattern(PatternId, [], GoalTree),

    % Collate messages (parse messages + our own)
    append([ [IndentMsg],
             [BodyMsgs],
             [NodeMsgs],
             [IndentMsgs],
             [RelMsgs0],
             [RelMsgs1],
             [RootMessages]
           ],
           MsgLists),
    flatten(MsgLists, Messages).


% ----------------------------------------------------------------------
% Message printing helper (optional for CLI)
% ----------------------------------------------------------------------

print_apl_messages([]).
print_apl_messages([M|Ms]) :-
    format('apl-info: ~q~n', [M]),
    print_apl_messages(Ms).


% ----------------------------------------------------------------------
% Node and edge indexing
% ----------------------------------------------------------------------

% build_node_index(+Nodes,-NodesById)
% NodesById is an assoc-like list Id-Node.

build_node_index(Nodes, NodesById) :-
    findall(Id-node(Id,Type,Label,Body,Level,Line),
            member(node(Id,Type,Label,Body,Level,Line), Nodes),
            NodesById).

lookup_node(Id, NodesById, Node) :-
    member(Id-Node, NodesById).


% build_child_map(+TreeEdges,-ChildMap)
% ChildMap: ParentId-[ChildId,...] for supported_by/2 edges (indent tree).

build_child_map(TreeEdges, ChildMap) :-
    findall(P-C,
            member(supported_by(P,C), TreeEdges),
            Pairs0),
    sort(Pairs0, Pairs),
    group_pairs_by_key(Pairs, ChildMap).

children_of(Id, ChildMap, Children) :-
    (   member(Id-Childs0, ChildMap)
    ->  sort(Childs0, Children)
    ;   Children = []
    ).


% build_context_map(+TreeEdges,-CtxMap)
% CtxMap: ParentId-[CtxId,...] for in_context_of/2 edges.

build_context_map(TreeEdges, CtxMap) :-
    findall(P-C,
            member(in_context_of(P,C), TreeEdges),
            Pairs0),
    sort(Pairs0, Pairs),
    group_pairs_by_key(Pairs, CtxMap).

contexts_of(Id, CtxMap, CtxIds) :-
    (   member(Id-CtxIds0, CtxMap)
    ->  sort(CtxIds0, CtxIds)
    ;   CtxIds = []
    ).


% ----------------------------------------------------------------------
% Root selection
% ----------------------------------------------------------------------

choose_root(Nodes, ChildMap, RootId, Messages) :-
    % all ids
    findall(Id, member(node(Id,_,_,_,_,_), Nodes), AllIds0),
    sort(AllIds0, AllIds),
    % all children
    findall(C,
            ( member(_P-Children, ChildMap),
              member(C, Children)
            ),
            Childs0),
    sort(Childs0, Childs),
    % roots = ids that are never children
    findall(Id,
            ( member(Id, AllIds),
              \+ memberchk(Id, Childs)
            ),
            CandidateRoots0),
    % keep only goal/module roots if possible
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
              member(node(Id,Type,_,_,_,_), Nodes),
              (Type = goal ; Type = module)
            ),
            Interesting),
    ( Interesting \= [] -> Filtered = Interesting
    ; Filtered = CandidateIds
    ).


% ----------------------------------------------------------------------
% Pattern id & case header handling
% ----------------------------------------------------------------------

pattern_id_from_case(none, 'anonymous_case', []).
pattern_id_from_case(some(case_header(TitleAtom, ScopeAtom)), PatternId, CaseCtx) :-
    % TitleAtom and ScopeAtom are atoms.
    atom_string(TitleAtom, TitleStr),
    title_to_slug_keep_caps(TitleStr, SlugStr),
    atom_string(PatternId, SlugStr),

    % Optional extra context derived from Case header
    atom_string(ScopeAtom, ScopeStr),
    ( ScopeStr = ""
    -> format(string(CaseText), "Case: ~w", [TitleStr])
    ;  format(string(CaseText), "Case: ~w — ~w", [TitleStr, ScopeStr])
    ),
    CaseCtx = [context(CaseText)].

% Replace non-alphanumeric chars with '_' but keep case and collapse runs.

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
collapse_underscores_([0'_|Rest], [], Acc) :-        % leading underscore
    collapse_underscores_(Rest, [], Acc).
collapse_underscores_([0'_|Rest], [0'_ | Acc], Out) :-  % consecutive '_'
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


% ----------------------------------------------------------------------
% Building the nested Goal tree
% ----------------------------------------------------------------------

% build_goal_tree(+Id,+NodesById,+ChildMap,+CtxMap,+Visited0,
%                 -Goal,-Visited, +ExtraCtx)
%
% ExtraCtx is used only at the top level to add Case: context.

build_goal_tree(Id, NodesById, ChildMap, CtxMap,
                Visited0, Goal, Visited, ExtraCtx) :-
    (   memberchk(Id, Visited0)
    ->  % break cycles defensively
        Goal = goal(Id, 'Cyclic reference (omitted)', [], []),
        Visited = Visited0
    ;   lookup_node(Id, NodesById,
                    node(Id, Type, _Label, Body, _Level, _Line)),
        ( Type = goal ; Type = module ),
        !,
        Visited1 = [Id|Visited0],
        % Claim text: prefer Body if present, else use Id as a placeholder
        claim_text_from_body_or_id(Body, Id, ClaimText),

        % Contexts for this node
        contexts_for_node(Id, NodesById, ChildMap, CtxMap, NodeCtx),
        append(ExtraCtx, NodeCtx, CtxAll),

        % Children: goals, strategies, evidence
        children_of(Id, ChildMap, ChildIds),
        build_children_terms(ChildIds, NodesById, ChildMap, CtxMap,
                             Visited1, BodyTerms, Visited),
        Goal = goal(Id, ClaimText, CtxAll, BodyTerms)
    ;
        % Fallback: if Id is not a goal/module, manufacture a goal wrapper
        Visited1 = [Id|Visited0],
        claim_text_from_body_or_id('', Id, ClaimText2),
        contexts_for_node(Id, NodesById, ChildMap, CtxMap, NodeCtx2),
        children_of(Id, ChildMap, ChildIds2),
        build_children_terms(ChildIds2, NodesById, ChildMap, CtxMap,
                             Visited1, BodyTerms2, Visited),
        Goal = goal(Id, ClaimText2, NodeCtx2, BodyTerms2)
    ).

claim_text_from_body_or_id(Body, Id, ClaimText) :-
    ( Body \= '',
      Body \= ""
    -> ClaimText = Body
    ; atom_string(Id, IdStr),
      ClaimText = IdStr
    ).


% build_children_terms(+ChildIds,...,-Terms,-VisitedOut)

build_children_terms([], _NodesById, _ChildMap, _CtxMap, Visited, [], Visited).
build_children_terms([ChildId|Rest], NodesById, ChildMap, CtxMap,
                     Visited0, [Term|Terms], VisitedOut) :-
    lookup_node(ChildId, NodesById,
                node(ChildId, Type, _Label, _Body, _Lev, _Line)),
    (   Type = goal
    ;   Type = module
    ),
    !,
    build_goal_tree(ChildId, NodesById, ChildMap, CtxMap,
                    Visited0, Term, Visited1, []),
    build_children_terms(Rest, NodesById, ChildMap, CtxMap,
                         Visited1, Terms, VisitedOut).

build_children_terms([ChildId|Rest], NodesById, ChildMap, CtxMap,
                     Visited0, [Term|Terms], VisitedOut) :-
    lookup_node(ChildId, NodesById,
                node(ChildId, strategy, _Label, Body, _Lev, _Line)),
    !,
    build_strategy_tree(ChildId, Body, NodesById, ChildMap, CtxMap,
                        Visited0, Term, Visited1),
    build_children_terms(Rest, NodesById, ChildMap, CtxMap,
                         Visited1, Terms, VisitedOut).

build_children_terms([ChildId|Rest], NodesById, ChildMap, CtxMap,
                     Visited0, [Term|Terms], VisitedOut) :-
    lookup_node(ChildId, NodesById,
                node(ChildId, evidence, Label, Body, _Lev, _Line)),
    !,
    build_evidence_term(ChildId, Label, Body, NodesById, ChildMap, CtxMap, Term),
    Visited1 = [ChildId|Visited0],
    build_children_terms(Rest, NodesById, ChildMap, CtxMap,
                         Visited1, Terms, VisitedOut).

% If child is a context/assumption/justification directly under a goal,
% we simply ignore it here (it should appear via in_context_of/2).

build_children_terms([ChildId|Rest], NodesById, ChildMap, CtxMap,
                     Visited0, Terms, VisitedOut) :-
    lookup_node(ChildId, NodesById,
                node(ChildId, Type, _Label, _Body, _Lev, _Line)),
    (Type = context ; Type = assumption ; Type = justification),
    !,
    build_children_terms(Rest, NodesById, ChildMap, CtxMap,
                         Visited0, Terms, VisitedOut).

% Fallback: unknown type → skip with a warning-like message, but
% do not fail the whole translation.

build_children_terms([ChildId|Rest], NodesById, ChildMap, CtxMap,
                     Visited0, Terms, VisitedOut) :-
    format(user_error,
           'apl-warning: skipping unsupported node type for id ~w~n',
           [ChildId]),
    build_children_terms(Rest, NodesById, ChildMap, CtxMap,
                         Visited0, Terms, VisitedOut).


% ----------------------------------------------------------------------
% Strategy and evidence construction
% ----------------------------------------------------------------------

% build_strategy_tree(+Id,+Body,+NodesById,+ChildMap,+CtxMap,
%                     +Visited0,-Strategy,-VisitedOut)

build_strategy_tree(Id, Body, NodesById, ChildMap, CtxMap,
                    Visited0, Strategy, VisitedOut) :-
    (   memberchk(Id, Visited0)
    ->  Strategy = strategy('Cyclic strategy (omitted)', [], []),
        VisitedOut = Visited0
    ;   Visited1 = [Id|Visited0],
        claim_text_from_body_or_id(Body, Id, ClaimText),
        contexts_for_node(Id, NodesById, ChildMap, CtxMap, Ctx),
        children_of(Id, ChildMap, ChildIds),
        build_children_terms(ChildIds, NodesById, ChildMap, CtxMap,
                             Visited1, BodyTerms, VisitedOut),
        Strategy = strategy(ClaimText, Ctx, BodyTerms)
    ).


% build_evidence_term(+Id,+Label,+Body,+NodesById,+ChildMap,+CtxMap,-Evidence)
%
% Category := Label (ACO label atom).
% Description := Body if present, otherwise the label string.
% Contexts from in_context_of/2 edges.

build_evidence_term(Id, LabelAtom, Body, NodesById, ChildMap, CtxMap, Evidence) :-
    % Category := Label atom
    Category = LabelAtom,
    % Description text: prefer Body, else label
    ( Body \= '',
      Body \= ""
    -> Desc = Body
    ;  atom_string(LabelAtom, Desc)
    ),
    contexts_for_node(Id, NodesById, ChildMap, CtxMap, Ctx),
    Evidence = evidence(Category, Desc, Ctx).

% ----------------------------------------------------------------------
% Context extraction
% ----------------------------------------------------------------------

% contexts_for_node(+Id,+NodesById,+ChildMap,+CtxMap,-ContextTerms)
%
% Contexts come from two places:
%   1) explicit in_context_of/2 edges (CtxMap)
%   2) directly indented children whose type is
%      context/assumption/justification.

contexts_for_node(Id, NodesById, ChildMap, CtxMap, ContextTerms) :-
    % 1) Explicit in_context_of edges
    contexts_of(Id, CtxMap, CtxIds1),

    % 2) Direct children of context-ish types
    children_of(Id, ChildMap, ChildIds),
    findall(CId,
            ( member(CId, ChildIds),
              lookup_node(CId, NodesById,
                          node(CId, Type, _Label, _Body, _Lev, _Line)),
              ( Type = context
              ; Type = assumption
              ; Type = justification
              )
            ),
            CtxIds2),

    % Combine and normalise
    append(CtxIds1, CtxIds2, CtxIdsAll0),
    sort(CtxIdsAll0, CtxIdsAll),
    build_context_terms(CtxIdsAll, NodesById, ContextTerms).

build_context_terms([], _NodesById, []).
build_context_terms([CtxId|Rest], NodesById, [Term|Terms]) :-
    lookup_node(CtxId, NodesById,
                node(CtxId, Type, _Label, Body, _Level, _Line)),
    context_term(Type, Body, Term),
    !,
    build_context_terms(Rest, NodesById, Terms).
build_context_terms([_CtxId|Rest], NodesById, Terms) :-
    % Unsupported type as context: just skip.
    build_context_terms(Rest, NodesById, Terms).

context_term(context,      Body, context(Text))       :- context_text(Body, Text).
context_term(assumption,   Body, assumption(Text))    :- context_text(Body, Text).
context_term(justification,Body, justification(Text)) :- context_text(Body, Text).

context_text(Body, Text) :-
    ( Body \= '',
      Body \= ""
    -> Text = Body
    ;  Text = ''
    ).

/*
% ----------------------------------------------------------------------
% Context extraction
% ----------------------------------------------------------------------

contexts_for_node(Id, NodesById, CtxMap, ContextTerms) :-
    contexts_of(Id, CtxMap, CtxIds),
    build_context_terms(CtxIds, NodesById, ContextTerms).

build_context_terms([], _NodesById, []).
build_context_terms([CtxId|Rest], NodesById, [Term|Terms]) :-
    lookup_node(CtxId, NodesById,
                node(CtxId, Type, _Label, Body, _Level, _Line)),
    context_term(Type, Body, Term),
    !,
    build_context_terms(Rest, NodesById, Terms).
build_context_terms([_CtxId|Rest], NodesById, Terms) :-
    % Unsupported type as context: just skip.
    build_context_terms(Rest, NodesById, Terms).

context_term(context,      Body, context(Text))       :- context_text(Body, Text).
context_term(assumption,   Body, assumption(Text))    :- context_text(Body, Text).
context_term(justification,Body, justification(Text)) :- context_text(Body, Text).

context_text(Body, Text) :-
    ( Body \= '',
      Body \= ""
    -> Text = Body
    ;  Text = ''
    ).
*/
