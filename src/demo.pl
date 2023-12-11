


run(ModelId, CaseId) :-
				% load the model
	
	model:load_model(ModelId, Model),
	Model = model(Policy, Platform, _Configuration),
	
				% assurance case specification
	
	AC = [ 'foundational_plane'-[Platform],
	       
	       'operational_plane'-[Policy],

	       'person'-['Alice', 'AC Patterns Definition'],
	       'person'-['Bob', 'ETB Development']

	       /*
	       'invariant_property'-[ModelId, 'p1'],
	       'invariant_property'-[ModelId, 'p2']
	       */
	       
	     ],
	
				% instantiate

	instantiate:instantiate_pattern_list(AC, CaseId),
	
				% export  html

	export:ac_export(CaseId, 'html').
