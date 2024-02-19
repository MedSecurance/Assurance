
				%
				% the patterns collection (examples)
				%

:-module(patterns, [ ac_pattern/3 ]).

				%
				%
				% foundational plane pattern
				%
				%

:- multifile ac_pattern/3.

ac_pattern('foundational_plane',
	   [arg('S', foundational_plane:platform)],
	   goal(g0, 'The foundational plane guarantees the local policy is met',
		[context('The adaptive MILS system model describes the plane')],
		[strategy('Argument over the desired behavior and requirements \c
			 of each MILS platform node',
			  iterate('N', foundational_plane:node, nodes('S')),
			  [],
			  [ac_pattern_ref('foundational_plane_node', ['S', 'N'])]),
		 ac_pattern_ref('foundational_plane_nsm', ['S']),
		 ac_pattern_ref('foundational_plane_tsn', ['S'])
		])).

ac_pattern('foundational_plane_node',
	   [arg('S', foundational_plane:platform), arg('N', foundational_plane:node)],
	   goal(g0, 'The platform node meets the requirements stated in the \c
	       local policy', [],
	       [strategy('Argument over desired behaviour and requirements of \c
			each SK instance', [],
			[goal(g1, 'Ensures complete data and processor time \c
			     partitioning per processor', [],
			     [goal(g11, 'Runtime resource constructors and destructors \c
				  ensure initialization function and low-leve primitives \c
				  to create and destroy resources, and the underlying \c
				  management of primitive resources', [],
				  [ goal(g4, 'CC evaluation of the separation kernel \c
					indicates compliance  to SKPP and is extended \c
					with the aforementioned subgoals', [],
					[ evidence(certificate, 'CC Evaluation certificate', [])])]),
			      goal(g12, 'The separation kernel provides runtime reconfiguration \c
				  primitives that permit an authorized subject to perform \c
				  reconfiguration changes', [],
				  [ goal_ref(g4) ]),
			      goal(g13, 'The separation kernel provides configuration \c
				  introspection primitives that permit an authorised subject \c
				  to obtain a representation of the current configuration', [],
				  [goal(g131, 'The configuration plane generates configuration \c
				       blueprints and low-level system configuration \c
				       properties that can be monitored at runtime from \c
				       high-level specifications of the bounds of safe and \c
				       secure operation and permissible configuration', [],
				       [ evidence(unknown, 'configuration blueprints', [])])])])]),
		strategy('Argument over desired behaviour and requirements of each MNS instance', [],
			 [goal(g2, 'Requirements of MNS instance are met', [], [])]) ])).

