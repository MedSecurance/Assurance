% GLOBAL PARAMETERS OF THE TOG Evidential Tool Bus
%
% all parameters should be defined here
%
:- module(param, [setparam/2,
                  debug/1, statusprt/1, guitracer/1, guiserver/1,
		  self_test/1, regression_test/1, initialize/1, verbose/1,
		  initialized/1, etb_initialized/1, user_level/1, settable_params/1,
		  self_test_modules/1, regression_test_modules/1,
		  local_pdf_viewer/2, local_dot_render/2,local_open_file/2,
                  build_version/2, build_version/3,
                  build_current_version_description/2, build_name/3,
		  name_string/1, name_string/2, prompt_string/1, prompt_string/2, msg_failed_command/1,
		  msg_unimplemented_command/1,
		  msg_script_read/1, msg_running_script/1, msg_script_aborted/1,
		  pattern_prefix/1, pattern_language_version/1, server_version/1,
		  pattern_directory_name/1, log_directory_name/1, cap_directory_name/1,
		  test_directory_name/1, repo_directory_name/1,
                  ac_repo_directory/1, ev_repo_directory/1,
		  prettyprint_tab/1,
		  host_os/1, local_pdf_viewer/2,
                  server_port/1, etb_api_port/1, erepo_api_port/1, arepo_api_port/1,
                  server_sleeptime/1, kb_token/1, repo_token/1, audit_token/1,
                  audit_logging/1, audit_stream/1, audit_record/1,
		  audit_selection/1,
		  null_stream/1, sleep_after_server_start/1,
                  jsonresp_server/1, jsonresp/1,
                  localhost_ip/1, serverhost_ip/1
		 ]).

% Versioning of various things
%
% Past versions etb_version/2 and current version etb_version/1:
% When starting a new version create a new etb_version/1 and
% add a description as a second argument to the preceding version.
%
% When development is actively going on, the current version, given by
% etb_version/1, is the version against which changes are currently being
% actively made and checked-in to the git repository. It is not fixed.

:- discontiguous build_version/3, build_version/2, build_current_version_description/2.

build_version(etb,'1.0.0','initial structure setup').

build_version(etb,'1.0.1','added directory structure and new files').

build_version(etb,'1.0.2' /* ongoing development */ ).

build_current_version_description(etb,'added parameterization').
%

% Used by the command interpreter
%
prompt_string('').
prompt_string(etb,'etb').
prompt_string(kb,'kb').
prompt_string(arepo,'arepo').
prompt_string(erepo,'erepo').

build_name(etb,'TOG-ETB','TOG-etb').
build_name(kb,'TOG-KB','TOG-kb').
build_name(arepo,'TOG-AREPO','TOG-arepo').
build_name(erepo,'TOG-EREPO','TOG-erepo').

name_string('').
name_string(etb,'TOG Evidential Tool Bus').
name_string(kb,'TOG-ETB Knowledge Base').
name_string(arepo,'TOG-ETB Assurance Case Repository').
name_string(erepo,'TOG-ETB Evidence Repository').

% SETTABLE PARAMETERS
%
% enter new params both in dynamic directive and settable_params
%
:- dynamic prompt_string/1, debug/1, statusprt/1, guitracer/1, guiserver/1,
        self_test/1, regression_test/1, verbose/1,
        initialize/1, initialized/1, etb_initialized/1, user_level/1,
        etb_mode/1, etb_logging/1, null_stream/1, sleep_after_server_start/1.

settable_params([prompt_string,debug,statusprt,guitracer,guiserver,
		 self_test,regression_test,verbose,
		 initialize,initialized,etb_initialized,user_level,
		 etb_mode, etb_logging, null_stream, sleep_after_server_start
                ]).

setparam(Param,Value) :- atom(Param), ground(Value),
    settable_params(SP), memberchk(Param,SP), !,
    P1 =.. [Param,_], retractall(P1),
    P2 =.. [Param,Value], assert(P2).
setparam(_,_).

% command_mode establishes the default mode of the top-level command
% interpreter when it is started without an argument.
% Its values can be e.g. etb | kb | repo
% user_level is related to user_mode/1 and user_lev/1 in command.pl
% Its values can be e.g. basic | advanced | developer
command_mode(etb).
user_level(developer). % default command user mode: basic/advanced/developer

etb_mode(normal).
debug(off). % off/on
statusprt(off). % off/on
guitracer(on). % off/on
guiserver(off). % off/on
self_test(off). % off/on
regression_test(off). % off/on
null_stream(x).
initialize(on). % off/on
initialized(false).
verbose(on). % off/on
sleep_after_server_start(on). % normally: on

jsonresp_server(off).
jsonresp(off). % off / on / separate / same

% API ports
server_port(9001). % default server port
etb_api_port(9001).
arepo_api_port(9001). % default arepor server port, currently same as server_port
erepo_api_port(9002). % default evidence repo port

localhost_ip('127.0.0.1').
serverhost_ip('127.0.0.1').

server_sleeptime(32767).

% AUTHORIZATION TOKENS (default tokens)
etb_token('etb_token').
kb_token('kb_token').
repo_token('repo_token').
audit_token('audit_token').

% AUDITING - In addition to (optionally) sending audit records to a
% system audit service, they will be written to a local log if
% audit_logging is not 'off'. The local log is sent to audit_stream
% (user_error by default). If audit_logging is 'file' then a file will
% be opened and audit_stream set to the open file stream.

audit_logging(file). % 'file' or 'on' or 'off'
audit_stream(user_error). % default stream for audit log (standard error)
audit_selection([]). % currently selected set of events for audit generation
audit_record('audit_log(~w, ~q, ~q, ~q).~n'). % format of the audit record [TS,Source,Event,EventData]

etb_url(ETB_URL) :-
    serverhost_ip(IP),
    etb_api_port(EP),
    atomic_list_concat(['http://',IP,':',EP,'/etb/'], ETB_URL).
etb_logging(file). % 'file', or 'on' (to std out), or 'off'
etb_stream(user_error). % default stream for EPP log (standard error)
etb_initialized(false).
etb_status(inactive). % inactive, wf_server, standalone, ac_server, ev_server

initial_evidence_counter_base(10000).

% Modules providing functional tests
%
self_test_modules([]).       % modules that provide self tests
regression_test_modules([]). % modules that provide regression tests

% Misc strings
%
msg_failed_command('command failed').
msg_unimplemented_command('Unimplemented command or option. Enter:<command>. help. or quit.').
msg_script_read('script read:').
msg_running_script('running script ...').
msg_script_aborted('script aborted').

pattern_prefix('pat_').
pattern_language_version('0.1').
server_version('0.1').


% Files and directories
% all directory names should include the final '/'
repo_directory_name('REPOSITORY/').
ac_repo_directory('REPOSITORY/CASES/').
ac_repo_file('repository.pl').

ev_repo_directory('REPOSITORY/EVIDENCE/').
ev_repo_file('repository.pl').
ev_status_file('status').

test_directory_name('TEST/').
pattern_directory_name('KB/PATTERNS/').
models_directory_name('KB/MODELS/').
log_directory_name('RUNTIME/LOG/').
cap_directory_name('CAP/').

% Misc values
%
prettyprint_tab(2). % tab indent for pretty printed output

host_os(os_x). % define only one
% host_os(linux). % define only one
% host_os(windows). % define only one

% External utilities
%
local_pdf_viewer(os_x,'"/Applications/Adobe Reader 9/Adobe Reader.app/Contents/MacOS/AdobeReader"').
local_dot_render(os_x,'dot').
local_open_file(os_x,'open').
