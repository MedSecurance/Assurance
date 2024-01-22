% Evidential Tool Bus

:- module(etb, [etb/0,etb/1,etb/4,etb_server/0,etb_reset/0]).
:- use_module([
       'com/param','com/command','com/test','com/procs'
  ]).
:- use_module(models_api/common).
:- use_module(models_api/platform).
:- use_module(models_api/policy).
:- use_module(models_api/configuration).
:- use_module(models_api/model).

:- use_module('../KB/PATTERNS/patterns').
:- use_module(assurance).
:- use_module(evidence).

:- use_module(agents/axiom_agent).
:- use_module(agents/certificate_agent).
:- use_module(agents/ocra_agent).
:- use_module(agents/ichecker_agent).
:- use_module(agent).

:- use_module(instantiate).
:- use_module(export).

:- style_check(-singleton).

% :- initialization(etb).
%

:- set_prolog_flag(verbose, silent).

% These are the main entry points to the system
% Other special entry points may also be defined here
%
etb :- % most typical entry
	get_command_args(_Argv),
	etb(_,_,_,_), !.
etb :- halt(1).

% can be invoked with directives: (could ddo to allow a set of directives)
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
	server:server_with_args(Argv).

get_command_args(Argv) :-
	current_prolog_flag(argv, Argv),
	% format('Argv: ~q~n',[Argv]),
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

	% e.g.: kb:init(full), % basic or full
	attach_evidence_repository,

	param:setparam(initialized,true).

etb_reset :-
	etb_reset(repos),
	reset_CAP,
	true.

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
