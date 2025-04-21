% COMMAND INTERPRETER USER INTERFACE
% and definition of the interactive commands

:- module(command, [ tl/0, tl/1 ]).

:- use_module(param).
:- use_module(ui).
:- use_module('../assurance').
:- use_module(procs).

%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%
% ETB, AC and EV tool modes of operation and available commands
%
% Mode of operation and available commands determined by several factors:
%
% Mode - argument given when the command interpreter is invoked
%
% Available commands are based on the default user level defined in param.
%
% CommandSet:
%  'etb' for commands in general etb user mode
%  'kb' for commands in knowledge base user mode
%  'general' for commands that may be used in any user mode
%  'advanced' commands
%  'developer' for commands such as inspect,regtest,reinit
%  'obsolete' for commands that are no longer used and may not work
%
% Each command is declared to be associated with a single command set.
% Generally, more priveleged command sets include lesser privileged
% commands.
%
% available_commands/1 is a list of the currently available command sets
% See end of this file for manipulation of available_commands.
%
% The command interpreter currently has ETB and AC modes:
% ETB mode: etb, general, advanced & developer commands
% KB mode: kb, general, advanced & developer commands
%
%   general commands are available in every mode to all user levels
%   advanced and developer commands can be added
%   obsolete commands should not appear in available_commands
%
%	There are commands to explicitly change command sets, e.g. “advanced”.
%
% How available commands are determined:
%   The top level command interpreter tl/1 is invoked with a mode
%   of 'etb' or 'kb'. Invoking tl/0 causes tl(etb) to be invoked.
%
%  UserMode in the command syntax table
%  user_mode/1 dynamic fact - initialized to param:user_level in tl/1
%    values are: etb, kb
%  Mode argument passed to tl/1 - etb or kb
%
%

%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%
% Command declarations
%
% Commands associated with a specific tool/mode of operation may be
% declared in separate files and included below.
% E.g., see ETB tool and KB command set declaration includes.
% General commands are declared in this file.
%
% Command declarations have a common approach to syntax, argument
% semantics, help and operational semantics.
%
% syntax( Signature, CommandSet ).
%
% semantics( ParametrizedSignature ) :- <parameter check goals>.
%
% help( CommandName, HelpText ).
%
% do(PSignature) :- <command goals>.
%
% There must be a syntax entry for every command form. Constraint:
% do not create a 0-ary command with the name "invalid" (see rd/2).
% 0-ary commands should not have a semantics entry.
%
% Commands are listed alphabetically in syntax/2, semantics/1, help/2
% and do/1.
% These declarations may also be made in separate files and included.
% Hence the predicates syntac, semantics, help and do are discontiguous.
% Such files should also contain a commands_defined/1 fact for the
% command mode(s) being defined by the file.
% The predicate defined_commands/1 returns all currently defined
% command sets and modes.

:- discontiguous syntax/2, semantics/1, help/2, do/1, commands_defined/1.

:- if( exists_file('command_etb.pl') ).
:- include('command_etb.pl').
commands_defined(etb).
:- endif.

:- if( exists_file('command_kb.pl') ).
:- include('command_kb.pl').
commands_defined(kb).
:- endif.

:- if( exists_file('command_repo.pl') ).
:- include('command_repo.pl').
commands_defined(repo).
:- endif.

commands_defined(basic).
commands_defined(advanced).
commands_defined(developer).

defined_commands(CmdSets) :- findall(CmdSet, commands_defined(CmdSet), CmdSets).
% e.g.: defined_commands([etb,kb,basic,advanced,developer]).

