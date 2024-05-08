% ETB-specific command set

:- use_module('etb').

%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%
% definition of the ETB tool interactive commands syntax
% syntax( Signature, CommandSet ).
%
syntax(ac_export(basename, format),                              etb).
syntax(attach_case(case_id),                                     etb).
syntax(detach_case,                                              etb).

syntax(etb,                            basic).
syntax(etb_server,                                               etb).
syntax(etb_reset,						 etb).
syntax(etb_server(arg),                                          etb).
syntax(etbt,                                                     etb).
syntax(etbt(test_id),                                            etb).
syntax(etbt(test_id,mode),                                       etb).

syntax(etbtests,                                                 etb).

syntax(import(spec_type,file,s_id),                              etb).

syntax(instantiate_pattern(pattern_name,arg_list,ac_id),	 etb).

syntax(instantiate_pattern_list(pattern_list,ac_id),		 etb).

syntax(load_model_v(modelid,policy,platform,config),		 etb).

syntax(update,                                                   etb).

%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%
% ETB tool command semantics
% semantics(<signature with formal params>) :- <constraints>.
%
% optional static semantics entry, e.g., used to check command arguments
% distinct from syntax so syntax can be called separately
%
semantics(ac_export(Name,Format)) :- !, atom(Name), atom(Format), (Format==txt;Format==html).
semantics(attach_case(Case)) :- !, atom(Case).

semantics(etb_server(A)) :- !, atomic(A), (number(A) ; A==nurvsim).
semantics(etbt(T)) :- !, atom(T).
semantics(etbt(T,E)) :- !, atom(T), atom(E).

semantics(import(T,F,Id)) :- !, atom(T), atom(F), atom(Id).

semantics(instantiate_pattern(PName,Args,CaseId)) :- !, atom(PName), is_list(Args), atom(CaseId).
semantics(instantiate_pattern_list(PatList,CaseId)) :- !, is_list(PatList), atom(CaseId).

semantics(load_model_v(Mid,Pol,Plat,Config)) :- !, atom(Mid), var(Pol), var(Plat), var(Config).

%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%
% command help strings
%   help(Key,    HelpString)
%
%   all strings for a given key are displayed when key is given as an
%   argument to the help command, e.g., "help(etb_server)"
%
help(ac_export,	'Export the current assurance case to the CAP.').
help(ac_export,	'Arg1 is a name in the CAP directory for the export.').
help(ac_export, 'Arg2 is the format (currently either txt or html).').

help(attach_case, 'Attach the identified assurance case in the repository.').
help(attach_case, 'Arg is an assurance case identifier.').

help(detach_case, 'Detach the currently attached assurance case.').

help(etb,       'Switch to etb user mode.').
help(etb_reset,	'Reset ETB repositories.').
help(etb_server,'Start the ETB server.').

help(etbt,      'Run an etb built-in test. Default is \'e2e\'.').
help(etbt,      'Arg1 (opt) is a test identifier.').
help(etbt,      'Arg2 (opt) is etb mode.').

help(import,    'Import a specification of type (model, property, ...).').
help(import,    'Arg1 is a specification type.').
help(import,    'Arg2 is a file name.').
help(import,    'Arg3 (opt) is the identifier to associate with the spec.').

help(instantiate_pattern,	'Instantiate a pattern from the KB into the REPO.').
help(instantiate_pattern, 	'Arg1 is the name of a defined pattern.').
help(instantiate_pattern, 	'Arg2 is a list of the required parameters for the pattern.').
help(instantiate_pattern, 	'Arg3 is a valid new assurance case ID.').

help(instantiate_pattern_list,	'Instantiate the given AC pattern into the REPO.').
help(instantiate_pattern_list,	'Arg1 is an AC pattern list.').
help(instantiate_pattern_list,	'Arg2 is a valid new assurance case ID.').

help(load_model_v, 'Load model from KB and return policy, platform and config components.').
help(load_model_v, 'Arg1 is a model identifier.').
help(load_model_v, 'Arg2 is a variable to receive the policy component.').
help(load_model_v, 'Arg3 is a variable to receive the platform component.').
help(load_model_v, 'Arg4 is a variable to receive the configuration component.').

help(update,	'Update assurance cases and evidence.').

%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%
% do the command, should be one for every implemented valid command form
% known broken or unimplemented commands should just "fail." straightaway
%
do(ac_export(Name,Format)) :- !, export:ac_export(Name,Format).

do(attach_case(Case)) :- !, assurance:attach_assurance_repository(Case).

do(detach_case) :- !, assurance:detach_assurance_repository.

do(etb) :- user_mode(etb), !, writeln('Already in etb mode').
do(etb) :- !, user_mode(M), retractall(user_mode(_)), assert(user_mode(etb)),
	param:prompt_string(etb,Prompt), param:setparam(prompt_string,Prompt),
	rem_commands(M), add_commands(etb), banner(etb).

do(etb_reset) :- !, etb_reset.

do(etb_server) :- !, etb_server:etb_server_cmd.
do(etb_server(A)) :- !, etb_server:etb_server_cmd(A).

do(etbt) :- !, etbt(e2e). % abbrev-change to suit current need
do(etbt(e2e)) :- !, etbt(e2e).
do(etbt(T,Mode)) :- !, etbt(T,Mode).
do(etbtests) :- !, load_test_files([]), run_tests. % .plt tests

do(import(T,F,Sid)) :- !,
    kb:load_specification_from_file(T,F,Sid).

do(instantiate_pattern(Name,Args,ACid)) :- !, instantiate:instantiate_pattern(Name,Args,ACid).
do(instantiate_pattern_list(PatList,ACid)) :- !,
	instantiate:instantiate_pattern_list(PatList,ACid).

do(load_model_v(Mid,Pol,Plat,Conf)) :- !, model:load_model(Mid,M), M = model(Pol,Plat,Conf).

do(update) :- evidence:update_ongoing.

%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%
% command procedures
%

etbt(e2e) :- % end-to-end test
	true.

etbt(Test,Emode) :-
	param:setparam(etb_mode,Emode),
	etbt(Test).
