%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%
% ETB self_test
etb_startup_tests([tc01, tc02, tc03
		   ]).
etb_regression_tests([ % tc_meta00
		     ]).

self_test :-
	etb_startup_tests(Tests),
	forall( member(T,Tests),
	        (       param:verbose(V), param:setparam(verbose,off),
                        test:report_test(etb:T),
                        param:setparam(verbose,V)
                )
              ).

regression_test :-
	etb_startup_tests(Startup),
	etb_regression_tests(Regression),
	append(Startup,Regression,AllTests),
	forall(member(T,AllTests), test:report_test(etb:T)).

%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%
% experimental

run_tests_safe([]).
run_tests_safe([TC|TCs]) :-
	setup_call_cleanup(
		true,
		run_single_test(TC),
		safe_detach_repository),
	run_tests_safe(TCs).

run_single_test(TC) :-
	test:report_test(TC),
	call(TC).

safe_detach_repository :-
	catch( detach_assurance_repository, _, true).

tc_translate_aco_string_to_apl_terms(AcoString, AplTerms) :-
	aco_processor:translate_aco_string(
		'<test>',
		AcoString,
		AplTerms,
		Messages),
	aco_processor:print_messages(Messages),
	(   member(Msg, Messages),
		Msg = message(error, _, _)
	->  throw(error(aco_translation_failed, _))
	;   true).

tc_write_apl_terms_to_temp_file(AplTerms, File) :-
	tmp_file_stream(text, File, Stream),
	forall(member(Term, AplTerms),
			( write_term(Stream, Term, [fullstop(true)]),
				nl(Stream)
			)),
	close(Stream).

%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%
% Test cases, test passes if tcxx goal succeeds

% Baseline
tc_meta00 :-
	assurance:reset_assurance_repository,
    AcoString = "
Case: META_BASELINE
Goal: G1
  Evidence: E1
    Tool: demo_tool
    evidence-category: analysis
    xref: DEMO-1
    This is a simple evidence description.
",
    tc_translate_aco_string_to_apl_terms(AcoString, AplTerms),
    tc_write_apl_terms_to_temp_file(AplTerms, AplFile),
    load_patterns(AplFile),
    instantiate_pattern('META_BASELINE', [], meta00),
    export:ac_string(Result),
    assurance:detach_assurance_repository,

	Expected="=== ACO summary ===
	Total nodes: 0
	  Goals:          0 (undeveloped: 0)
	  Strategies:     0
	  Contexts:       0 (tree: 0, relation: 0)
	  Assumptions:    0
	  Justifications: 0
	  Evidence:       0
	  Modules:        0 (undeveloped: 0)
  
	supported_by edges:
	  from indentation (tree):  0
	  from explicit relations:  0
  
	in_context_of edges:
	  from indentation (tree):  0
	  from explicit relations:  0
  
	Cross-branch relations: 0
  ======================
  ",
  Result == Expected.

tc_meta01 :- true. % Metadata assertion test

% Instantiate pattern tests
%      instantiate_pattern(PatternName,PatternArgs,AssuranceCaseId)

tc01 :-
	assurance:reset_assurance_repository,
	instantiate_pattern(person, ['Marius', 'Programming'], 'person_ex1'),
	export:ac_string(Result),
	assurance:detach_assurance_repository,
	Expected='goal g0_1 : Marius is sufficiently trustworthy\n  goal g1_1 : Marius has the necessary attributes to perform Programming\n    strategy : argument over attributes\n      goal g11_1_k1 : Marius has sufficient capability to perform Programming\n        evidence certificate : Marius capability for Programming\n          status: ongoing, reference -> 10001\n      goal g11_1_k2 : Marius has sufficient experience to perform Programming\n        evidence certificate : Marius experience for Programming\n          status: ongoing, reference -> 10002\n  goal g2_1 : Marius has sufficient level of supervision and review to successfully perform Programming\n',
	Result == Expected.

