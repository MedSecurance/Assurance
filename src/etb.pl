% Evidential Tool Bus

:- module(etb, [etb/0,etb/1,etb/4,etb_server/0,etb_reset/0,etb_reset/1]).
:- use_module([
       'com/command','com/param','com/procs','com/ui'
  ]).
:- use_module(models_api/common).
:- use_module(models_api/configuration).
:- use_module(models_api/model).
:- use_module(models_api/platform).
:- use_module(models_api/policy).

:- use_module(kb).
:- use_module(patterns).
:- use_module(stringutil).

:- use_module(assurance).

:- use_module(evidence).

:- use_module(agents/axiom_agent).
:- use_module(agents/certificate_agent).
:- use_module(agents/ocra_agent).
:- use_module(agents/ichecker_agent).
% :- use_module(agent).
:- use_module(agent_interface).

:- use_module(instantiate).
:- use_module(export).
:- use_module(etb_server).

:- use_module('com/test').

:- include(etb_test).

:- style_check(-singleton).

% :- initialization(etb).
%

:- set_prolog_flag(verbose, silent).

%
% etb command line options
%
%    --command    -c     <command string>
%

etb_opt_spec([
        [opt(command), type(atom), shortflags([c]), longflags(['command']),
         help( 'command to execute when ETB starts' )],
        [opt(model), type(atom), shortflags([m]), longflags(['model']),
         help( 'load model specification when ETB starts' )],
        [opt(selftest), type(boolean), default(true), shortflags([s]), longflags(['selftest']),
         help( 'run self tests when ETB starts' )],
        [opt(verbose), type(boolean), default(true), shortflags([v]), longflags(['verbose']),
         help( 'verbose reporting' )]
]).

:- dynamic etb_options/1.
etb_options([]).


% These are the main entry points to the system
% Other special entry points may also be defined here
%
etb :- % most typical entry
	get_command_args(Argv),
	% etb(Argv,_,_,_,_), !.
        etb_with_args(Argv), !.
etb :- halt(1).

etb_with_args(Argv) :-
	format('Argv: ~q~n',[Argv]),

	% process the arguments
	etb_opt_spec(OptSpec),
	catch(
	    opt_parse(OptSpec,Argv,Opts,_Positionals),
	    E, writeln('error in command line options')),
	!,
	(   nonvar(E)
	->  halt(1)
	;   retractall(etb_options(_)), assert(etb_options(Opts))
	),
	etb_with_opts(Opts).

etb_with_opts(Opts) :-
	format('Options=~q~n',[Opts]),
	(   memberchk(command(CommandStr),Opts); true ),
	(   memberchk(model(ModelName),Opts); true ),
	(   memberchk(selftest(S),Opts); true ),
	(   memberchk(verbose(V),Opts); true ),
	(   nonvar(ModelName)
	->  model:load_model(ModelName,_M)
        ;   true
        ),
	(   var(CommandStr)
	->  etb(_,_,_,_) % go to interactive command interpreter
	;   % otherwise execute the command given in command line option
            initialize_all,
            read_term_from_atom(CommandStr, Command, []),
            format('executing command: ~w~n',Command),
            % guitracer, trace,
            command:add_commands(advanced), command:add_commands(developer), command:add_commands(etb),
            command:do( Command ) % full set of commands available
	).

% can be invoked with directives: (could do to allow a set of directives)
etb(self_test) :- !, etb(on,off,on,_).
etb(regression_test) :- !, etb(off,on,on,_).
etb(no_initial) :- !, etb(off,off,off,_).
etb(verbose) :- !, etb(_,_,_,on).

etb(Selftest,Regression,Init,Verbose) :-
	(   var(Selftest) -> param:self_test(Selftest) ; true ),
	(   var(Regression) -> param:regression_test(Regression) ; true),
	(   var(Init) -> param:initialize(Init) ; true ),
	(   var(Verbose) -> param:verbose(Verbose) ; true ),

	(   Verbose == on
	->  param:command_mode(CMode), param:user_level(UL), param:etb_mode(EMode),
		format('command_mode=~a user_level=~a etb_mode=~a~n', [CMode,UL,EMode]),
		format('self_test=~a regression_test=~a initialize=~a verbose=~a~n',
		  [Selftest,Regression,Init,Verbose])
	; true),

	(   Init == on
	-> initialize_all
	; true ),

	(   Selftest == on
	->  self_test_all
	;   true ),

	(   Regression == on
	->  regression_test_all
	;   true ),

	(   param:guitracer(on)
	->  guitracer
	;   true ),

	param:prompt_string(etb,Prompt), param:setparam(prompt_string,Prompt),
	command:tl(etb). % run the top-level etb command interpreter

etb_server :-
	get_command_args(Argv),
	initialize_all,
	etb_server:etb_server_with_args(Argv).

get_command_args(Argv) :-
	current_prolog_flag(argv, Argv),
	true.

%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%
%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%

% Initialization
%
initialize_once :- param:initialized(true), !.
initialize_once :-
	open_null_stream(Null), param:setparam(null_stream,Null),
	true.

initialize_all :-
	% initialize all subsystems and modules requiring startup initialization
	% ui:notify(initialize,all),
        initialize_once,
        
	% individual module initializations, e.g.: kb:init(full), % basic or full
        patterns:init,

	attach_evidence_repository,

	param:setparam(initialized,true).

etb_reset :- % TODO currently not resulting in a complete reset, use make clean
        shell('make clean'), % just use makefile unless it becomes a problem
	% etb_reset(repos),
	% etb_reset(cap),
	true.

etb_reset(cap) :- !,
	reset_CAP.

etb_reset(repos) :- !,
	reset_assurance_repository,
	reset_evidence_repository,
	true.

etb_reset(all) :- !,
	etb_reset,
	% everything etb_reset does, plus the following:
	% reset_CAP,
	% reset_parameters,
	true.

% Test
%
self_test_all :-
	test:self_test,
	true.

regression_test_all :-
	test:regression_test,
	true.
