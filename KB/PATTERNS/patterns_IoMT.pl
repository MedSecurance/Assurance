
				%
				% MedSecurance patterns catalog (developmental/experimental)
				%

				%
				% TVRA patterns
				%

				%
				% team patterns
				%


ac_pattern('programming_teamN',
	[arg('Qualifications', team:qualifications),
	 arg('Members', team:members)],
	goal(g0, 'The members of the programming team possess the necessary qualifications',
		[context('IoMT system')],
		[goal(g1, 'all members meet specified qualifications', [],
			[strategy('no. of members',
				iterate('Member', team:member, '{Members}'),
				[],
				[ ac_pattern_ref('person', ['{Member}','{Qualifications}'])])
			]
		 )]
	    )
	).


ac_pattern('qualified_person',
	[arg('Qualification', person:activity),
	 arg('Person', person:participant)
	],
	goal(g0, 'The ability to perform the activity {Qualification} is possessed by the person {Person}',
		[],
		[goal(g1, 'the person is qualified to do {Qualification}', [],
			[strategy('establish the {Person} exists and is qualified to do the activity',
				[],
				[ ac_pattern_ref('person', ['Person','Qualification'])])
			]
		 )]
		)
	).


ac_pattern('teamOf2',
	[arg('Qualification', person:activity)
 	],
	goal(g0, 'The programming team possesses the necessary qualifications',
		[context('IoMT system')],
		[goal(g1, 'all team members meet specified qualification: {Qualification}', [],
			[strategy('establish qualification for both members',
				iterate( 'TeamMember', person:participant, list(['Marius','Rance']) ),
				[],
				[ ac_pattern_ref('person', ['TeamMember','Qualification'])])
			]
		)]
	)
).


ac_pattern('teamOfN',
	[arg('Qualification', person:activity), arg('TeamMembers', list(person:participant))
 	],
	goal(g0, 'The programming team possesses the necessary qualifications',
		[context('IoMT system')],
		[goal(g1, 'all members meet specified qualification: {Qualification}', [],
			[strategy('establish qualification for all members',
				iterate( 'TeamMember', person:participant, '{TeamMembers}'),
				[],
				[ ac_pattern_ref('person', ['TeamMember','Qualification'])])
			]
		)]
	)
).


%
% IoMT system patterns
%

