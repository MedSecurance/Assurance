% ETB Knowledge Base - Evidence Categories

:- module(categories, [evidence_category/4, evidence_categories/1,
			validation_method/3, validation_agent/3]).

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

:- include('../KB/EVIDENCE/agents.pl'). % may not be necessary, currently all info in KB/EVIDENCE/categories.pl