ac_pattern('foundational_plane_nsm',
	   [arg('S', foundational_plane:platform)],
	   goal(g0, 'A Network scheduling Master monitors and adapts the \c
	       network when network configuration change is necessary',
	       [ context('A rescheduling agent recomputes processor \c
			schedules for a proposed new configuration')],
	       [])).

ac_pattern('foundational_plane_tsn',
	   [arg('S', foundational_plane:platform)],
	   goal(g0, 'TSN ensures that critical information is delivered \c
	       timely and additionally optimises bandwidth by labelling \c
	       messages with different levels of priority', [],
	       [strategy('Argument over correct implementation of TSN',
			 [assumption('TSN configuration file is correct')],
			 [goal(g1, 'TSN supports the dynamic reconfiguration of \c
			      Adaptive-MILS system',
			      [assumption('TSN End system primitives are in place to \c
					 enhance dynamic reconfiguration'),
			      assumption('TSN switch primitives are in place to \c
					enhance dynamic reconfiguration')],
			      [strategy('Argument over TSN reconfiguration protocols', [],
					[goal(g11, 'A protocol is in place to collect \c
					     Adaptive-MILS reconfiguration requests', [],
					     [evidence(unknown, 'Formal verification results for \c
						      the reconfiguration request protocol', [])]),
					goal(g12, 'A protocol is inplace to distribute \c
					    new TSN schedules to dynamic MILS nodes', [],
					    [evidence(unknown, 'Formal verification results for \c
						     TSN schedule distribution protocol', [])])])]),
			 goal(g2, 'TSN configuration file is correctly \c
			     implemented by the hardware', [],
			     [goal(g21, 'The hardware is configured according to the \c
				  configuration files', [],
				  [goal(g211, 'Configuration data is downloaded into \c
				       end node controllers and switches over TSN network \c
				       from application on central workstation', [], [])])]),
			 goal(g3, 'Mechanisms in the network switches and \c
			     end-nodes dynamically add and remove links (runtime \c
			     configuration changes) whilst maintaining \c
			     availability and guaranteed real-time properties ', [],
			     [ goal(g31, 'A mechanisms is in place that safely requests \c
				   and distributes configuration data', [],[])]),
			 goal(g4, 'TSN ensures that only communications with \c
			     the implemented configuration occur', [],
			     [goal(g41, 'TSN network faulttolerant design ensures \c
				  consistency of communications', [],
				  [goal(g411, 'TSN switches and endpoints cards have \c
				       fault tolerant design',  [],
				       [goal(g4111, 'Incorrect frames cannot be generated', [],
					     [goal(g41111, 'All faulty frames are \c
						  intercepted by a monitor', [],
						  [ evidence(unknown, 'TSN high integrity switch design', []),
						    evidence(unknown, 'TSN high integrity endpoint \c
							    card design', [])] )]),
				       goal(g4112, 'The availability of frames is ensured \c
					   through path redundancy', [],
					   [evidence(unknown, 'TSN network design', [])])]),
				       goal(g412, 'Analysis of TSN network demonstrates \c
					   sufficiency of TSN fault tolerance', [],
					   [evidence(unknown, 'Results of network fault propagation \c
						    analysis', [])])]),
			     goal(g42, 'TSN ensures temporal behavior frames', [],
				  [goal(g421, 'Synchronized time is maintained in the \c
				       network even in the presence of failures', [],
				       [strategy('Argument over TSN synchronization protocols', [],
						 [goal(g4211, 'Permanence function ensures local \c
						      clocks of components are synchronised', [],
						      [evidence(unknown, 'Formal verification results for \c
							       permanence function', [])]),
						 goal(g4212, 'Clock-synchronisation protocol ensures \c
						     synchronised global time is maintained ', [],
						     [evidence(unknown, 'Formal verification results for \c
							      clock synchronization', [])]),
						 goal(g4213, 'Precision of the system is improved \c
						     by detecting and removing faulty TSN devices \c
						     from clock synchronisation', [],
						     [goal(g42131, 'Formal verification demonstrates the bound \c
							  of overall precision', [],
							  [evidence(unknown, 'Formal verification results', [])])])
						 ])])])])])])).

				%
				%
				% operational plane pattern
				%
				%
		     
ac_pattern('operational_plane', 
	   [arg('Policy', operational_plane:policy)],
	   goal(g0,
		'The operational plane guarantees that the {Policy} is met',
		[context('The Adaptive MILS system model describes \c
			the plane and the architecture, properties and \c
			local policy the plane')],
		[ac_pattern_ref('operational_plane_interface', ['Policy']),
		 goal(g1, 'Compositional behaviour of separate components \c
		     demonstrates to meet the local policy', [],
		     [ strategy('no. of components',
				iterate('Component', operational_plane:component, subjects('Policy')), [],
				[ ac_pattern_ref('operational_plane_process', ['Component', 'Policy'])])]),
		 goal(g2, 'Compositional behaviour of compositions \c
		     demonstrates to meet the local policy', [],
		     [ ac_pattern_ref('operational_plane_composition',
				      ['Policy'])])
		])).

ac_pattern('operational_plane_interface',
	   [arg('Policy', operational_plane:policy)],
	   goal(g0, 'Interactions of {Policy} are as defined by the policy architecture',
		[context('operational plane | composition')],
		[goal(g1, 'communication will occur over defined connections',
		      [context('connections are as specified in the {Policy} system model')],
		      [strategy('argument over the requirements that need to be satisfied \c
			       to guarantee communication will only occur over \c
			       defined connections',
			       iterate('Requirement', operational_plane:interface_requirement,
				       list(['availability', 'reliability'])), [],
				[goal(g11, 'specific {Requirement} of {Policy} are satisfied', [],
				      [evidence('unknown',
						'evidence of satisfaction of {Requirement} on {Policy}',
						[])])])]),
		 goal(g2, 'the defined connections are correctly implemented',
		      [context('communication is as specified in the {Policy} system model through dataflows')],
		      [goal(g21, 'all required connections are implemented',
			    [], [strategy('argument over connections specified in the system model',
					  iterate('Flow', operational_plane:flow, ss_flows('Policy')), [],
					  [goal(g211, 'The {Flow} connection is implemented', [],
						[evidence('unknown', 'Nodes and network configuration', [])])])]),
		       goal(g22, 'no additional connections are implemented',
			    [], [evidence('unknown', 'Nodes and network configuration', [])])])])).

ac_pattern('operational_plane_process',
	   [arg('Component', operational_plane:component),
	    arg('Policy', operational_plane:policy)],
	   goal(g0, 'component {Component} enforces its local policy',
		[context('component {Component} is defined through its local policy and architecture')],
		[goal(g1, 'Local policy is realized through the design of the component', [],
		      [ac_pattern_ref('operational_plane_process_modes_and_transitions', ['Component', 'Policy'])]),
		 ac_pattern_ref('operational_plane_process_threats', ['Component', 'Policy']),
		 ac_pattern_ref('operational_plane_process_properties', ['Component', 'Policy'])])).
	  
ac_pattern('operational_plane_process_modes_and_transitions',
	   [arg('Component', operational_plane:component),
	    arg('Policy', operational_plane:policy)],
	   goal(g0, 'The desired behavior of {Component} is realised through \c
	       conformance to the accepted modes and transitions',
	       [context('The behavior of {Composition} is specified in the system model')],
		[goal(g1, '{Component} will only be transitioned to specific modes \c
		     by satisfying the requirements of defined modes',
		     [context('specification of modes')],
		      [strategy('no. of modes',
				iterate('Mode', operational_plane:component_mode,
					modes('Component')), [],
				[goal(g11, 'specific requirements of {Mode} are satisfied', [],
				      [evidence('unknown',
						'evidence of satisfaction of the mode requirements', [])])])]),
		 goal(g2, '{Component} will transition according to the specified \c
		     transitions and perform correct error behavior',
		     [context('specification of transitions')],
		      [strategy('no. of transitions',
				iterate('Transition', operational_plane:component_transition,
					transitions('Component')), [],
				[goal(g21, 'specific requirments of {Transition} are satisfied', [],
				      [evidence('unknown',
						'evidence of satisfaction of mode transition requirements',[])]),
				 goal(g22, '{Component} performs appropriate error \c
				     behaviour in case of occurrence of errors during transitions',
				     [context('specification of appropriate error behavior')],
				      [evidence('unknown',
						'evidence of satisfactory error behavior during errors',[])])])])])).

ac_pattern('operational_plane_process_threats',
	   [arg('Component', operational_plane:component),
	    arg('Policy', operational_plane:policy)],
	   goal(g0, 'Threats on {Component} will not affect \c
	       the performance or consistency of communications',
	       [context('Defined threats for {Component}')],
		[strategy('argument over mitigation of identified threats',
			  iterate('Threat', operational_plane:process_threat,
				% eventually, threats shall be provided as annotations of 
				% components / system and therefore extracted from the system model 
				  list(['Technical failure', 'Unauthorised action'])), [], 
			  [goal(g1, '{Threat} is mitigated for {Component}', [],
				[evidence('unknown', '{Threat} specific mitigation', []),
				 evidence('unknown', 'Evidence that controls are in place', [])])]),
		 goal(g2, 'The identified threats for {Component} is complete', [], [])])).

ac_pattern('operational_plane_process_properties',
	   [arg('Component', operational_plane:component),
	    arg('Policy', operational_plane:policy)],
	   goal(g0, 'Properties required on the Adaptive MILS platform \c
	       by {Component} in order to enforce its local policy are assured', [], [])).

ac_pattern('operational_plane_composition',
	   [arg('Policy', operational_plane:policy)],
	   goal(g0, 'The composition guarantess that {Policy} is met',
		[context('The composition is defined through the local policy, parameters and properties')],
		[goal(g1, 'compositional behavior of the components \c
		     demonstrates to meet the local policy', [],
		     [strategy('no. of components',
			       iterate('Component', operational_plane:component, subjects('Policy')), [],
			       [ ac_pattern_ref('operational_plane_process', ['Component', 'Policy'])])]),
		 ac_pattern_ref('operational_plane_interface', ['Policy'])])).

				%
				%
				% person pattern
				%
				%

ac_pattern('person',
	   [ arg('P', person:participant), arg('A', person:activity) ],
	   goal(g0, '{P} is sufficiently trustworthy', [],
		[ goal(g1, '{P} has the necessary  attributes to perform {A}', [],
		       [strategy('argument over attributes',
				 iterate('T', person:attribute, list(['capability', 'experience'])), [], 
				 [ goal(g11, '{P} has sufficient {T} to perform {A}', [],
					[evidence(certificate, '{P} {T} for {A}', [])])
				 ])
		       ]),
		  goal(g2, '{P} has sufficient level of supervision and review \c
		      to successfully perform {A}', [],
		       [])
		])).



ac_pattern('invariant_property',
	   [ arg('M', model:id), arg('P', property:id)],
	   goal(g0, 'Model {M} satisfies invariant property {P}', [],
		[evidence(ichecker, 'formal validation using ichecker', [])])).