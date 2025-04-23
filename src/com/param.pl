% GLOBAL PARAMETERS OF THE Open Evidential Tool Bus (O-ETB)
%
% all parameters should be defined here
%
:- module(param, [setparam/2,
                  debug/1, statusprt/1, guitracer/1, guiserver/1,
		  self_test/1, regression_test/1, initialize/1, verbose/1,
		  initialized/1, etb_initialized/1, user_level/1, settable_params/1,
		  self_test_modules/1, regression_test_modules/1, test_modules/2,
		  local_pdf_viewer/2, local_dot_render/2,local_open_file/2,
                  build_version/2, build_version/3,
                  build_current_version_description/2, build_name/3,
		  name_string/1, name_string/2, prompt_string/1, prompt_string/2, msg_failed_command/1,
		  msg_unimplemented_command/1,
		  msg_script_read/1, msg_running_script/1, msg_script_aborted/1,
		  pattern_prefix/1, pattern_language_version/1, server_version/1,
		  test_directory/1, patterns_directory/1, models_directory/1, log_directory/1,
		  cases_repo_dir/1, evidence_repo_dir/1, cap_dir/1,
		  prettyprint_tab/1,
		  host_os/1, local_pdf_viewer/2,
                  server_port/1, etb_port/1, etb_api_port/1, erepo_api_port/1, arepo_api_port/1,
                  server_sleeptime/1, kb_token/1, repo_token/1, audit_token/1,
                  audit_logging/1, audit_stream/1, audit_record/1,
		  audit_selection/1,
		  null_stream/1, sleep_after_server_start/1,
                  jsonresp_server/1, jsonresp/1,
                  localhost_ip/1, serverhost_ip/1,
		  etb_run_with_http_server/1, etb_server_is_running/1
		 ]).

% Versioning of various things
%
% Past versions build_version/3 and current version build_version/2:
% When starting a new version create a new build_version/2 and
% add a description as a third argument to the preceding version.
%
% When development is actively going on, the current version, given by
% build_version/2, is the version against which changes are currently being
% actively made and checked-in to the git repository. It is a living version.

:- discontiguous build_version/3, build_version/2, build_current_version_description/2.

build_version(etb,'1.0.0','initial structure setup').

build_version(etb,'1.0.1','added directory structure and new files').

build_version(etb,'1.0.2','added parameterization').

build_version(etb,'1.0.3','various changes toward Prototype #1').

build_version(etb,'1.1.0','Prototype #1').

build_version(etb,'1.1.1','Revisions to Prototype #1, incl: commands and pattern extensions').

build_version(etb,'1.1.2' /* ongoing development */ ).

build_current_version_description(etb,'ongoing developments to ease integration with other tools').
%

% Used by the command interpreter
%
prompt_string('').
prompt_string(etb,'etb').
prompt_string(kb,'kb').
prompt_string(arepo,'arepo').
prompt_string(erepo,'erepo').

build_name(etb,'O-ETB','o-etb').
build_name(kb,'O-KB','o-kb').
build_name(arepo,'O-AREPO','o-arepo').
build_name(erepo,'O-EREPO','o-erepo').

name_string('').
name_string(etb,'Open Evidential Tool Bus').
name_string(kb,'O-ETB Knowledge Base').
name_string(arepo,'O-ETB Assurance CASES Repository').
name_string(erepo,'O-ETB EVIDENCE Repository').

% SETTABLE PARAMETERS
%
% enter new params both in dynamic directive and settable_params
%
:- dynamic prompt_string/1, debug/1, statusprt/1, guitracer/1, guiserver/1,
        self_test/1, regression_test/1, verbose/1,
        initialize/1, initialized/1, etb_initialized/1, user_level/1,
        etb_mode/1, etb_logging/1, null_stream/1, sleep_after_server_start/1,
        etb_run_with_http_server/1, etb_server_is_running/1.

settable_params([prompt_string,debug,statusprt,guitracer,guiserver,
		 self_test,regression_test,verbose,
		 initialize,initialized,etb_initialized,user_level,
		 etb_mode, etb_logging, null_stream, sleep_after_server_start,
		 etb_run_with_http_server, etb_server_is_running
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

jsonresp_server(off).
jsonresp(off). % off / on / separate / same

% API ports - not yet implemented
server_port(9001). % default server port
etb_port(9001).
etb_api_port(9001).
arepo_api_port(9001). % default arepor server port, currently same as server_port
erepo_api_port(9002). % default evidence repo port

localhost_ip('127.0.0.1').
serverhost_ip('127.0.0.1').

server_sleeptime(32767).

% AUTHORIZATION TOKENS (default token values)
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
sleep_after_server_start(on). % normally: on
etb_run_with_http_server(true). % 'false' is used for testing (set to false by test harness)
etb_server_is_running(false).

initial_evidence_counter_base(10000).

% Modules providing functional tests
%
self_test_modules([etb]).       % modules that provide self tests
regression_test_modules([etb]). % modules that provide regression tests
test_modules(Set,Modules) :-
    ( atom(Set)
      ->
      (atomic_concat(Set,'_test_modules',ModuleSet),
       GetMods =.. [ModuleSet,Modules],
       (   clause(GetMods,_)
	   -> call(GetMods)
	   ;  Modules = []
       )
      )
      ; Modules = []
    ).

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
%

ac_repo_file('repository.pl').
ev_repo_file('repository.pl').
ev_status_file('status').
ev_validate_extension('_validate').
mod_policy_file('policy.pl').
mod_platform_file('platform.pl').
mod_configuration_file('configuration.pl').
mod_properties_dir('properties').
kb_evidence_category_file('categories.pl').

% Key pathname components
%
path_prefix('..').		% relative to expected execution location

cap('CAP').			% Certification Assurance Package(s)

kb('KB').			% Base of the Knowledge Base
patterns('PATTERNS').		% Assurance Case Patterns dir name
models('MODELS').		% System Models dir name
workflows('WORKFLOWS').	% Workflow definitions dir name
categories('CATEGORIES').	% Evidence Categories dir name

repository('REPOSITORY').	% Base of the Repositories
cases('CASES').			% Assurance Case Repository name
evidence('EVIDENCE').		% Evidence Repository name

test_directory('TEST').
patterns_directory('KB/PATTERNS').
models_directory('KB/MODELS').
workflows_directory('KB/WORKFLOWS').
categories_directory('KB/CATEGORIES').
log_directory('RUNTIME/LOG').

pattern_files( [ 'IoMT', 'ISO_81001', 'MILS' ] ).

% Constructors for the primary runtime and persistent storage area names
%
cases_repo_dir(CasesDir) :- % used in assurance module
	path_prefix(Pre), repository(Repository), cases(Cases),
	atomic_list_concat([Pre,Repository,Cases],'/',CasesDir).

evidence_repo_dir(EvidenceDir) :- % used in evidence module
	path_prefix(Pre), repository(Repository), evidence(Evidence),
	atomic_list_concat([Pre,Repository,Evidence],'/',EvidenceDir).

cap_dir(CAPdir) :- % used in export module
	path_prefix(Pre), cap(Cap),
	atomic_list_concat([Pre,Cap],'/',CAPdir).

kb_patterns_dir(KBPdir) :- 
	path_prefix(Pre), kb(KB), patterns(Patterns),
	atomic_list_concat([Pre,KB,Patterns],'/',KBPdir).

kb_models_dir(KBMdir) :- 
	path_prefix(Pre), kb(KB), models(Models),
	atomic_list_concat([Pre,KB,Models],'/',KBMdir).

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
