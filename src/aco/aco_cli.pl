:- module(aco_cli, [main/0, main1/1, dispatch/2]).

:- use_module(library(readutil)).

:- use_module(aco_processor).
:- use_module(aco_ascii_tree).
:- use_module(aco_apl).

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
    % Parse flags and file
    parse_tree_args(Args, File, ModeTag, AliasesFlag),
    % Map CLI "verbosity" names to ascii-tree modes
    mode_tag_to_ascii_mode(ModeTag, TreeMode),
    alias_flag(AliasesFlag, AliasOpt),
    strip_cr_atom(File,CleanFile),
    read_file_to_string(CleanFile, Raw, [newline(detect)]),
    Options = [mode(TreeMode), AliasOpt],
    aco_ascii_tree_from_string(CleanFile, Raw, Tree, Options),
    format("~s~n", [Tree]).

dispatch(canon, [In, Out]) :-
    !,
    strip_cr_atom(Out,CleanOut),
    canonicalize_aco_file(In, CleanOut).

dispatch(apl, [In, Out]) :-
    !,
    strip_cr_atom(Out,CleanOut),
    aco_file_to_apl_file(In,CleanOut).

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

dispatch(_, _) :-
    usage.

usage :-
    format("Usage:~n", []),
    format("  aco tree [--verbosity N | --full | --structure | --skeleton] [--no-aliases] FILE~n", []),
    format("  aco canon IN_OUTLINE OUT_CANONICAL~n", []),
    format("  aco apl   IN_OUTLINE OUT_APL_PL~n", []),
    format("  aco aplc  IN_OUTLINE OUT_APL_PL~n", []),
    format("  aco stats IN_OUTLINE~n", []),
    halt(1).

% ----------------------------------------------------------------------
% Tree subcommand: argument parsing
% ----------------------------------------------------------------------
%
% parse_tree_args(+Argv, -File, -ModeTag, -Aliases)
%
% ModeTag ∈ {full, structure, skeleton, verbosity N}
% Aliases ∈ {on, off}
% Verbosity : 0 (skeleton), 1 (structure), 2 (full)
%
% Defaults if not specified:
%   Verbosity = 2 (full)
%   Aliases   = on
%
% Accepted flags:
%   --verbosity N      (N ∈ {0,1,2})
%   --full             (Verbosity = 2)
%   --structure        (Verbosity = 1)
%   --skeleton         (Verbosity = 0)
%   --aliases          (Aliases = on)
%   --no-aliases       (Aliases = off)
% ----------------------------------------------------------------------

parse_tree_args(Argv, File, ModeTag, Aliases) :-
    DefaultMode    = full, % verbosity = 2
    DefaultAliases = on,
    parse_tree_args(Argv,
                    none,           % FileAcc
                    DefaultMode,    % ModeAcc
                    DefaultAliases, % AliasAcc
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
    ;   % positional: file
        ( FileAcc0 == none
        -> FileAcc1  = Arg,
           ModeAcc1  = ModeAcc0,
           AliasAcc1 = AliasAcc0
        ;  throw(error(usage(extra_positional_arg(Arg)), _))
        )
    ),
    parse_tree_args(Rest,
                    FileAcc1, ModeAcc1, AliasAcc1,
                    File, Mode, Alias).

% Recognised flags
%   --full / --structure / --skeleton
%   --aliases / --no-aliases

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

% Any atom starting with "-" looks flag-like
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

% Map CLI mode tags to ascii-tree "mode/1" options:
%   full      -> full body
%   structure -> headers_only (body suppressed)
%   skeleton  -> no_body      (no body at all)

mode_tag_to_ascii_mode(full,      full).
mode_tag_to_ascii_mode(structure, headers_only).
mode_tag_to_ascii_mode(skeleton,  no_body).

alias_flag(on,  aliases(on)).
alias_flag(off, aliases(off)).

% Reuse the aco_processor messages printer not system print_message
% print_messages(Messages) :-
%    maplist(print_message(informational), Messages).

% utility strip CR
strip_cr_atom(AtomIn, AtomOut) :-
    % Convert the atom to a list of character codes
    atom_codes(AtomIn, CodesIn),
    % Remove the trailing CR/LF sequence if present
    strip_cr_codes(CodesIn, CodesOut),
    % Convert the resulting codes back to an atom
    atom_codes(AtomOut, CodesOut).

strip_cr_codes(Codes, Stripped) :-
    % Check for the specific sequence [..., 13, 10] (CRLF)
    append(Stripped, [13, 10], Codes), !.
strip_cr_codes(Codes, Stripped) :-
    % Check for a single trailing [..., 13] (CR)
    append(Stripped, [13], Codes), !.
strip_cr_codes(Codes, Codes) :-
    % No trailing CR or CRLF found, return original codes
    !.

