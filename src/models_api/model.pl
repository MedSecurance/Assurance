:- module(model, [load_model/2, model_spec/1, model_loaded/1]).

:- use_module(['com/ui']).

:- dynamic model_spec/1, model_loaded/1.


				% load_model(ModelId, Model)

load_model(ModelId, model(Policy, Platform, Configuration)) :-
	vformat('*** loading model ~a ... ', [ModelId]),
	param:kb_models_dir(ModDir), param:mod_policy_file(MpolFile),
        param:mod_platform_file(MplatFile), param:mod_configuration_file(MconfFile),

				% load policy
	atomic_list_concat([ModDir, ModelId, MpolFile], '/', PolicyFilename),
	open(PolicyFilename, read, PolicyInput),
	read_term(PolicyInput, Policy, []),
	close(PolicyInput),
				% load platform
	atomic_list_concat([ModDir, ModelId, MplatFile], '/', PlatformFilename),
	open(PlatformFilename, read, PlatformInput),
	read_term(PlatformInput, Platform, []),
	close(PlatformInput),
				% load configuration
	atomic_list_concat([ModDir, ModelId, MconfFile], '/', ConfigurationFilename),
	open(ConfigurationFilename, read, ConfigurationInput),
	read_term(ConfigurationInput, Configuration, []),
	close(ConfigurationInput),
				%
        retractall(model_spec(_)), assert(model_spec( model(Policy, Platform, Configuration) ) ),
        retractall(model_loaded(_)), assert(model_loaded(true)),

	vformat('done.~n').
