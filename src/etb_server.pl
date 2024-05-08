% ETB server process

:- module(etb_server, [etb_server_cmd/0, etb_server_cmd/1, etb_server_cmd/2,
	etb_server_with_args/1]).

:- use_module('com/param').
:- use_module(etb).
%:- use_module('com/jsonresp').


:- use_module(library(http/thread_httpd)).
:- use_module(library(http/http_dispatch)).

% etb-server command line options
%
%    --port    --portnumber -p    <integer>
%    --selftest -s
%    --token   -t    <etbtoken>
%    --verbose  -v
%
etb_server_opt_spec([
        [opt(portnumber), meta('RP'), type(integer), shortflags([p]), longflags(['port','portnumber']),
         help( 'server listens for API calls on port RP' )],
        [opt(selftest), type(boolean), default(false), shortflags([s]), longflags(['selftest']),
         help( 'run self tests on startup' )],
        [opt(token), meta('TOKEN'), type(atom), shortflags([t]), longflags(['token']),
         help( 'protected requests must cite TOKEN' )],
        [opt(verbose), type(boolean), default(false), shortflags([v]), longflags(['verbose']),
         help( 'show all messages' )],
	% the following are only for testing
		% [opt(awake), type(boolean), default(false), shortflags([a]), longflags(['awake','nosleep']),
		%  help( 'stay awake in top-level loop after starting server' )],
		[opt(guitracer), type(boolean), default(false), shortflags([g]), longflags(['guitracer']),
		 help( 'enable GUI tracer' )]
]).

:- dynamic etb_server_options/1.
etb_server_options([]).

% etb_server_cmd/0, etb_server_cmd/1 and etb_server_cmd/2 are called by etb_command:do
% etb_server_with_args/1 is called by etb:etb_server
%
etb_server_cmd :-
	param:etb_port(Port), % use same port for all etb APIs
	etb_server_cmd(Port).

etb_server_cmd(Port) :-
	param:build_version(etb,Vnum), format('etb-server version ~a starting~n',Vnum),
	%create_server_audit_log,
	(   param:guiserver(on)
	->  trace
	;   true
	),
	(   param:etb_run_with_http_server(true)
	->  param:etb_token(Etoken),
		Opts = [portnumber(Port),jsonresp(true),token(Etoken)],
		param:setparam(sleep_after_server_start,off),
		etb_server_with_opts(Opts)
	;   true
	).

run_http_etb_server(Port) :-
	http_server(http_dispatch, [port(Port)]),
	format('etb-server listening on port ~d~n',[Port]),
	% audit_gen(etb, etb_start, success),
	% param:setparam(epp_status,etb_server),
	% epp:epp_with_etb,
	(   param:sleep_after_server_start(on)
	->  param:server_sleeptime(S), go_to_sleep(S)
	;   true
	).

etb_server_cmd(Port,EToken) :-
	param:setparam(etb_token,EToken),
	etb_server_cmd(Port).

etb_server_with_args(Argv) :-
	% process the arguments
	etb_server_opt_spec(OptSpec),
	catch(
	    opt_parse(OptSpec,Argv,Opts,_Positionals),
	    E, writeln('error in command line arguments')),
	!,
	(   nonvar(E)
	->  halt(1)
	;   retractall(etb_server_options(_)), assert(etb_server_options(Opts))
	),
	etb_server_with_opts(Opts).

etb_server_with_opts(_) :- param:etb_server_is_running(true), !,
	writeln('ETB server is already running').
etb_server_with_opts(Opts) :-
	process_id(Pid),
	param:build_version(etb,Vnum), format('etb-server version ~a starting pid=~d~n',[Vnum,Pid]),
	format('Options=~q~n',[Opts]),
	(   memberchk(portnumber(EPort),Opts); true ),
	(   var(EPort)
	->  param:etb_port(EPort)
	;   param:setparam(etb_port,EPort)
	),

	(   memberchk(verbose(true),Opts)
	->  param:setparam(verbose,on)
	;   param:setparam(verbose,off)
	),

	(   memberchk(jsonresp(true),Opts)
	->  param:setparam(jsonresp_server,on), % turns on JSON responses for server
	    param:setparam(jsonresp,on)
	;   param:setparam(jsonresp_server,off),
	    param:setparam(jsonresp,off)
	),

	(   memberchk(epp(true),Opts)
	->  param:setparam(epp_status,etb_server) % activate EPP as part of etb server
	;   true
	),

	(   memberchk(selftest(true),Opts) 
	->  param:setparam(self_test,on)
	;   param:setparam(self_test,off)
	),

	(   memberchk(token(Token),Opts); true ),
	(   atom(Token)
	->  param:setparam(etb_token,Token)
	;   true
	),

	(   memberchk(guitracer(true),Opts)
	->  guitracer
	;   true
	),

	% create_server_audit_log,
	http_server(http_dispatch, [port(EPort)]),
	param:setparam(etb_server_is_running,true),
	format('etb-server listening on port ~d~n',[EPort]),
	% audit_gen(etb, etb_start, success),

	% run self-test here if turned on in param or command line

	(   param:sleep_after_server_start(on)
	->  param:server_sleeptime(S), go_to_sleep(S)
	;   true
	).

go_to_sleep(S) :-
	sleep(S),
	periodic_goals,
	go_to_sleep(S).

periodic_goals :-
	% add periodic ETB goals here, e.g. synchronization
	true.
/*
create_server_audit_log :- param:audit_logging(file), !,
	audit:gen_time_stamp(TS),
	param:log_directory_name(LogD),
	atomic_list_concat([LogD,'/etb_audit_log','_',TS],LogFile),
	format('Audit log file: ~w~n',LogFile),
	open(LogFile,append,AudStream),
	param:setparam(audit_stream,AudStream).
create_server_audit_log.
*/
