% ETB-specific command procedures

%%%%%%%%%%
% The procedures IoMT_system_inst and ISO_case_inst 
% generate the correspoding text and htmp exports to CAP that are maintained
% as examples. The procs can be re-run to regenerate the example outputs.
% If the procs or anything they are dependent upon (e.g. model, patterns, etc.)
% are modified the procs should be re-run to regenerate the CAP outputs.
%
proc('IoMT_case', [
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

proc('ISO_case', [
		set_v(ModelId, '2.0'),
		set_v(CaseId, iso_system_example),
		load_model_v(ModelId, App_Specification, Platform, _Configuration),
                instantiate_pattern('MS_generic_risk_based',['hit-spec',App_Specification,Platform],CaseId),
	        export_case(CaseId,txt),
		export_case(CaseId,html),
		detach_case
    ]).
%%%%%%%%%%

%%%%%%%%%%
% instantiate the person pattern as person_examp
proc(person_inst, [
    instantiate_pattern('person', ['Marius', 'Programming'], 'person_examp'),
    export_case(cap_person,txt),
	detach_case
]).

% export person_examp created by the person_inst proc
proc(person_exp, [
    update,
    attach_case(person_examp),
    export_case(cap_person,html),
	detach_case
]).

proc(qualified_person_inst, [
	instantiate_pattern('qualified_person', ['Programming', 'Marius'], 'qual_person_examp'),
	export_case(cap_qual_person,txt),
	detach_case
]).

% instantiate a list of patterns using model 1.0 as system_examp and export
proc(mils_system_inst, [
	set_v(ModelId, '1.0'),
	set_v(CaseId, mils_system_example),
	load_model_v(ModelId, Policy, Platform, _Configuration),
	set_v(AC,
		[ 'foundational_plane'-[Platform],
		'operational_plane'-[Policy],
		'person'-['Alice', 'AC Patterns Definition'],
		'person'-['Bob', 'ETB Development']
		]),
	instantiate_pattern_list(AC,CaseId),
	export_case(CaseId,html),
	detach_case
]).

% pass a list as an actual parameter to pattern instantiation
proc(teamN, [
        instantiate_pattern(teamOfN, [programming, list([marius,rance])], teamN)
    ]).

proc(shortdemo, [
	help(proc),
	help(show_proc),
	help(show_pattern),

	show_proc(shortdemo),
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
	export_case(CaseId, txt),
	detach_case,

	echo('DONE!')
]).



%%%% PAST DEMOS %%%%

proc(demo_day, [
		help,
		help(show_pattern),
		help(instantiate_pattern),
		status,

		show_procs,
		show_proc(demo_day),
		show_proc(person_inst),
		
		show_pattern(qualified_person),
		instantiate_pattern('qualified_person', ['Programming', 'Marius'], 'person_examp'),
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