tc02 :-
	assurance:reset_assurance_repository, % for repeatability
	instantiate_pattern(teamOfN, [programming, list([marius,rance])], team_ex1),
	export:ac_string(Result),
	assurance:detach_assurance_repository,
	Expected='goal g0_1 : The programming team possesses the necessary qualifications\n  context : IoMT system\n  goal g1_1 : all members meet specified qualification: programming\n    strategy : establish qualification for all members\n      module pr_1_1_k1 : person([TeamMember,Qualification])  -> person_g0_2\n      module pr_1_1_k2 : person([TeamMember,Qualification])  -> person_g0_3\ngoal g0_2 : marius is sufficiently trustworthy\n  goal g1_2 : marius has the necessary attributes to perform programming\n    strategy : argument over attributes\n      goal g11_2_k1 : marius has sufficient capability to perform programming\n        evidence certificate : marius capability for programming\n          status: ongoing, reference -> 10003\n      goal g11_2_k2 : marius has sufficient experience to perform programming\n        evidence certificate : marius experience for programming\n          status: ongoing, reference -> 10004\n  goal g2_2 : marius has sufficient level of supervision and review to successfully perform programming\ngoal g0_3 : rance is sufficiently trustworthy\n  goal g1_3 : rance has the necessary attributes to perform programming\n    strategy : argument over attributes\n      goal g11_3_k1 : rance has sufficient capability to perform programming\n        evidence certificate : rance capability for programming\n          status: ongoing, reference -> 10005\n      goal g11_3_k2 : rance has sufficient experience to perform programming\n        evidence certificate : rance experience for programming\n          status: ongoing, reference -> 10006\n  goal g2_3 : rance has sufficient level of supervision and review to successfully perform programming\n',
	Result == Expected.

