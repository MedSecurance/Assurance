% ETB-specific command procedures
:- use_module('etb').

proc(ex1, [
        instantiate_pattern('person', ['Marius', 'Programming'], 'ac1'),
        export_case(ac1,txt),
	detach_case
    ]).

proc(ex2, [
        update,
        attach_case(ac1),
        export_case(ac1,html),
	detach_case
    ]).

proc(ex3, [
	set_v(ModelId, '1.0'),
	set_v(CaseId, ac2),
	load_model_v(ModelId, Policy, Platform, _Configuration),
	set_v(AC,
		[ 'foundational_plane'-[Platform],
		  'operational_plane'-[Policy],
		  'person'-['Alice', 'AC Patterns Definition'],
		  'person'-['Bob', 'ETB Development']
	          /*
	          'invariant_property'-[ModelId, 'p1'],
	          'invariant_property'-[ModelId, 'p2']
	          */
	     	]),
	instantiate_pattern_list(AC,CaseId),
	export_case(CaseId,html),
	detach_case
    ]).
