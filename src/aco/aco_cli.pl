:- module(aco_cli, [main/0, main1/1, dispatch/2]).

:- use_module(library(readutil)).

:- use_module(aco_processor).
:- use_module(aco_ascii_tree).
:- use_module(aco_apl).
:- use_module(aco_actions).
:- use_module(aco_transforms).

main :-
    current_prolog_flag(argv, Argv),
    main1(Argv).

main1(Argv) :-
    (   Argv = []
    ->  usage
    ;   Argv = [Cmd|Rest],
        dispatch(Cmd, Rest)
    ),
    halt.

% ----------------------------------------------------------------------
% Command dispatch
% ----------------------------------------------------------------------

dispatch(tree, Args) :-
    !,
    parse_tree_args(Args, File, ModeTag, AliasesFlag),
    mode_tag_to_ascii_mode(ModeTag, TreeMode),
    alias_flag(AliasesFlag, AliasOpt),
    strip_cr_atom(File,CleanFile),
    read_file_to_string(CleanFile, Raw, [newline(detect)]),
    Options = [mode(TreeMode), AliasOpt],
    aco_ascii_tree_from_string(CleanFile, Raw, Tree, Options),
    format("~s~n", [Tree]), !.

dispatch(canon, [In, Out]) :-
    !,
    strip_cr_atom(Out,CleanOut),
    canonicalize_aco_file(In, CleanOut).

dispatch(apl, [In, Out]) :-
    !,
    strip_cr_atom(Out,CleanOut),
    aco_file_to_apl_file(In,CleanOut), !.

dispatch(aplc, [In, Out]) :-
    !,
    strip_cr_atom(Out,CleanOut),
    aco_file_to_apl_file_canon(In,CleanOut).

dispatch(stats, [In]) :-
    !,
    strip_cr_atom(In, CleanIn),
    read_file_to_string(CleanIn, Raw, [newline(detect)]),
    aco_processor:translate_aco_string(CleanIn, Raw, _Terms, Messages),
    print_messages(Messages).

dispatch(t1_observe, [In]) :-
    !,
    aco_transforms:t1_observe_file(In, Cands),
    forall(member(C, Cands), (write_term(C, [quoted(true)]), nl)).

dispatch(t1_slim, [TargetAtom, In, Out]) :-
    !,
    term_string(Target0, TargetAtom),
    aco_transforms:t1_slim_evidence_file(Target0, In, Out).

dispatch(t2_observe, [In]) :-
    !,
    aco_transforms:t2_observe_file(In, Cands),
    forall(member(C, Cands), (write_term(C, [quoted(true)]), nl)).

dispatch(t2_insert, [TargetAtom, In, Out]) :-
    !,
    term_string(Target0, TargetAtom),
    aco_transforms:t2_insert_goal_file(Target0, In, Out).

dispatch(t6, [GoalsAtom, In, Out]) :-
    !,
    term_string(Goals, GoalsAtom),
    aco_transforms:t6_modularize_file(Goals, In, Out).

dispatch(t7_observe, [In]) :-
    !,
    aco_transforms:t7_observe_file(In, Cands),
    forall(member(C, Cands), (write_term(C, [quoted(true)]), nl)).

dispatch(t7_insert, [TargetAtom, In, Out]) :-
    !,
    term_string(Target0, TargetAtom),
    aco_transforms:t7_insert_strategy_file(Target0, In, Out).

dispatch(_, _) :-
    usage.

usage :-
    format("Usage:~n", []),
    format("  aco tree [--verbosity N | --full | --structure | --skeleton] [--no-aliases] FILE~n", []),
    format("  aco canon IN_OUTLINE OUT_CANONICAL~n", []),
    format("  aco apl   IN_OUTLINE OUT_APL_PL~n", []),
    format("  aco aplc  IN_OUTLINE OUT_APL_PL~n", []),
    format("  aco stats IN_OUTLINE~n", []),
    format("  aco t6 GOALS_TERM IN_OUTLINE OUT_OUTLINE~n", []),
    format("  aco t1_observe IN_OUTLINE~n", []),
    format("  aco t1_slim TARGET_TERM IN_OUTLINE OUT_OUTLINE~n", []),
    format("  aco t2_observe IN_OUTLINE~n", []),
    format("  aco t2_insert TARGET_TERM IN_OUTLINE OUT_OUTLINE~n", []),
    format("  aco t7_observe IN_OUTLINE~n", []),
    format("  aco t7_insert TARGET_TERM IN_OUTLINE OUT_OUTLINE~n", []),
    halt(1).
    % Note: TARGET_TERM is passed through term_string/2, so onw can write e.g. goal('G10') or evidence('E111')
    % depending on the Ti entrypoint’s normalization.


% ----------------------------------------------------------------------
% Tree subcommand: argument parsing
% ----------------------------------------------------------------------

parse_tree_args(Argv, File, ModeTag, Aliases) :-
    DefaultMode    = full,
    DefaultAliases = on,
    parse_tree_args(Argv,
                    none,
                    DefaultMode,
                    DefaultAliases,
                    File, ModeTag, Aliases),
    ( File == none ->
        throw(error(usage(missing_input_file), _))
    ; true
    ).

parse_tree_args([], FileAcc, ModeAcc, AliasAcc,
                FileAcc, ModeAcc, AliasAcc).

parse_tree_args([Arg|Rest],
                FileAcc0, ModeAcc0, AliasAcc0,
                File, Mode, Alias) :-
    (   is_tree_flag(Arg, Kind)
    ->  apply_tree_flag(Kind, ModeAcc0, AliasAcc0,
                        FileAcc0, FileAcc1, ModeAcc1, AliasAcc1)
    ;   is_flag_like(Arg)
    ->  throw(error(usage(unknown_flag(Arg)), _))
    ;   ( FileAcc0 == none
        -> FileAcc1  = Arg,
           ModeAcc1  = ModeAcc0,
           AliasAcc1 = AliasAcc0
        ;  throw(error(usage(extra_positional_arg(Arg)), _))
        )
    ),
    parse_tree_args(Rest,
                    FileAcc1, ModeAcc1, AliasAcc1,
                    File, Mode, Alias).

is_tree_flag('--full',      mode(full)).
is_tree_flag('-full',       mode(full)).
is_tree_flag('--structure', mode(structure)).
is_tree_flag('-structure',  mode(structure)).
is_tree_flag('--skeleton',  mode(skeleton)).
is_tree_flag('-skeleton',   mode(skeleton)).

is_tree_flag('--aliases',    aliases(on)).
is_tree_flag('-aliases',     aliases(on)).
is_tree_flag('--no-aliases', aliases(off)).
is_tree_flag('-no-aliases',  aliases(off)).

is_flag_like(Arg) :-
    atom(Arg),
    sub_atom(Arg, 0, 1, _, '-').

apply_tree_flag(mode(full), _Mode0, Alias0,
                File0, File0, full, Alias0).

apply_tree_flag(mode(structure), _Mode0, Alias0,
                File0, File0, structure, Alias0).

apply_tree_flag(mode(skeleton), _Mode0, Alias0,
                File0, File0, skeleton, Alias0).

apply_tree_flag(aliases(on), Mode0, _Alias0,
                File0, File0, Mode0, on).

apply_tree_flag(aliases(off), Mode0, _Alias0,
                File0, File0, Mode0, off).

mode_tag_to_ascii_mode(full,      full).
mode_tag_to_ascii_mode(structure, headers_only).
mode_tag_to_ascii_mode(skeleton,  no_body).

alias_flag(on,  aliases(on)).
alias_flag(off, aliases(off)).

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