%
syntax(advanced,                        basic).
syntax(basic,				basic).
syntax(demo(demo_command),              basic).
syntax(developer,                       basic).
syntax(echo(string),                    basic).
syntax(guitracer,						                                developer).
syntax(guiserver,			                                            developer).
syntax(halt,                            basic).
syntax(help,                            basic).
syntax(help(command),			basic).
syntax(import_model(model),             basic).
syntax(inspect,                                                         developer).
syntax(inspect(item),                                                   developer).
syntax(load_procs(file),                basic).
syntax(make,                                                            developer).
syntax(noop,				basic).
syntax(nl,                              basic).
syntax(proc(proc_id),                   basic).
syntax(proc(proc_id,step_or_verbose),	basic).
syntax(quit,                            basic).
syntax(regtest,								developer).
syntax(reset,					                      advanced).
syntax(reset(domain),					              advanced).
%syntax(reset(domain,name),				              advanced).
syntax(reinit,                                                          developer).
syntax(script(file),                    basic).
syntax(script(file,step_or_verbose),	basic).
syntax(selftest,					                  advanced).
syntax(set,						                      advanced).
syntax(set(name),				                      advanced).
syntax(set(name,value),				                  advanced).
syntax(set_v(var,expr),					     basic).
syntax(show_proc(proc_id),              basic).
%syntax(show_proc(proc_id,mode),              basic).
syntax(show_procs,                      basic).
%syntax(show_procs(mode),                      basic).
syntax(status,				basic).
syntax(step,								                            developer).
syntax(step(number_of_steps),				                         	developer).
syntax(time(command),                                 advanced).
syntax(time(command,repeat),			              advanced).
syntax(traceoff,					                                    developer).
syntax(traceon,					                                        developer).
syntax(traceone,					                                    developer).
syntax(version,				            basic).
syntax(versions,				        basic).

%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%
% ETB tool command semantics
%
% optional static semantics entry, e.g., used to check command arguments
% no entry needed for commands not taking arguments
% distinct from syntax so syntax can be checked separately
semantics(demo(C)) :- !, ground(C).
semantics(echo(S)) :- !, ground(S).
semantics(help(C)) :- !, ground(C).
semantics(import_model(M)) :- atom(M).
semantics(inspect(I)) :- nonvar(I).
semantics(load_procs(F)) :- !, atom(F).
semantics(proc(P)) :- !, atom(P).
semantics(proc(P,Opt)) :- !, atom(P), atom(Opt),
	member(Opt,[step,s,verbose,v]). % other opts can be added
semantics(reset(Dom)) :- !, atom(Dom).
%semantics(reset(Dom,Name)) :- !, atom(Dom), atom(Name).
semantics(script(F)) :- !, atom(F).
semantics(script(F,Opt)) :- !, atom(F), atom(Opt),
	member(Opt,[step,s,verbose,v]). % other opts can be added
semantics(set(N)) :- !, atom(N).
semantics(set(N,V)) :- !, atom(N), ground(V).
semantics(set_v(V,E)) :- !, ground(E), var(V).
semantics(show_proc(P)) :- !, atom(P).
%semantics(show_proc(P,M)) :- !, atom(P), atom(M), member(M,[pp]).
%semantics(show_procs(M)) :- !, atom(M), member(M,[pp]).
semantics(step(N)) :- !, (integer(N) ; N == break), !.
semantics(time(C)) :- !, ground(C).
semantics(time(C,N)) :- !, ground(C), integer(N).
semantics(_). % succeed for all other commands

%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%
% command help strings
%   all strings for a given key are displayed when key is given as an
%   argument to the help command, e.g., "help(assess)"
%
%   help(Key,    HelpString)
help(advanced,  'Switch to advanced user level, enabling all commands.').

help(basic,     'Switch to basic user level, limiting available commands to basic command set.').

help(demo,	'Run canned demos.'). % command for running canned demos of different features
help(demo,      'Arg is demo identifier.').

help(echo,      'echo a (single-quoted) string argument.').

help(halt,	'Leave command loop and halt Prolog.').

help(help,	'"help" with no argument lists the legal command forms.').
help(help,	'With a command name as argument it provides help on that command.').

help(inspect,	'Inspect values of internal structures or variables based on arg.').
help(inspect,	'arg options: settings, xml, str, current or other structures.').
help(inspect,	'arg: target(<target>,<element>) will show intermediate facts.').