tc03 :-
	assurance:reset_assurance_repository, % for repeatability
	model:load_model('2.0',M), M = model(App_Specification, Platform, _),
	instantiate_pattern_list([ 'IoMT_system'-[App_Specification, Platform],
			'person'-['Alicia', 'Assurance'],
			'person'-['Roberto', 'Development']
			], iomt_system_ex1),
	export:ac_string(Result),
	assurance:detach_assurance_repository,
	Expected='goal g0_1 : The IoMT system satisfies its required properties\n  context : The system is defined by the specifications of its application plane and its platform plane\n  strategy : The IoMT system depends on the synergy between the platform and the application planes\n    goal g1_1 : The application plane behaves according to its specification and required properties\n      module pr_1_1 : application_plane([App_Spec])  -> application_plane_g0_2\n    goal g2_1 : The platform plane guarantees the properties on which the application plane depends\n      module pr_2_1 : platform_plane([Platform_Spec])  -> platform_plane_g0_3\ngoal g0_2 : The application plane guarantees that the iomt_spec1 is met\n  context : The IoMT system model describes the application plane and the architecture, properties and local specification of the plane\n  module pr_1_2 : application_plane_interface([App_Spec])  -> application_plane_interface_g0_4\n  goal g1_2 : Compositional behaviour of separate components demonstrated to meet the local specification\n    strategy : no. of processes\n      module pr_2_2_k1 : application_plane_process([Process,App_Spec])  -> application_plane_process_g0_5\n      module pr_2_2_k2 : application_plane_process([Process,App_Spec])  -> application_plane_process_g0_6\n  goal g2_2 : Compositional behaviour of compositions demonstrated to meet the local specification\n    module pr_3_2 : application_plane_composition([App_Spec])  -> application_plane_composition_g0_7\ngoal g0_3 : The platform plane guarantees that the platform properties and the application plane assumptions are met\n  context : The IoMT system model describes the plane\n  strategy : Argument over the desired behavior and requirements of each IoMT platform node\n    module pr_1_3_k1 : platform_plane_node([P,N])  -> platform_plane_node_g0_8\n    module pr_1_3_k2 : platform_plane_node([P,N])  -> platform_plane_node_g0_9\n  module pr_2_3 : platform_plane_TS_network([P])  -> platform_plane_TS_network_g0_10\ngoal g0_4 : Interactions are as defined by the architecture spec iomt_spec1\n  context : application plane | composition\n  goal g1_4 : communication occur only over defined connections\n    context : connections are as specified in the iomt_spec1 system model\n    strategy : argument over the requirements that need to be satisfied to guarantee communication will only occur over defined connections\n      goal g11_4_k1 : specific availability of iomt_spec1 are satisfied\n        evidence unknown : evidence of satisfaction of availability on iomt_spec1\n          status: pending, reference -> 10007\n      goal g11_4_k2 : specific reliability of iomt_spec1 are satisfied\n        evidence unknown : evidence of satisfaction of reliability on iomt_spec1\n          status: pending, reference -> 10008\n  goal g2_4 : the defined connections are correctly implemented\n    context : communication is as specified in the iomt_spec1 system model dataflows\n    goal g21_4 : all required connections are implemented\n      strategy : argument over connections specified in the system model\n        goal g211_4_k1 : The p1p2 connection is implemented\n          evidence unknown : Nodes and network configuration\n            status: pending, reference -> 10009\n    goal g22_4 : no additional connections are implemented\n      evidence unknown : Nodes and network configuration\n        status: pending, reference -> 10010\ngoal g0_5 : process P1 enforces its local spec\n  context : process P1 is defined through its local spec and architecture\n  goal g1_5 : Local spec is realized through the design of the component\n    module pr_1_5 : application_plane_process_modes_and_transitions([Process,App_Spec])  [ARG_MISMATCH]  -> application_plane_process_modes_and_transitions_G_BADARGS\n  module pr_2_5 : application_plane_process_threats([Process,App_Spec])  -> application_plane_process_threats_g0_11\n  module pr_3_5 : application_plane_process_properties([Process,App_Spec])  -> application_plane_process_properties_g0_12\ngoal g0_6 : process P2 enforces its local spec\n  context : process P2 is defined through its local spec and architecture\n  goal g1_6 : Local spec is realized through the design of the component\n    module pr_1_6 : application_plane_process_modes_and_transitions([Process,App_Spec])  [ARG_MISMATCH]  -> application_plane_process_modes_and_transitions_G_BADARGS\n  module pr_2_6 : application_plane_process_threats([Process,App_Spec])  -> application_plane_process_threats_g0_13\n  module pr_3_6 : application_plane_process_properties([Process,App_Spec])  -> application_plane_process_properties_g0_14\ngoal g0_7 : The composition guarantess that iomt_spec1 is satisfied\n  context : The composition is defined through the local specification, parameters and properties\n  goal g1_7 : compositional behavior of the processes satisfies the local specification\n    strategy : no. of processes\n      module pr_1_7_k1 : application_plane_process([Process,App_Spec])  -> application_plane_process_g0_15\n      module pr_1_7_k2 : application_plane_process([Process,App_Spec])  -> application_plane_process_g0_16\n  module pr_2_7 : application_plane_interface([App_Spec])  -> application_plane_interface_g0_17\ngoal g0_8 : The platform node node1 meets the requirements stated in the local requirements\n  strategy : Argument over desired behaviour and requirements of each node OS\n    goal g1_8 : Node OS ensures data separation and fair processor time scheduling per processor\n      goal g11_8 : Runtime resource constructors and destructors ensure initialization function and low-level primitives to create and destroy resources, and the underlying allocation and management of primitive resources\n        goal g4_8 : CC evaluation of the operating system indicates compliance to the Protection Profile for General Purpose Operating Systems and is extended with the aforementioned subgoals\n          evidence certificate : CC Evaluation certificate\n            status: ongoing, reference -> 10011\n      goal g12_8 : Node OS provides runtime reconfiguration primitives that permit an authorized subject to perform configuration changes\n        goal -> g4_8\n      goal g13_8 : Node OS provides configuration introspection primitives that permit an authorised subject to obtain a representation of the current configuration\n        goal g131_8 : The configuration plane generates configuration blueprints and low-level system configuration properties that can be monitored at runtime from high-level specifications of the bounds of safe and secure operation and permissible configuration\n          evidence unknown : configuration blueprints\n            status: pending, reference -> 10012\n  strategy : Argument over desired behaviour and requirements of each network software (NS) instance\n    goal g2_8 : Requirements of NS instance are met\ngoal g0_9 : The platform node node2 meets the requirements stated in the local requirements\n  strategy : Argument over desired behaviour and requirements of each node OS\n    goal g1_9 : Node OS ensures data separation and fair processor time scheduling per processor\n      goal g11_9 : Runtime resource constructors and destructors ensure initialization function and low-level primitives to create and destroy resources, and the underlying allocation and management of primitive resources\n        goal g4_9 : CC evaluation of the operating system indicates compliance to the Protection Profile for General Purpose Operating Systems and is extended with the aforementioned subgoals\n          evidence certificate : CC Evaluation certificate\n            status: ongoing, reference -> 10013\n      goal g12_9 : Node OS provides runtime reconfiguration primitives that permit an authorized subject to perform configuration changes\n        goal -> g4_9\n      goal g13_9 : Node OS provides configuration introspection primitives that permit an authorised subject to obtain a representation of the current configuration\n        goal g131_9 : The configuration plane generates configuration blueprints and low-level system configuration properties that can be monitored at runtime from high-level specifications of the bounds of safe and secure operation and permissible configuration\n          evidence unknown : configuration blueprints\n            status: pending, reference -> 10014\n  strategy : Argument over desired behaviour and requirements of each network software (NS) instance\n    goal g2_9 : Requirements of NS instance are met\ngoal g0_10 : TS network (TSN) ensures that critical information is delivered timely and additionally optimises bandwidth by labelling messages with different levels of priority\n  strategy : Argument over correct implementation of TSN\n    assumption : TSN configuration file is correct\n    goal g1_10 : TSN supports the dynamic reconfiguration of IoMT system\n      assumption : TSN End system primitives are in place to enhance dynamic reconfiguration\n      assumption : TSN switch primitives are in place to enhance dynamic reconfiguration\n      strategy : Argument over TSN reconfiguration protocols\n        goal g11_10 : A protocol is in place to collect IoMT reconfiguration requests\n          evidence unknown : Verification results for the reconfiguration request protocol\n            status: pending, reference -> 10015\n        goal g12_10 : A protocol is in place to distribute new TSN schedules to platform nodes\n          evidence unknown : Verification results for TSN schedule distribution protocol\n            status: pending, reference -> 10016\n    goal g2_10 : TSN configuration file is correctly implemented by the hardware\n      goal g21_10 : The hardware is configured according to the configuration files\n        goal g211_10 : Configuration data is downloaded into platform node controllers and switches over TSN network from application on central management\n    goal g3_10 : Mechanisms in the network switches and end-nodes dynamically add and remove links (runtime configuration changes) whilst maintaining availability and guaranteed time-sensitive properties\n      goal g31_10 : A mechanisms is in place that safely requests and distributes configuration data\n    goal g4_10 : TSN ensures that only communications with the implemented configuration occur\n      goal g41_10 : TSN network fault-tolerant design ensures consistency of communications\n        goal g411_10 : TSN switches and endpoints cards have fault tolerant design\n          goal g4111_10 : Incorrect frames cannot be generated\n            goal g41111_10 : All faulty frames are intercepted by a monitor\n              evidence unknown : TSN high integrity switch design\n                status: pending, reference -> 10017\n              evidence unknown : TSN high integrity endpoint card design\n                status: pending, reference -> 10018\n          goal g4112_10 : The availability of frames is ensured through path redundancy\n            evidence unknown : TSN network design\n              status: pending, reference -> 10019\n        goal g412_10 : Analysis of TSN network demonstrates sufficiency of TSN fault tolerance\n          evidence unknown : Results of network fault propagation analysis\n            status: pending, reference -> 10020\n      goal g42_10 : TSN ensures temporal behavior frames\n        goal g421_10 : Synchronized time is maintained in the network even in the presence of failures\n          strategy : Argument over TSN synchronization protocols\n            goal g4211_10 : Permanence function ensures local clocks of components are synchronised\n              evidence unknown : Formal verification results for permanence function\n                status: pending, reference -> 10021\n            goal g4212_10 : Clock-synchronisation protocol ensures synchronised global time is maintained\n              evidence unknown : Formal verification results for clock synchronization\n                status: pending, reference -> 10022\n            goal g4213_10 : Precision of the system is improved by detecting and removing faulty TSN devices from clock synchronisation\n              goal g42131_10 : Verification demonstrates the bound of overall precision\n                evidence unknown : Verification results\n                  status: pending, reference -> 10023\ngoal g0_11 : Threats on P1 will not affect the performance or consistency of communications\n  context : Defined threats for P1\n  strategy : argument over mitigation of identified threats\n    goal g1_11_k1 : Technical failure is mitigated for P1\n      evidence unknown : Technical failure specific mitigation\n        status: pending, reference -> 10024\n      evidence unknown : Evidence that controls are in place\n        status: pending, reference -> 10025\n    goal g1_11_k2 : Unauthorised action is mitigated for P1\n      evidence unknown : Unauthorised action specific mitigation\n        status: pending, reference -> 10026\n      evidence unknown : Evidence that controls are in place\n        status: pending, reference -> 10027\n  goal g2_11 : The identified threats for P1 are complete\ngoal g0_12 : Properties required of the IoMT platform by P1 in order to satisfy its specification are assured\ngoal g0_13 : Threats on P2 will not affect the performance or consistency of communications\n  context : Defined threats for P2\n  strategy : argument over mitigation of identified threats\n    goal g1_13_k1 : Technical failure is mitigated for P2\n      evidence unknown : Technical failure specific mitigation\n        status: pending, reference -> 10028\n      evidence unknown : Evidence that controls are in place\n        status: pending, reference -> 10029\n    goal g1_13_k2 : Unauthorised action is mitigated for P2\n      evidence unknown : Unauthorised action specific mitigation\n        status: pending, reference -> 10030\n      evidence unknown : Evidence that controls are in place\n        status: pending, reference -> 10031\n  goal g2_13 : The identified threats for P2 are complete\ngoal g0_14 : Properties required of the IoMT platform by P2 in order to satisfy its specification are assured\ngoal g0_15 : process P1 enforces its local spec\n  context : process P1 is defined through its local spec and architecture\n  goal g1_15 : Local spec is realized through the design of the component\n    module pr_1_15 : application_plane_process_modes_and_transitions([Process,App_Spec])  [ARG_MISMATCH]  -> application_plane_process_modes_and_transitions_G_BADARGS\n  module pr_2_15 : application_plane_process_threats([Process,App_Spec])  -> application_plane_process_threats_g0_18\n  module pr_3_15 : application_plane_process_properties([Process,App_Spec])  -> application_plane_process_properties_g0_19\ngoal g0_16 : process P2 enforces its local spec\n  context : process P2 is defined through its local spec and architecture\n  goal g1_16 : Local spec is realized through the design of the component\n    module pr_1_16 : application_plane_process_modes_and_transitions([Process,App_Spec])  [ARG_MISMATCH]  -> application_plane_process_modes_and_transitions_G_BADARGS\n  module pr_2_16 : application_plane_process_threats([Process,App_Spec])  -> application_plane_process_threats_g0_20\n  module pr_3_16 : application_plane_process_properties([Process,App_Spec])  -> application_plane_process_properties_g0_21\ngoal g0_17 : Interactions are as defined by the architecture spec iomt_spec1\n  context : application plane | composition\n  goal g1_17 : communication occur only over defined connections\n    context : connections are as specified in the iomt_spec1 system model\n    strategy : argument over the requirements that need to be satisfied to guarantee communication will only occur over defined connections\n      goal g11_17_k1 : specific availability of iomt_spec1 are satisfied\n        evidence unknown : evidence of satisfaction of availability on iomt_spec1\n          status: pending, reference -> 10007\n      goal g11_17_k2 : specific reliability of iomt_spec1 are satisfied\n        evidence unknown : evidence of satisfaction of reliability on iomt_spec1\n          status: pending, reference -> 10008\n  goal g2_17 : the defined connections are correctly implemented\n    context : communication is as specified in the iomt_spec1 system model dataflows\n    goal g21_17 : all required connections are implemented\n      strategy : argument over connections specified in the system model\n        goal g211_17_k1 : The p1p2 connection is implemented\n          evidence unknown : Nodes and network configuration\n            status: pending, reference -> 10009\n    goal g22_17 : no additional connections are implemented\n      evidence unknown : Nodes and network configuration\n        status: pending, reference -> 10010\ngoal g0_18 : Threats on P1 will not affect the performance or consistency of communications\n  context : Defined threats for P1\n  strategy : argument over mitigation of identified threats\n    goal g1_18_k1 : Technical failure is mitigated for P1\n      evidence unknown : Technical failure specific mitigation\n        status: pending, reference -> 10024\n      evidence unknown : Evidence that controls are in place\n        status: pending, reference -> 10025\n    goal g1_18_k2 : Unauthorised action is mitigated for P1\n      evidence unknown : Unauthorised action specific mitigation\n        status: pending, reference -> 10026\n      evidence unknown : Evidence that controls are in place\n        status: pending, reference -> 10027\n  goal g2_18 : The identified threats for P1 are complete\ngoal g0_19 : Properties required of the IoMT platform by P1 in order to satisfy its specification are assured\ngoal g0_20 : Threats on P2 will not affect the performance or consistency of communications\n  context : Defined threats for P2\n  strategy : argument over mitigation of identified threats\n    goal g1_20_k1 : Technical failure is mitigated for P2\n      evidence unknown : Technical failure specific mitigation\n        status: pending, reference -> 10028\n      evidence unknown : Evidence that controls are in place\n        status: pending, reference -> 10029\n    goal g1_20_k2 : Unauthorised action is mitigated for P2\n      evidence unknown : Unauthorised action specific mitigation\n        status: pending, reference -> 10030\n      evidence unknown : Evidence that controls are in place\n        status: pending, reference -> 10031\n  goal g2_20 : The identified threats for P2 are complete\ngoal g0_21 : Properties required of the IoMT platform by P2 in order to satisfy its specification are assured\ngoal g0_22 : Alicia is sufficiently trustworthy\n  goal g1_22 : Alicia has the necessary attributes to perform Assurance\n    strategy : argument over attributes\n      goal g11_22_k1 : Alicia has sufficient capability to perform Assurance\n        evidence certificate : Alicia capability for Assurance\n          status: ongoing, reference -> 10032\n      goal g11_22_k2 : Alicia has sufficient experience to perform Assurance\n        evidence certificate : Alicia experience for Assurance\n          status: ongoing, reference -> 10033\n  goal g2_22 : Alicia has sufficient level of supervision and review to successfully perform Assurance\ngoal g0_23 : Roberto is sufficiently trustworthy\n  goal g1_23 : Roberto has the necessary attributes to perform Development\n    strategy : argument over attributes\n      goal g11_23_k1 : Roberto has sufficient capability to perform Development\n        evidence certificate : Roberto capability for Development\n          status: ongoing, reference -> 10034\n      goal g11_23_k2 : Roberto has sufficient experience to perform Development\n        evidence certificate : Roberto experience for Development\n          status: ongoing, reference -> 10035\n  goal g2_23 : Roberto has sufficient level of supervision and review to successfully perform Development\n',
	Result == Expected.


% ...
