% ETB Knowledge Base - Evidence Categories

:- module(categories, [evidence_category/4]).

:- use_module([  ]).

		%
		% evidence_category(CatName,Description,EvidenceType,ValidationMethod)
		%

:- dynamic evidence_category/4.

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