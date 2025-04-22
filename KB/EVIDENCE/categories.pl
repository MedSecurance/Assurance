% Knowledge base of evidence categories, validation methods and validation agents

%	evidence_category(CatName, CatDescription, CatType, CatValidationMethod)

evidence_category(axiom, _, _, fact_check).
evidence_category(certificate, _, _, cert_check).
evidence_category(ichecker, _, _, invariant_check).
evidence_category(contract, _, _, contract_check).
evidence_category(property, _, _, property_check).
% evidence_category(unknown, _, _, _).

%	validation_method(ValName, ValDescription, ValidationAgent)

validation_method(fact_check, 'Evidence is validated by declared premises', axiom_agent).
validation_method(cert_check, 'Certificate exists and is valid', certificate_agent).
validation_method(invariant_check, 'Invariant is valid for artefact', ichecker_agent).
validation_method(contract_check, 'Contract consistency and refinement is valid', ocra_agent).
validation_method(property_check, 'Behavior property is valid for artefact', nusmv_agent).

%	validation_agent(AgentName, AgentArgs, AgentResult)
%		additional information about the agent to support improved agent interface
%		AgentArgs / AgentResult are: <term> ::= <atom> | <compound term> | <list>
%
% 		a corresonding file agents/<AgentName>.pl must exist or a warning will be given

validation_agent(axiom_agent, _, _).
validation_agent(certificate_agent, _, _).
validation_agent(ichecker_agent, _, _).
validation_agent(ocra_agent, _, _).
% validation_agent(nusmv_agent, _, _). % doesn't currently exist
