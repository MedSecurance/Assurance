:- module(am_etb, [ setup/0 ]).

				% models api

:- use_module(models_api/common).
:- use_module(models_api/platform).
:- use_module(models_api/policy).
:- use_module(models_api/configuration).
:- use_module(models_api/model).

:- use_module('../KB/patterns').
:- use_module(assurance).
:- use_module(evidence).

:- use_module(agents/axiom_agent).
:- use_module(agents/certificate_agent).
:- use_module(agents/ocra_agent).
:- use_module(agents/ichecker_agent).
:- use_module(agent).

:- use_module(instantiate).
:- use_module(export).

				% am-etb setup

setup :-
	attach_evidence_repository.

