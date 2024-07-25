% ETB-specific command procedures
:- use_module('etb').

proc(person_inst, [
        instantiate_pattern('person', ['Marius', 'Programming'], 'person_examp'),
        export_case(cap_person,txt),
		detach_case
    ]).

proc(person_exp, [
        update,
        attach_case(person_examp),
        export_case(cap_person,html),
		detach_case
    ]).

proc(system_inst, [
		set_v(ModelId, '1.0'),
		set_v(CaseId, system_examp),
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

proc(demo_day, [
		help,
		help(show_pattern),
		help(instantiate_pattern),
		status,
		show_procs,
		show_proc(person_inst),
		show_pattern(qualified_person),
		instantiate_pattern('qualified_person', ['Marius', 'Programming'], 'person_examp'),
		export_case(cap_person,txt),
		export_case(cap_person,html),
		detach_case,

		show_pattern(teamOf2),
		instantiate_pattern('teamOf2', ['Programming'], 'team_examp'),
		export_case(cap_team,html),
		detach_case,

		show_proc(system_inst),
		set_v(ModelId, '1.0'),
		set_v(CaseId, system_examp),
		load_model_v(ModelId, Policy, Platform, _Configuration),
		set_v(AC,
			[ 'foundational_plane'-[Platform],
			'operational_plane'-[Policy],
			'person'-['Alice', 'AC Patterns Definition'],
			'person'-['Bob', 'ETB Development']
			]),
		instantiate_pattern_list(AC,CaseId),
		export_case(CaseId,html),
		detach_case,

		show_pattern(foundational_plane),
		show_pattern(operational_plane),4

		echo('DONE!')
	]).