help(load_procs,'Load proc definitions from a named file.').
help(load_procs,'Arg is the procs file name.').

help(make,	'Recompile changed source files.').

help(nl,     'Write a newline to the console.').

help(proc,	'Run a predefined command procedure.').
help(proc,	'Arg 1 is a procedure identifier.').
help(proc,   'Arg 2 (optional) is "step" or "verbose".').

help(quit,	'Quit top-level command loop or a command script; stay in Prolog.').

help(regtest, 'Run regression tests.').

help(reinit,	'Re-initialize.').

help(reset,  	'Reset databases.').
help(reset,	'Arg 1 is the domain to be reset.').
%help(reset,  	'Arg 2 is the name of the group to be reset.').

help(script,	'Run a command script from a named file.').
help(script,	'Arg 1 is the file name.').
help(script,	'Arg 2 (optional) is "step" or "verbose".').

help(selftest,  'Run self tests.').

help(set,	'With no argument displays all settable parameters.').
help(set,	'Arg 1 is name of a paramater. If only one arg, display its value.').
help(set,	'Arg 2, if present, is the value to set.').
help(set, 'Settable: cache, debug, initialize, statusprt, self_test, regression_test, verbose.').

help(set_v, 'Set variable to expression.').
help(set_v, 'Arg 1 is a logical variable.').
help(set_v, 'Arg 2 is a ground expression.').

help(show_proc, 'Show a predefined command procedure.').
help(show_proc, 'Arg1 is the id of the procedure.').
%help(show_proc, 'Arg2 (opt) is the mode (pp).').
help(show_procs, 'Show all of the predefined command procedures.').
%help(show_procs, 'Arg1 (opt) is the mode (pp).').

help(status,	'Display system status.').

help(step,	'"step" with no argument steps engine one cycle.').
help(step,	'With an integer argument it steps the engine that number of cycles.').

help(time,	'Execute command and report time stats.').
help(time,	'With an integer second argument, execute command repeatedly and report total time stats.').

help(traceoff,  'Turn Prolog tracing off.').
help(traceon,   'Turn Prolog tracing on.').
help(traceone,	'Turn Prolog tracing on for one command (next).').

help(version,	'Show current version number.').
help(versions,	'Show past versions with descriptions and current version.').

%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%
% do the command, should be one for every implemented valid command form
% known broken or unimplemented commands should just "fail." straightaway
% interactive_do provides an appropriate message for interactive use of
% a command that is known to be invalid because it fails syntax or
% semantics check, does not have a do entry, or fails in do.
% (Would be better to distinguish between unimplemented and failed do,
% which is what the fail_act in tl is for.)
% As it is now, commands with an entry in do that fail are reported
% in the interactive_do as unimplemented commands.
%
do(advanced) :- !, do(level(advanced)).
do(basic) :- !, do(level(basic)).

do(demo(C)) :- !, perform_demo(C).
do(developer) :- !, do(level(developer)).
do(echo(S)) :- !, 
	( ground(S) -> writeq(S), nl ; writeln('non-ground arg')).
do(guitracer) :- !,
	(   param:guitracer(off)
	->  setparam(guitracer,on),
	    guitracer
	;   true).
do(guiserver) :- !,
	(   param:guiserver(off)
	->  do(set(guiserver,on)),
	    do(guitracer),
	    do(set(jsonresp_server,on)), % turns on JSON responses for APIs
	    do(set(jsonresp,on)),
	    do(set(sleep_after_server_start,off)),
	    % do(traceone),
       param:server_port(Port),
	    do(server(Port)),
	    do(echo(ready))
	;   do(echo('already on'))
	).

do(help) :- !, help_commands.
do(help(C)) :- !, show_help(C).

do(inspect) :- !, writeln('inspect(opt). options: settings').
do(inspect(Item)) :- !, inspect(Item).

do(level(L)) :- !, retractall(user_lev(_)), assert(user_lev(L)),
	user_mode(M), level_commands(L,LCs), union([M],LCs,Cmds), set_avail_commands(Cmds).

