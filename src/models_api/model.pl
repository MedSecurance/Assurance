:- module(model, [load_model/2]).

				% load_model(ModelId, Model)

load_model(ModelId, model(Policy, Platform, Configuration)) :-
	format('*** loading model ~a ... ', [ModelId]),
				% load policy
	atomic_list_concat( [ '../KB/MODELS/', ModelId, '/policy.pl' ], PolicyFilename),
	open(PolicyFilename, read, PolicyInput),
	read_term(PolicyInput, Policy, []),
	close(PolicyInput),
				% load platform
	atomic_list_concat( ['../KB/MODELS/', ModelId, '/platform.pl'], PlatformFilename),
	open(PlatformFilename, read, PlatformInput),
	read_term(PlatformInput, Platform, []),
	close(PlatformInput),
				% load configuration
	atomic_list_concat( ['../KB/MODELS/', ModelId, '/configuration.pl'], ConfigurationFilename),
	open(ConfigurationFilename, read, ConfigurationInput),
	read_term(ConfigurationInput, Configuration, []),
	close(ConfigurationInput),
				%
	format('done.~n').
