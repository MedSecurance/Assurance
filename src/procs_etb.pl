% ETB-specific command procedures

% Tests of a set of new MILS argument patterns that should produce results comparable or
% better than the results of comparable invocations of the previous collection of MILS patterns
% in mils_system_example, mils_found_only and mils_op_only

proc(n_mils_system_example, [
	set_v(ModelId, '1.0'),
	set_v(CaseId, n_mils_system_example),
	load_model_v(ModelId, Policy, Platform, _Configuration),
	aco_apl('../Tools/APL_to_ACO_foundational_plane_executable_family_v2.aco','../Tools/APL_to_ACO_foundational_plane_executable_family_v2.apl'),
	load_patterns('../Tools/APL_to_ACO_foundational_plane_executable_family_v2.apl'),	
	aco_apl('../Tools/APL_to_ACO_operational_plane_executable_family_v3.aco','../Tools/APL_to_ACO_operational_plane_executable_family_v3.apl'),
	load_patterns('../Tools/APL_to_ACO_operational_plane_executable_family_v3.apl'),
	set_v(AC,
		[ 'n_foundational_plane'-[Platform],
		'n_operational_plane'-[Policy],
		'person'-['Alice', 'AC Patterns Definition'],
		'person'-['Bob', 'ETB Development']
		]),
	instantiate_pattern_list(AC,CaseId),
	export_case(CaseId,txt),
	export_case(CaseId,html)
]).

proc(n_mils_found_only, [
	aco_apl('../Tools/APL_to_ACO_foundational_plane_executable_family_v2.aco','../Tools/APL_to_ACO_foundational_plane_executable_family_v2.apl'),
	load_patterns('../Tools/APL_to_ACO_foundational_plane_executable_family_v2.apl'),
	set_v(ModelId, '1.0'),
	set_v(CaseId, n_mils_found_only),
	load_model_v(ModelId, _Policy, Platform, _Configuration),
	instantiate_pattern(n_foundational_plane,[Platform],CaseId),
	export_case(CaseId,txt),
	export_case(CaseId,html),
	detach_case
]).

proc(n_mils_op_only, [
	aco_apl('../Tools/APL_to_ACO_operational_plane_executable_family_v3.aco','../Tools/APL_to_ACO_operational_plane_executable_family_v3.apl'),
	load_patterns('../Tools/APL_to_ACO_operational_plane_executable_family_v3.apl'),
	set_v(ModelId, '1.0'),
	set_v(CaseId, n_mils_op_only),
	load_model_v(ModelId, Policy, _Platform, _Configuration),
	instantiate_pattern(n_operational_plane,[Policy],CaseId),
	export_case(CaseId,txt),
	export_case(CaseId,html),
	detach_case
]).

%%%%%%%%%%%%%%%
	
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

	aco_apl('../TEST/ACO/bio_v6d.aco', '../TEST/ACO/bio_v6d.apl'),
	load_patterns('../TEST/aco/bio_v6d.apl'),
	instantiate_pattern('BioAssist', [ ], bio6d),
	export_case(bio6d, txt),
	export_case(bio6d, html),
	detach_case,

	aco_apl('../TEST/ACO/bio_v7c.aco', '../TEST/ACO/bio_v7c.apl'),
	load_patterns('../TEST/aco/bio_v7c.apl'),
	instantiate_pattern('BioAssist', [ ], bio7c),
	export_case(bio7c, txt),
	export_case(bio7c, html),
	detach_case
	]).

%%%%%%%%%%
% Demonstration of ACO capabilities
%   run these in ETB command interpreter by typing, e.g.:  proc(op_plane_ACO, step). (step through with Return key)
%   only canonicalization is not demonstrated in these examples
% It is suggested to reset the REPOSITORY and CAP when repeating these examples. in ETB command mode type: reset.