do(load_procs(F)) :- !, procs:load_procs(F).

do(make) :- !, make.
do(noop) :- !.
do(nl) :- nl.

do(proc(Pid)) :- !, do(proc(Pid,none)).
do(proc(Pid,Opt)) :- !, procs:proc(Pid,Proc), user_mode(M),
	retractall(interactive(_)), assert(interactive(false)),
	run_commands(M,Proc,Opt),
	retractall(interactive(_)), assert(interactive(true)).
do(quit) :- !.
do(halt) :- !, halt.
do(regtest) :- !, user_mode(M), M:regression_test_all.
do(reinit) :- !, writeln('No top-level reinit currently').
do(reset) :- !, etb_reset.
do(reset(D)) :- !, etb_reset(D).
do(script(F)) :- !, user_mode(M), run_command_script(M,F,none).
do(script(F,Opt)) :- !, param:prompt_string(P), run_command_script(P,F,Opt).
do(selftest) :- !, user_mode(M), M:self_test_all, /* others ... */ true.
do(set) :- !, param:settable_params(Ps), forall(member(P,Ps),do(set(P))). % display all settable params
do(set(P)) :- param:settable_params(Ps), member(P,Ps), !, % display a settable param
	Q =.. [P,V], call(param:Q), format('~a=~w~n',[P,V]).
do(set(_)) :- !, writeln('Unknown parameter name').
do(set(debug,V)) :- (V == on ; V == off), !, do(debug(V)).
do(set(statusprt,V)) :- (V == on ; V == off), !, do(statusprt(V)).
do(set(self_test,V)) :- (V == on ; V == off), !, do(self_test(V)).
do(set(P,V)) :- param:settable_params(Ps), member(P,Ps), !, param:setparam(P,V).

do(set_v(V,E)) :- !, V = E.

do(set(initialize,V)) :- (V == on ; V == off), !, param:setparam(initialize,V).
do(set(regression_test,V)) :- (V == on ; V == off), !, param:setparam(regression_test,V).
do(set(verbose,V)) :- (V == on ; V == off), !, param:setparam(verbose,V).

% add cases for other parameter settings here
do(set(P,V)) :- atom(P), ground(V), param:setparam(P,V), !.
do(set(_,_)) :- !,
	writeln('Unknown parameter name or illegal parameter value').
do(show_proc(P)) :- !, listing(proc(P,_)).
do(show_procs) :- !, listing(procs:proc/2).
do(status) :- user_mode(M), param:name_string(M,N), user_lev(L),
	write(' '), writeln(N),
	write('   Command Mode: '), writeln(M),
	write('   Command Level: '), writeln(L),
	available_commands(Cmds), write('   Command sets: '), writeln(Cmds),
	assurance:ar_write_status,
	evidence:er_write_status.
do(time(Command)) :- !, time(do(Command)).
do(time(Command,N)) :- !,
	current_output(S), param:null_stream(Null), set_output(Null),
	time( (foreach(between(1,N,_), do(Command)), set_output(S)) ).
do(traceon) :-	retractall(tracing(_)), assert(tracing(on)), trace.
do(traceone) :-	retractall(tracing(_)), assert(tracing(set)).
do(traceoff) :- retractall(tracing(_)), assert(tracing(off)), notrace.

do(version) :- !, param:prompt_string(Mode),
	param:build_version(Mode,Cur), param:build_current_version_description(Mode,Desc),
	format('Current version: ~a: ~a~n',[Cur,Desc]).
do(versions) :- !, param:prompt_string(Mode),
	forall(param:build_version(Mode,V,D), format('~t~17|~a: ~a~n',[V,D])),
	do(version).

%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%
:- dynamic tracing/1, user_mode/1, user_lev/1, interactive/1, tl_initialized/1.

% tracing
% values: on, off, set, and one
%         set changes to one in mid next iteration
%         one changes to off after the next command is run
tracing(off).

