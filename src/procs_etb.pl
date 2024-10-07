% ETB-specific command procedures
:- use_module('etb').

proc(m18review, [
		help(show_proc),
		help(show_pattern),

		show_proc(m18review),
	        show_pats,
		etb_reset,
	
		show_pattern(person),
		help(instantiate_pattern),
		instantiate_pattern('person', ['Marius', 'Programming'], 'person_example'),
		export_case(person_example, txt),
		export_case(person_example, html),
		detach_case,

		show_pattern(teamOfN),
                instantiate_pattern(teamOfN, [programming, list([marius,rance])], team_example),
		export_case(team_example, html),
		detach_case,

	        show_pattern('IoMT_system'),
	        show_pattern('application_plane'),
	        show_pattern('platform_plane'),
	        show_proc('IoMT_system_inst'),

		set_v(ModelId, '2.0'),
		set_v(CaseId, iomt_system_example),
		load_model_v(ModelId, App_Specification, Platform, _Configuration),
		set_v(APL,
			[ 'IoMT_system'-[App_Specification, Platform],
			'person'-['Alicia', 'Assurance'],
			'person'-['Roberto', 'Development']
			]),
		instantiate_pattern_list(APL, CaseId),
		export_case(CaseId, html),
		detach_case,

		show_pattern('MS_generic_risk_based'),
		show_pattern('MS_residual_risk'),
		show_pattern('MS_acceptable_risk'),
		show_pattern('MS_accepted_risk'),
		
		echo('DONE!')
	]).

proc('IoMT_system_inst', [
		set_v(ModelId, '2.0'),
		set_v(CaseId, iomt_system_example),
		load_model_v(ModelId, App_Specification, Platform, _Configuration),
		set_v(AC,
			[ 'IoMT_system'-[App_Specification, Platform],
			'person'-['Alicia', 'Assurance'],
			'person'-['Roberto', 'Development']
			]),
		instantiate_pattern_list(AC,CaseId),
	        export_case(CaseId,txt),
		export_case(CaseId,html),
		detach_case
    ]).

proc('ISO_case_inst', [
		set_v(ModelId, '2.0'),
		set_v(CaseId, iomt_system_example),
		load_model_v(ModelId, _App_Specification, _Platform, _Configuration),
                instantiate_pattern_list('MS_generic_risk_based',[]),
	        export_case(CaseId,txt),
		export_case(CaseId,html),
		detach_case
    ]).

%%%%%%%%%%

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

proc(teamN, [
                instantiate_pattern(teamOfN, [programming, list([marius,rance])], teamN)
        ]).

proc(demo_day, [
		help,
		help(show_pattern),
		help(instantiate_pattern),
		status,

		show_procs,
		show_proc(demo_day),
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

		show_pattern(generic_risk_based),
		show_pattern(residual_risk),
		show_pattern(acceptable_risk),
		show_pattern(accepted_risk),
		
		show_pattern(foundational_plane),
		show_pattern(operational_plane),

		echo('DONE!')
	]).