ac_pattern('IoMT_system',
       [arg('App_Spec', application_plane:specification),
        arg('Platform_Spec', platform_plane:platform)
       ],
       goal(g0, 'The IoMT system satisfies its required properties',
            [context('The system is defined by the specifications \c
                     of its application plane and its platform plane ')],
            [strategy('The IoMT system depends on the synergy between \c
                      the platform and the application planes', [],
                      [goal(g1, 'The application plane behaves according to its \c
                            specification and required properties', [],
                            [ac_pattern_ref('application_plane', ['App_Spec'])] ),
                       goal(g2, 'The platform plane guarantees the properties \c
                           on which the application plane depends', [],
                           [ac_pattern_ref('platform_plane', ['Platform_Spec'])])
                      ]
                )
            ]
       )
).


ac_pattern('platform_plane',
       [arg('P', platform_plane:platform)],
       goal(g0, 'The platform plane guarantees that the platform properties \c
            and the application plane assumptions are met',
        [context('The IoMT system model describes the plane')],
        [strategy('Argument over the desired behavior and requirements \c
             of each IoMT platform node',
              iterate('N', platform_plane:node, nodes('P')),
              [],
              [ac_pattern_ref('platform_plane_node', ['P', 'N'])]),
         ac_pattern_ref('platform_plane_TS_network', ['P'])
        ])).

ac_pattern('platform_plane_node',
       [arg('P', platform_plane:platform), arg('N', platform_plane:node)],
       goal(g0, 'The platform node {N} meets the requirements stated in the \c
           local requirements', [],
           [strategy('Argument over desired behaviour and requirements of \c
            each node OS', [],
            [goal(g1, 'Node OS ensures data separation and fair processor time \c
                 scheduling per processor', [],
                 [goal(g11, 'Runtime resource constructors and destructors \c
                  ensure initialization function and low-level primitives \c
                  to create and destroy resources, and the underlying \c
                  allocation and management of primitive resources', [],
                  [ goal(g4, 'CC evaluation of the operating system \c
                    indicates compliance to the Protection Profile for \c
                    General Purpose Operating Systems and is extended \c
                    with the aforementioned subgoals', [],
                    [ evidence(certificate, 'CC Evaluation certificate', [])])]),
                  goal(g12, 'Node OS provides runtime reconfiguration \c
                  primitives that permit an authorized subject to perform \c
                  configuration changes', [],
                  [ goal_ref(g4) ]),
                  goal(g13, 'Node OS provides configuration \c
                  introspection primitives that permit an authorised subject \c
                  to obtain a representation of the current configuration', [],
                  [goal(g131, 'The configuration plane generates configuration \c
                       blueprints and low-level system configuration \c
                       properties that can be monitored at runtime from \c
                       high-level specifications of the bounds of safe and \c
                       secure operation and permissible configuration', [],
                       [ evidence(unknown, 'configuration blueprints', [])])])])]),
        strategy('Argument over desired behaviour and requirements of each \c
                 network software (NS) instance', [],
             [goal(g2, 'Requirements of NS instance are met', [], [])]) ])).

ac_pattern('platform_plane_TS_network',
       [arg('P', platform_plane:platform)],
       goal(g0, 'TS network (TSN) ensures that critical information is delivered \c
           timely and additionally optimises bandwidth by labelling \c
           messages with different levels of priority', [],
           [strategy('Argument over correct implementation of TSN',
             [assumption('TSN configuration file is correct')],
             [goal(g1, 'TSN supports the dynamic reconfiguration of \c
                  IoMT system',
                  [assumption('TSN End system primitives are in place to \c
                     enhance dynamic reconfiguration'),
                  assumption('TSN switch primitives are in place to \c
                    enhance dynamic reconfiguration')],
                  [strategy('Argument over TSN reconfiguration protocols', [],
                    [goal(g11, 'A protocol is in place to collect \c
                         IoMT reconfiguration requests', [],
                         [evidence(unknown, 'Verification results for \c
                              the reconfiguration request protocol', [])]),
                    goal(g12, 'A protocol is in place to distribute \c
                        new TSN schedules to platform nodes', [],
                        [evidence(unknown, 'Verification results for \c
                             TSN schedule distribution protocol', [])])])]),
             goal(g2, 'TSN configuration file is correctly \c
                 implemented by the hardware', [],
                 [goal(g21, 'The hardware is configured according to the \c
                  configuration files', [],
                  [goal(g211, 'Configuration data is downloaded into \c
                       platform node controllers and switches over TSN network \c
                       from application on central management', [], [])])]),
             goal(g3, 'Mechanisms in the network switches and \c
                 end-nodes dynamically add and remove links (runtime \c
                 configuration changes) whilst maintaining \c
                 availability and guaranteed time-sensitive properties ', [],
                 [ goal(g31, 'A mechanisms is in place that safely requests \c
                   and distributes configuration data', [],[])]),
             goal(g4, 'TSN ensures that only communications with \c
                 the implemented configuration occur', [],
                 [goal(g41, 'TSN network fault-tolerant design ensures \c
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
                             [goal(g42131, 'Verification demonstrates the bound \c
                              of overall precision', [],
                              [evidence(unknown, 'Verification results', [])])])
                         ])])])])])])).

ac_pattern('application_plane',
       [arg('App_Spec', application_plane:specification)],
       goal(g0,
        'The application plane guarantees that the {App_Spec} is met',
        [context('The IoMT system model describes \c
            the application plane and the architecture, properties and \c
            local specification of the plane')],
        [ac_pattern_ref('application_plane_interface', ['App_Spec']),
         goal(g1, 'Compositional behaviour of separate components \c
             demonstrated to meet the local specification', [],
             [ strategy('no. of processes',
                iterate('Process', application_plane:process, processes('App_Spec')), [],
                [ ac_pattern_ref('application_plane_process', ['Process', 'App_Spec'])])]),
         goal(g2, 'Compositional behaviour of compositions \c
             demonstrated to meet the local specification', [],
             [ ac_pattern_ref('application_plane_composition',
                      ['App_Spec'])])
        ])).

ac_pattern('application_plane_interface',
       [arg('App_Spec', application_plane:specification)],
       goal(g0, 'Interactions are as defined by the architecture spec {App_Spec}',
        [context('application plane | composition')],
        [goal(g1, 'communication occur only over defined connections',
              [context('connections are as specified in the {App_Spec} system model')],
              [strategy('argument over the requirements that need to be satisfied \c
                   to guarantee communication will only occur over \c
                   defined connections',
                   iterate('Requirement', application_plane:interface_requirement,
                       list(['availability', 'reliability'])), [],
                [goal(g11, 'specific {Requirement} of {App_Spec} are satisfied', [],
                      [evidence('unknown',
                        'evidence of satisfaction of {Requirement} on {App_Spec}',
                        [])])])]),
         goal(g2, 'the defined connections are correctly implemented',
              [context('communication is as specified in the {App_Spec} system model dataflows')],
              [goal(g21, 'all required connections are implemented',
                [], [strategy('argument over connections specified in the system model',
                      iterate('Flow', application_plane:flow, ipc_flows('App_Spec')), [],
                      [goal(g211, 'The {Flow} connection is implemented', [],
                        [evidence('unknown', 'Nodes and network configuration', [])])])]),
               goal(g22, 'no additional connections are implemented',
                [], [evidence('unknown', 'Nodes and network configuration', [])])])])).

ac_pattern('application_plane_process',
       [arg('Process', application_plane:process),
        arg('App_Spec', application_plane:specification)],
       goal(g0, 'process {Process} enforces its local spec',
        [context('process {Process} is defined through its local spec and architecture')],
        [goal(g1, 'Local spec is realized through the design of the component', [],
              [ac_pattern_ref('application_plane_process_modes_and_transitions', ['Process', 'App_Spec'])]),
         ac_pattern_ref('application_plane_process_threats', ['Process', 'App_Spec']),
         ac_pattern_ref('application_plane_process_properties', ['Process', 'App_Spec'])])).
      
ac_pattern('application_plane_process_modes_and_transitions',
       [arg('Process', application_plane:process),
        aarg('App_Spec', application_plane:specification)],
       goal(g0, 'The desired behavior of {Process} is realised through \c
           conformance to the accepted modes and transitions',
           [context('The behavior of {Composition} is specified in the system model')],
        [goal(g1, '{Process} will only be transitioned to specific modes \c
             by satisfying the requirements of defined modes',
             [context('specification of modes')],
              [strategy('no. of modes',
                iterate('Mode', application_plane:process_mode,
                    modes('Process')), [],
                [goal(g11, 'specific requirements of {Mode} are satisfied', [],
                      [evidence('unknown',
                        'evidence of satisfaction of the mode requirements', [])])])]),
         goal(g2, '{Process} will transition according to the specified \c
             transitions and perform correct error behavior',
             [context('specification of transitions')],
              [strategy('no. of transitions',
                iterate('Transition', application_plane:process_transition,
                    transitions('Process')), [],
                [goal(g21, 'specific requirments of {Transition} are satisfied', [],
                      [evidence('unknown',
                        'evidence of satisfaction of mode transition requirements',[])]),
                 goal(g22, '{Process} performs appropriate error \c
                     behaviour in case of occurrence of errors during transitions',
                     [context('specification of appropriate error behavior')],
                      [evidence('unknown',
                        'evidence of satisfactory error behavior during errors',[])])])])])).

ac_pattern('application_plane_process_threats',
       [arg('Process', application_plane:process),
        arg('App_Spec', application_plane:specification)],
       goal(g0, 'Threats on {Process} will not affect \c
           the performance or consistency of communications',
           [context('Defined threats for {Process}')],
        [strategy('argument over mitigation of identified threats',
              iterate('Threat', application_plane:process_threat,
                % eventually, threats shall be provided as annotations of
                % processes / system and therefore extracted from the system model
                  list(['Technical failure', 'Unauthorised action'])), [],
              [goal(g1, '{Threat} is mitigated for {Process}', [],
                [evidence('unknown', '{Threat} specific mitigation', []),
                 evidence('unknown', 'Evidence that controls are in place', [])])]),
         goal(g2, 'The identified threats for {Process} are complete', [], [])])).

ac_pattern('application_plane_process_properties',
       [arg('Process', application_plane:process),
        arg('App_Spec', application_plane:specification)],
       goal(g0, 'Properties required of the IoMT platform \c
           by {Process} in order to satisfy its specification are assured', [], [])).

ac_pattern('application_plane_composition',
       [arg('App_Spec', application_plane:specification)],
       goal(g0, 'The composition guarantess that {App_Spec} is satisfied',
        [context('The composition is defined through the local specification, parameters and properties')],
        [goal(g1, 'compositional behavior of the processes \c
             satisfies the local specification', [],
             [strategy('no. of processes',
                   iterate('Process', application_plane:process, processes('App_Spec')), [],
                   [ ac_pattern_ref('application_plane_process', ['Process', 'App_Spec'])])]),
         ac_pattern_ref('application_plane_interface', ['App_Spec'])])).