% user_mode
user_mode(M) :- !, param:command_mode(M). % use default from parameter

% user_lev
user_lev(L) :- !, param:user_level(L). % default from parameter

% interactive
% true when reading from user interaction
interactive(true).

% top level initialized true | false
tl_initialized(false).

%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%
% top-level command loop
%
% tl(Mode)
%

tl :- param:command_mode(M), tl(M).

tl(_) :- tl_initialized(true), !, tl_loop.
tl(Mode) :-
	param:user_level(Ulev), % user_level param overides user_mode default
	retractall(user_lev(_)), assert(user_lev(Ulev)),
	add_commands(Ulev), % basic / advanced / developer
	(   Ulev == developer -> add_commands(advanced) ; true),
	retractall(user_mode(_)), assert(user_mode(Mode)),
	add_commands(Mode),
	banner(Mode),
	retractall(tl_initialized(_)), assert(tl_initialized(true)),
	tl_loop.

tl_loop :-
	repeat,
	    user_mode(Mode),
		param:prompt_string(Mode,Prompt),
	        pre_act, rd(Prompt,C), mid_act(C),
		(   interactive_do(Mode,C)
		->  true
		;   fail_act
		),
		post_act,
	(C == quit, ! ; fail).


banner(Mode) :-
	param:build_version(Mode,V), param:name_string(Mode,Name),
	format('~n~a version ~a~n',[Name,V]),
	nl.

pre_act :- % do before reading the command
	true.
mid_act(_) :- % do after reading the command but before do-ing it
	(   tracing(set)
	->  retractall(tracing(_)),
	    assert(tracing(one)),
	    trace
	;   true
	).
post_act :- % do after performing the command or after fail_act
	(   tracing(one)
	->  retractall(tracing(_)),
	    assert(tracing(off)),
	    notrace
	;   true
	),
	(param:statusprt(on) -> do(status);true),
	nl, !.
fail_act :- % do when a command fails
	(   tracing(one)
	->  retractall(tracing(_)),
	    assert(tracing(off)),
	    notrace
	;   true
	),
	param:msg_failed_command(M),
	ui:notify('interactive',M).

interactive_do(_,invalid) :- !, unimplemented_command.
interactive_do(CS,C) :- param:prompt_string(CS), !, do(C).
interactive_do(CS,C) :-	 atom(CS), DO =.. [CS,C], !, call(CS:DO).
interactive_do(_,_) :- unimplemented_command.

unimplemented_command :- param:msg_unimplemented_command(M), writeln(M).

%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%
% read and validate a command:
% execute a Prolog goal preceded by :- or ?-
% or check whether a valid NGAC command
% return invalid if not found or fails checks
%
rd(Prompt,C) :-
	atom_concat(Prompt,'> ',FullPrompt),
        % use read_term_with_history for newer SWI version
	read_history(h, '!h', [], FullPrompt, C, _Bindings),
        % read_term_with_history(C, [prompt(FullPrompt)]),
	nonvar(C), % nonvar instead of ground to allow Prolog goals w/vars
	(   (C=..[:-,P];C=..[?-,P]) % command is a Prolog goal
	->  call(P), nl, !, fail    % bypass other goals in tl, repeat
	;   chk_command(C)          % check the command, fail to 'invalid'
	), !.
rd(_,invalid).

%chk_command(CommandSet,C) :-
%	param:prompt_string(Prompt),
%	(   CommandSet == Prompt
%	->  syntax_chk(C),
%	    semantics(C)
%	;   Check =.. [cmd,C,_,_],
%	    clause(CommandSet:Check,true)
%	).
chk_command(C) :-
	available_commands(CommandSets),
	syntax_chk(C,CommandSets),
	semantics(C).

%syntax_chk(C) :-
%	functor(C,F,A), functor(Sig,F,A), user_lev(M),
%	(   M == advanced
%	->  syntax(Sig,_)
%	;   syntax(Sig,M)
%	).
syntax_chk(C,CSets) :-
	functor(C,F,A), functor(Sig,F,A),
	syntax(Sig,CSet),
	memberchk(CSet,CSets).

