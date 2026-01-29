:- module(aco_modularize, [
    modularize/3            % +Goals, +InFile, +OutFile
]).

:- use_module(library(readutil)).
:- use_module(library(lists)).
:- use_module(library(apply)).
:- use_module(library(pcre)).

% ----------------------------------------------------------------------
% T6: Modularize selected goal subtrees (ACO-level, line-preserving)
%
% modularize(Goals, InFile, OutFile)
%   Goals: a single goal id atom, or a list of goal id atoms.
%   InFile:  input .aco file.
%   OutFile: output .aco file.
%
% For each selected goal G:
%   - Extract the entire subtree rooted at the goal header line.
%   - Write that subtree verbatim to a module .aco file placed alongside OutFile.
%   - Replace the subtree in OutFile with a single Module node header at the same
%     indentation level, preserving the goal id and label at the call site.
%
% Determinism & hygiene:
%   - Minimal-diff discipline: only the replaced subtree range changes.
%   - Output uses LF line endings and always ends with a final newline.
% ----------------------------------------------------------------------


modularize(Goals0, InFile0, OutFile0) :-
    must_be(atom, InFile0),
    must_be(atom, OutFile0),
    normalize_goals_arg(Goals0, Goals1),
    strip_cr_atom(InFile0, InFile),
    strip_cr_atom(OutFile0, OutFile),
    read_file_to_string(InFile, Raw, [newline(detect)]),
    split_string_preserve_empty(Raw, Lines),
    index_goal_headers(Lines, GoalIndex),
    order_goals_descendants_first(Goals1, GoalIndex, GoalsOrdered),
    modularize_loop(GoalsOrdered, GoalIndex, Lines, Lines1, ModuleUnitsRev),
    reverse(ModuleUnitsRev, ModuleUnits),
    append_module_units(Lines1, ModuleUnits, LinesOut),
    write_lines_lf(OutFile, LinesOut).


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
% Splitting/joining lines with predictable LF behavior
% ----------------------------------------------------------------------

split_string_preserve_empty(Raw, Lines) :-
    (   Raw == ""
    ->  Lines = ["" ]
    ;   split_string(Raw, "\n", "", Lines0),
        % If Raw ends with a newline, split_string/4 yields a trailing "".
        % We keep it so that write_lines_lf/2 reproduces a final newline.
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
    % Always end with a newline (even for empty content).
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
    % BIO style: "  Goal G1 confidentiality:"
    %            "          Goal G1121 secureChannelsToExternalSources:"
    re_matchsub('^(\\s*)Goal\\s+([A-Za-z0-9_]+)\\s+([^:]+):\\s*$',
                Line, Sub, []),
    string_length(Sub.1, Indent),
    atom_string(GoalId, Sub.2),
    string_trim(Sub.3, Label).

string_trim(S0, S) :-
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
    % Locate the goal header line in the *current* line list.
    find_goal_header_line(Lines0, GoalId, Indent, Label, StartIdx),
    find_subtree_end(Lines0, Indent, StartIdx, EndIdx),
    slice_lines(Lines0, StartIdx, EndIdx, SubtreeLines),

    % Extract preview body text (Step-2 meaning) for call site.
    extract_goal_body_preview(SubtreeLines, Indent, PreviewLines0),
    trim_trailing_blank_lines(PreviewLines0, PreviewLines),

    % Replace subtree with a module invocation node (ACO v1.2 syntax).
    make_module_ref_lines(Indent, GoalId, Label, PreviewLines, RefLines),
    replace_range_with_lines(Lines0, StartIdx, EndIdx, RefLines, Lines1),

    % Emit a module unit (kept in-memory; appended to OutFile).
    module_unit_from_subtree(GoalId, Label, Indent, SubtreeLines, ModuleUnit),

    modularize_loop(Rest, GoalIndex, Lines1, LinesOut, MoreUnits).


find_goal_header_line(Lines, GoalId, Indent, Label, StartIdx) :-
    % atom_string(GoalId, GoalIdStr),
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


% ----------------------------------------------------------------------
% ACO v1.2 module invocation + module-unit emission (Jan 26 addendum)
% ----------------------------------------------------------------------

make_module_ref_lines(Indent, GoalId, Label, PreviewLines, RefLines) :-
    make_spaces(Indent, Spaces),
    goalid_to_module_callsite_id(GoalId, CallsiteId),
    module_sig_from_label(Label, ModuleSig),
    format(string(H), "~sModule ~w [~w]:", [Spaces, CallsiteId, ModuleSig]),
    % Insert a blank line after the invocation block (for readability).
    append([H|PreviewLines], [""], RefLines).


module_unit_from_subtree(_GoalId, Label, RootIndent, SubtreeLines, ModuleUnitLines) :-
    module_sig_from_label(Label, ModuleSig),
    format(string(ModHdr), "Module: ~w", [ModuleSig]),
    % Adjust indentation so the root Goal header starts at indent 2 within the module unit.
    Shift is 2 - RootIndent,
    shift_lines_indent(SubtreeLines, Shift, SubtreeShifted),
    % Module unit header at column 0, followed by a blank line.
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
    % Collapse any run of trailing "" to a single "".
    reverse(Lines0, Rev),
    drop_while_blank(Rev, RevTail),
    reverse(RevTail, Tail),
    append(Tail, [""], LinesOut).

drop_while_blank([""|Rest], Out) :- !, drop_while_blank(Rest, Out).
drop_while_blank(List, List).


% Preview body: contiguous non-header lines after the root goal header.
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


% Shift indentation by N spaces (N may be negative).
shift_lines_indent([], _N, []).
shift_lines_indent([L0|Ls0], N, [L|Ls]) :-
    shift_line_indent(L0, N, L),
    shift_lines_indent(Ls0, N, Ls).

shift_line_indent(Line0, 0, Line0) :- !.
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

remove_n_spaces(Codes, 0, Codes) :- !.
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


module_sig_from_label(Label0, ModuleSig) :-
    % Keep label as-is (no normalization) except ensure no spaces in module id.
    string_trim(Label0, Label1),
    re_replace('\s+'/g, '', Label1, LabelNoWs),
    format(atom(ModuleSig), "~w()", [LabelNoWs]).


make_spaces(N, Spaces) :-
    (   N =< 0
    ->  Spaces = ""
    ;   length(Codes, N),
        maplist(=(0' ), Codes),
        string_codes(Spaces, Codes)
    ).
