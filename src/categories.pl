% ETB Knowledge Base - Evidence Categories

:- module(categories, [evidence_category/4, evidence_categories/1,
			validation_method/3, validation_agent/3,
			validation_agents/1]).

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

evidence_categories(Categories) :- var(Categories), !,
	findall(Category, evidence_category(Category,_,_,_), Categories).

validation_agents(Agents) :- var(Agents), !,
	findall(Agent, validation_agent(Agent,_,_), Agents).