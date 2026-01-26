% ETB-specific command procedures

proc(inst_test_d, [
	% reset,
	aco_apl('../TEST/ACO/bio_v6d.aco', '../TEST/ACO/bio_v6d.apl'),
	load_patterns('../TEST/aco/bio_v6d.apl'),
	% show_pattern('BioAssist'),
	instantiate_pattern('BioAssist', [ ], bio6d),
	export_case(bio6d, txt),
	export_case(bio6d, html),
	detach_case
	]).

proc(inst_test, [
	reset,
	instantiate_pattern(person, [marius,programming], person_example),
	export_case(person_example,txt),
	export_case(person_example,html),
	detach_case,

	instantiate_pattern(teamOfN, [programming, list([marius,rance])], team_example),
	export_case(team_example, txt),
	export_case(team_example, html),
	detach_case,

	aco_apl('../TEST/ACO/op_plane.aco', '../TEST/ACO/op_plane.apl'),
	load_patterns('../TEST/ACO/op_plane.apl'),
	instantiate_pattern('Op_Plane', [ ], op_plane),
	export_case(op_plane, txt),
	export_case(op_plane, html),
	detach_case,

	aco_apl('../TEST/ACO/tiny_multi5.aco', '../TEST/ACO/tiny_multi5.apl'),
	load_patterns('../TEST/ACO/tiny_multi5.apl'),
	instantiate_pattern('Main', [ ], tiny_multi5),
	export_case(tiny_multi5, txt),
	export_case(tiny_multi5, html),
	detach_case,

	aco_apl('../TEST/ACO/bio_v6.aco', '../TEST/ACO/bio_v6.apl'),
	load_patterns('../TEST/aco/bio_v6.apl'),
	% show_pattern('BioAssist'),
	instantiate_pattern('BioAssist', [ ], bio6),
	export_case(bio6, txt),
	export_case(bio6, html),
	detach_case
	]).

proc(show_aco_tests, [
	shell('cat ../TEST/ACO/tiny_test.aco'),
	echo('--------------------------------'),
	aco_tree('../TEST/ACO/tiny_test.aco'),
	aco_stats('../TEST/ACO/tiny_test.aco'),
	echo('================================'),

	shell('cat ../TEST/ACO/tiny_multi.aco'),
	echo('--------------------------------'),
	aco_tree('../TEST/ACO/tiny_multi.aco'),
	aco_stats('../TEST/ACO/tiny_multi.aco'),
	echo('================================'),

	shell('cat ../TEST/ACO/tiny_multi3.aco'),
	echo('--------------------------------'),
	aco_tree('../TEST/ACO/tiny_multi3.aco'),
	aco_stats('../TEST/ACO/tiny_multi3.aco'),
	echo('================================'),

	shell('cat ../TEST/ACO/tiny_multi5.aco'),
	echo('--------------------------------'),
	aco_tree('../TEST/ACO/tiny_multi5.aco'),
	aco_stats('../TEST/ACO/tiny_multi5.aco'),
	echo('================================'),

	shell('cat ../TEST/ACO/op_plane.aco'),
	echo('--------------------------------'),
	aco_tree('../TEST/ACO/op_plane.aco'),
	aco_stats('../TEST/ACO/op_plane.aco'),
	echo('================================')
	]).

%%%%%%%%%%
% Demonstration of ACO capabilities
%   run these in ETB command interpreter by typing, e.g.:  proc(op_plane_ACO, step). (step through with Return key)
%   only canonicalization is not demonstrated in these examples
% It is suggested to reset the REPOSITORY and CAP when repeating these examples. in ETB command mode type: reset.

proc(op_plane_ACO, [
	 aco_tree('../TEST/aco/tiny_test.aco'),
	 aco_stats('../TEST/aco/tiny_test.aco'),

	 aco_tree('../TEST/aco/op_plane.aco'),
	 aco_stats('../TEST/aco/op_plane.aco'),
	 aco_tree('../TEST/aco/op_plane.aco', [skeleton]),
	 aco_apl('../TEST/aco/op_plane.aco', '../TEST/aco/op_plane.apl'),
	 load_patterns('../TEST/aco/op_plane.apl'),
	 show_pattern('Op_Plane'),
	 instantiate_pattern('Op_Plane', [ ], op_plane),
	 export_case(op_plane, txt),
	 export_case(op_plane, html),
	echo('DONE! Browse result in CAP/op_plane/index.html')
     ]).

proc(hgo_ACO, [
	 aco_tree('../TEST/aco/hgo_v2.aco'),
	 aco_stats('../TEST/aco/hgo_v2.aco'),
	 aco_tree('../TEST/aco/hgo_v2.aco', [skeleton]),
	 aco_apl('../TEST/aco/hgo_v2.aco', '../TEST/aco/hgo_v2.apl'),
	 load_patterns('../TEST/aco/hgo_v2.apl'),
	 show_pattern('HGO_StabVida_Assurance_Case'),
	 instantiate_pattern('HGO_StabVida_Assurance_Case', [ ], hgo),
	 export_case(hgo, txt),
	 export_case(hgo, html),
	echo('DONE! Browse result in CAP/hgo/index.html')
     ]).

proc(bio_ACO, [
	 aco_tree('../TEST/aco/bio_v4.aco'),
	 aco_stats('../TEST/aco/bio_v4.aco'),
	 aco_tree('../TEST/aco/bio_v4.aco', [skeleton]),
	 aco_apl('../TEST/aco/bio_v4.aco', '../TEST/aco/bio_v4.apl'),
	 load_patterns('../TEST/aco/bio_v4.apl'),
	 show_pattern('BioAssist'),
	 instantiate_pattern('BioAssist', [ ], bio),
	 export_case(bio, txt),
	 export_case(bio, html),
	echo('DONE! Browse result in CAP/bio/index.html')
     ]).

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