proc(op_plane_ACO, [
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

proc(aco_tests, [
	shell('cat ../TEST/ACO/tiny_test.aco'),
	aco_tree('../TEST/ACO/tiny_test.aco'),
	aco_stats('../TEST/ACO/tiny_test.aco'),

	shell('cat ../TEST/ACO/tiny_multi.aco'),
	aco_tree('../TEST/ACO/tiny_multi.aco'),
	aco_stats('../TEST/ACO/tiny_multi.aco'),

	shell('cat ../TEST/ACO/tiny_multi5.aco'),
	aco_tree('../TEST/ACO/tiny_multi5.aco'),
	aco_stats('../TEST/ACO/tiny_multi5.aco'),

	shell('cat ../TEST/ACO/op_plane.aco'),
	aco_tree('../TEST/ACO/op_plane.aco'),
	aco_stats('../TEST/ACO/op_plane.aco')
	]).

%%%%%%%%%%

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

%%%%%%%%%%%%%% FINAL REVIEW MARCH 2026

proc(rev_demo_mod, [
	% reset,
	aco_modularize(['G1','G11','G51'], '../TEST/ACO/bio_v6d.aco', '../TEST/ACO/bio_v7t.aco'),
	aco_apl('../TEST/ACO/bio_v7t.aco', '../TEST/ACO/bio_v7t.apl'),
	load_patterns('../TEST/ACO/bio_v7t.apl'),
	instantiate_pattern('BioAssist', [], bio7t),
	export_case(bio7t,txt),
	export_case(bio7t,html),
	export_case(bio7t90,html90),
	detach_case
	]).

proc(rev_demo_aco, [
	shell('cat ../TEST/ACO/tiny_test.aco'),
	aco_tree('../TEST/ACO/tiny_test.aco'),
	aco_stats('../TEST/ACO/tiny_test.aco'),

	shell('cat ../TEST/ACO/tiny_multi.aco'),
	aco_tree('../TEST/ACO/tiny_multi.aco'),
	aco_stats('../TEST/ACO/tiny_multi.aco'),

	shell('cat ../TEST/ACO/tiny_multi5.aco'),
	aco_tree('../TEST/ACO/tiny_multi5.aco'),
	aco_stats('../TEST/ACO/tiny_multi5.aco'),

	shell('cat ../TEST/ACO/op_plane.aco'),
	aco_tree('../TEST/aco/op_plane.aco'),
	aco_stats('../TEST/aco/op_plane.aco'),
	aco_tree('../TEST/aco/op_plane.aco', [skeleton])
	]).
		
proc(rev_demo_etb, [
	reset,
	show_pattern(person),
	instantiate_pattern(person, [marius,programming], person_example),
	export_case(person_example,txt),
	export_case(person_example,html),
	detach_case,

	show_pattern(teamOfN),
	instantiate_pattern(teamOfN, [programming, list([marius,rance])], team_example),
	export_case(team_example, txt),
	export_case(team_example, html),
	detach_case,

	shell('cat ../TEST/ACO/op_plane.aco'),
	aco_apl('../TEST/ACO/op_plane.aco', '../TEST/ACO/op_plane.apl'),
	load_patterns('../TEST/ACO/op_plane.apl'),
	show_pattern('Op_Plane'),
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

	aco_apl('../TEST/ACO/bio_v6d.aco', '../TEST/ACO/bio_v6d.apl'),
	load_patterns('../TEST/aco/bio_v6d.apl'),
	instantiate_pattern('BioAssist', [ ], bio6d),
	export_case(bio6d, txt),
	export_case(bio6d, html),
	detach_case,

	aco_apl('../TEST/ACO/bio_v7c.aco', '../TEST/ACO/bio_v7c.apl'),
	load_patterns('../TEST/aco/bio_v7c.apl'),
	instantiate_pattern('BioAssist', [ ], bio7c),
	export_case(bio7c, txt),
	export_case(bio7c, html),
	detach_case
	]).

%%%%%%%%%%%%%% DEMO DAY JULY 2025

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

%%%%%%%%%%%%%% MONTH 18 REVIEW

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

%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%
% CANONICAL EXAMPLES
%
% Results of the following procs are maintained in the CAP by the makefile clean_cap target
% The generated txt and html exports for each case are maintained as examples.
% The procs can be re-run to regenerate the example outputs after a reset.
% If the procs or anything they are dependent upon (e.g. model, patterns, etc.)
% are modified the procs should be re-run to regenerate the CAP outputs.

%%%%%%%%%%
% IoMT_case and ISO_case build iomt_system_example and iso_system_example respectively
%
%   From patterns in KB/PATTERNS/patterns_IoMT.pl create the following Canonical Examples
%     iomt_system_example/ and iomt_system_example.txt

proc('IoMT_case', [
	set_v(ModelId, '2.0'),
	set_v(CaseId, x_iomt_system_example),
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

%   From patterns in KB/PATTERNS/patterns_MS_Risk.pl creatd the following Canonical Examples
%     iso_system_example/ and iso_system_example.txt

proc('ISO_case', [
	set_v(ModelId, '2.0'),
	set_v(CaseId, x_iso_system_example),
	load_model_v(ModelId, App_Specification, Platform, _Configuration),
        instantiate_pattern('MS_generic_risk_based',['hit-spec',App_Specification,Platform],CaseId),
	export_case(CaseId,txt),
	export_case(CaseId,html),
	detach_case
    ]).

%%%%%%%%%%

% mils_system_inst builds the complete mils_system_example using instantiate_pattern_list/2
% mils_found_only builds only the MILS foundational plane example using instante_pattern/3
% mils_op_only builds only the MILS operational plane example using instante_pattern/3
%
%   From patterns in KB/PATTERNS/patterns_MILS.pl the MILS Canonical Examples following
%   create in CAP the following txt and html case exports:
%     iomt_system_example/ and iomt_system_example.txt
%     iso_system_example/ and iso_system_example.txt
%     mils_system_example/ and mils_system_example.txt
%     mils_found_only/ and mils_found_only.txt
%     mils_op_only/ and mils_op_only.txt


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
	export_case(CaseId,txt),
	export_case(CaseId,html),
	detach_case
]).

% mils_found_only isolates the foundational plane portion of the mils_system_example

proc(mils_found_only, [
	set_v(ModelId, '1.0'),
	set_v(CaseId, mils_found_only),
	load_model_v(ModelId, _Policy, Platform, _Configuration),
	instantiate_pattern(foundational_plane,[Platform],CaseId),
	export_case(CaseId,txt),
	export_case(CaseId,html),
	detach_case
]).

% mils_op_only isolates the operational plane portion of the mils_system_example

proc(mils_op_only, [
	set_v(ModelId, '1.0'),
	set_v(CaseId, mils_op_only),
	load_model_v(ModelId, Policy, _Platform, _Configuration),
	instantiate_pattern(operational_plane,[Policy],CaseId),
	export_case(CaseId,txt),
	export_case(CaseId,html),
	detach_case
]).

