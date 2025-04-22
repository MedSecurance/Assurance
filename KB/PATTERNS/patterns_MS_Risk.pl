				%
                                % MS_ are MedSecurance versions of ISO Risk-based patterns
				%

ac_pattern('MS_generic_risk_based',
	   [arg('HIT',hit_system:specification),
	    arg('App_Spec',application_plane:specification),
	    arg('Platform',platform_plane:platform)],
	   goal(g1, 'G1: {HIT} Safety - Health IT is safe to use in defined care setting',
		[context('Con1: Care Setting - Care setting definition and description'),
		 context('Con2: {HIT} - HIT specification')
		],
		[strategy('S1: Risk Management - Argument based on adherence to \c
			 ISO 80001-1 risk management process standard',
			  iterate('N', platform:node, nodes('Platform')),
			  [justification('J1: Effective Process - ISO 80001-1 \c
				is an internationally published standard')],
			  [ac_pattern_ref('MS_residual_risk1', ['HIT', 'N'])])
		])).

ac_pattern('MS_residual_risk1',
		[arg('HIT',hit_system:specification), arg('Node',platform:node)],
		goal(g1_1, 'G1.1: Residual risk - risk to node {Node} of {HIT} is tolerated',
			[context('Con3: Risk Criteria - Criteria used to classify, evaluate and accept risk'),
			 context('Con4: Tolerable Risk - Risk meeting criteria (acceptable) or \c
				outweighed by clinical benefit (accepted)')
			],
			[strategy('for every identified hazard',
				iterate('H', system:hazard, hazards('HIT')), [],
				[goal(g1_1_1, 'Risk of hazard {H} is acceptable/accepted in node {Node}', [],
					[evidence(hazard_log,'{Node} Hazard log identifies {H} risk assessment',[])
					])
				]) 
			])).

ac_pattern('MS_residual_risk',
		[arg('HIT',system:arch)],
		goal(g1_1, 'G1.1: Residual risk - Residual risk of all identified hazards is tolerated',
			[context('Con3: Risk Criteria - Criteria used to classify, evaluate and accept risk'),
			 context('Con4: Tolerable Risk - Risk meeting criteria (acceptable) or \c
				outweighed by clinical benefit (accepted)')
			],
			[strategy('for every identified hazard',
				iterate('H', system:hazard, hazards('HIT')), [],
				goal(g1_1_1, 'Risk of {H} is acceptable/accepted in {HIT}', [],
					[alternatives( [ % NEW alternative subgoals construct
					        ac_pattern_ref('MS_acceptable_risk',['H','HIT']),
					        ac_pattern_ref('MS_accepted_risk',['H','HIT']) ] )
					])) 
			])).

ac_pattern('MS_acceptable_risk',
		[arg('H',system:hazard), arg('HIT',system:arch)],
		goal(g1_1_1, 'G1.1.1: Acceptable risk - Residual risk of hazard {H} has been \c
			 controlled to an acceptable level in {HIT}',
			[],
			[evidence(hazard_log,'Soln 1.1.1.1 - Hazard log identifies risk assessment',[])
			])).

ac_pattern('MS_accepted_risk',
		[arg('H',system:hazard), arg('HIT',system:arch)],
		goal(g1_1_2, 'G1.1.2: Accepted risk - Clinical benefits outweigh residual risk \c
			 of hazard {H} where further risk control is not practicable in {HIT}',
			[],
			[evidence(hazard_log,'Soln 1.1.2.1 - Hazard log identifies risk assessment',[]),
			 evidence(risk_acceptance,'Authority accepts risk of hazard {H} in {HIT}',[])
			])).