%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%
% command scripts
%
/* previous version doesn't work with scripts with variables
run_command_script(Mode,F,Opt) :-
	(   access_file(F,read)
	->  (
	        read_file_to_terms(F,Commands,[]),
	        (   Opt == verbose
	        ->  param:verbose(SaveVerboseParam), param:setparam(verbose, on),
		    param:msg_script_read(Mread), writeln(Mread),
		    ui:display_list(Commands,1),
	            param:msg_running_script(Mrun), writeln(Mrun)
	        ;   true
	        ),
	        run_commands(Mode,Commands,Opt)
	    )
	;
	    format('can''t find file "~a"~n', F)
	), !.
*/

run_command_script(Mode,F,Opt) :-
	(   access_file(F,read)
	->  (
	        read_file_to_terms(F,Terms,[]),
		run_script(Mode,Terms,Opt)
	    )
	;
	    format('can''t find file "~a"~n', F)
	), !.

run_script(Mode,[script(Commands)],Opt) :- !, run_script2(Mode,Commands,Opt).
run_script(Mode,[Commands],Opt) :- is_list(Commands), !, run_script2(Mode,Commands,Opt).
run_script(_,_,_) :- writeln('bad script file format').

run_script2(Mode,Commands,Opt) :-
	param:verbose(SaveVerboseParam),
	(	Opt == verbose
	->	param:setparam(verbose, on),
		param:msg_script_read(Mread), writeln(Mread),
		ui:display_list(Commands,1),
	        param:msg_running_script(Mrun), writeln(Mrun)
	;	param:setparam(verbose, off)
	),
	run_commands(Mode,Commands,Opt),
	param:setparam(verbose,SaveVerboseParam).

run_commands(_,[],_) :- !.
run_commands(Mode,[C|Cs],Opt) :-
	(
	    (	(Opt == step ; Opt == s)
	    ->	format('~n> ~q. ?', C), flush_output, readln(_)
	    ;	(Opt == verbose ; Opt == v)
	    ->	format('> ~q.~n', C)
	    ;	true
	    ),
	    (   (C=..[:-,P] ; C=..[?-,P]) % command is a Prolog goal
	    ->  call(P)
	    ;   % ground(C),
	        chk_command(C),          % check the command, fail to 'invalid'
		(   user_mode(Mode)
		->  do(C)
		;   atom(Mode), DO =.. [Mode,C], call(Mode:DO)
		)
	    )
	    ;   format('~q : ',[C]),
		param:msg_failed_command(CM), writeln(CM),
		param:msg_script_aborted(SM), writeln(SM),
		Abort=true
	),
	((C == quit; Abort == true), ! ; run_commands(Mode,Cs,Opt)).


%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%
% Available commands
%
% Command sets and categories
%  'basic' for commands that may be used in any user mode
%  'advanced' commands
%  'developer' for commands such as inspect,regtest,reinit
%  'obsolete' for commands that are no longer used and may not work
% Modular command sets brought in using ':-include'
%  'etb' for commands in etb user mode
%  'kb' for commands in knowledge base user mode

% Each command is declared to be associated with a single command set.
%
% available_commands/1 is a list of the currently available command sets
%  This is initialized when the top level loop tl/1 is started.
%
%  Values of available_commands will be, e.g.:
%    [etb,basic] [etb,basic,advanced] [etb,basic,advanced,developer]
%    [kb,basic]  [kb,basic,advanced]  [kb,basic,advanced,developer]
%    [etb,kb,basic,advanced,developer]

:- dynamic avail_commands/1.
avail_commands([basic]). % always start with the basic commands

available_commands(AvailCmds) :- avail_commands(AvailCmds).
%	user_lev(L), user_mode(M),
%	level_commands(L,LCs),
%	append([[M],LCs],Cmds),
%	avail_commands(Avail), Avail = AvailCmds.
%	(   subset(Avail,Cmds)
%	->  AvailCmds = Avail
%	;   AvailCmds = Cmds
%	).

