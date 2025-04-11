% ETB Knowledge Base - Evidence Categories

:- module(categories, [evidence_category/4]).

:- use_module([  ]).

		%
		% evidence_category(CatName,Description,EvidenceType,ValidationMethod)
		%
		% validation_method(ValName, ValDescription, ValidationAgent)
		%
		% validation_agent(AgentName, AgentArgs, AgentResult)
		%
		% These three structures are now defined in KB/EVIDENCE


:- dynamic evidence_category/4, validation_method/3, validation_agent/3.

:- include('../KB/EVIDENCE/categories.pl').

:- include('../KB/EVIDENCE/agents.pl').

/*
evidence_category(axiom,_,_,_).
evidence_category(certificate,_,_,_).
evidence_category(ichecker,_,_,_).
evidence_category(ocra,_,_,_).
%evidence_category(_,_,_,_).
evidence_category(unknown,_,_,_).

		%
		% validation_method(MethodId,ValidationAgent)
		%

validation_method(model_checking,_).
*/