level_commands(basic,[basic]).
level_commands(advanced,[basic,advanced]).
level_commands(developer,Dcmds) :- defined_commands(Dcmds).

set_avail_commands(Cs) :- is_list(Cs), defined_commands(Defined),
	subset(Cs,Defined), !,
	retractall(avail_commands(_)), assert(avail_commands(Cs)).
%set_avail_commands(_).

add_commands([]) :- !.
add_commands([C|Cs]) :- !, add_commands(C), add_commands(Cs).
add_commands(ToBeAdded) :- atom(ToBeAdded),
	defined_commands(Defined), memberchk(ToBeAdded, Defined), !,
	avail_commands(Av),
	(   \+ memberchk(ToBeAdded,Av)
	->  set_avail_commands([ToBeAdded|Av])
	;   true
	).
add_commands(_).

rem_commands([]) :- !.
rem_commands([C|Cs]) :- !, rem_commands(C), rem_commands(Cs).
rem_commands(ToBeRemoved) :- atom(ToBeRemoved),
	defined_commands(Defined), memberchk(ToBeRemoved, Defined), !,
	avail_commands(Av),
	(   memberchk(ToBeRemoved,Av)
	->  subtract(Av, [ToBeRemoved], NewAv),
	    set_avail_commands(NewAv)
	;   true
	).
rem_commands(_).
%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%
% command procedures
%   command procedures are support for 'do' entries for a command that
%   permit the 'do' entry to remain relatively short. Many commands
%   invoke detailed procedures in other modules. Command procedures lie
%   in between the 'do' entry for the implementation of the command and
%   the detailed core support from another appropriate module.
%
%   command procedures for miscellaneous commands, in some cases
%   procedures here may be temporary until they are moved to an
%   appropriate module
%

help_commands :-
	available_commands(CSs),
	findall(Sig, (syntax(Sig,CS), memberchk(CS,CSs)), Sigs),
	predsort(comp_name,Sigs,SSigs),
	writeln('<command> ::='),
	forall(member(Sig,SSigs), (write('  '), write(Sig), nl)), !.

comp_name('<',A,B) :- functor(A,Af,_), functor(B,Bf,_), Af @=< Bf.
comp_name('>',A,B) :- functor(A,Af,_), functor(B,Bf,_), Af @> Bf.

show_help(Cname) :-
	syntax(Sig,obsolete), functor(Sig,Cname,_),
	write('  '), write(Sig), writeln(' - OBSOLETE'),
	show_help_strings(Cname), !.
show_help(Cname) :-
	available_commands(CSs),
	findall(Sig, (syntax(Sig,CS), functor(Sig,Cname,_),memberchk(CS,CSs)), Sigs),
	forall(member(Sig,Sigs), (write('  '), writeln(Sig))),
	( Sigs \== [] -> show_help_strings(Cname) ; true).

%show_help(C) :-
%	C =.. [Command|_], % use only the command name, ignore args
%	(   help(Command,_)
%	->  nl, show_help_strings(Command),
%	    (	( syntax(S,obsolete), S =.. [Command|_] )
%	    ->	writeln('  OBSOLETE')
%	    ;	true
%	    )
%	;   format('No help for command "~q"~n', Command)
%	).

show_help_strings(Command) :-
	help(Command,HelpString), format('    ~a~n',HelpString), fail.
show_help_strings(_).

% inspection - for development and test
inspect(settings) :- !, do(set).
% add other inspect clauses here
%% e.g.: inspect(graph) :- !, graphmanager:getGraph(G),graphmanager:printGraph(G).
inspect(_) :- writeln('inspect: Unknown parameter name or illegal parameter value').

%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%
% demos
%   to show-off implemented portions of functionality
%   insert perform_demo clauses for specific arguments following comment

perform_demo(X) :- unimpl_d(X).

unimpl_d(X) :- format('Unimplemented demo command: ~q~n',[X]).
