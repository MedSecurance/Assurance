
				%
				% patterns defined in annexes to ISO 81001-2-1
				%

				%
				%
				% generic risk based assurance case pattern
				%
				%


ac_pattern('generic_risk_based',
	   [arg('HIT',system:arch)],
	   goal(g1, 'G1: {HIT} Safety - Health IT is safe to use in defined care setting',
		[context('Con1: Case Setting - Case setting definition and description'),
		 context('Con2: {HIT} - HIT specification')
		],
		[strategy('S1: Risk Management - Argument based on adherence to \c
			 national risk management process standard',
			  iterate('N', hit_platform:node, nodes('HIT')),
			  [justification('J1: Effective Process - Risk management \c
				standard mandated and approved by the HDO')],
			  [ac_pattern_ref('residual_risk', ['HIT', 'N'])])
		])).

ac_pattern('residual_risk',
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
					        ac_pattern_ref('acceptable_risk',['H','HIT']),
					        ac_pattern_ref('accepted_risk',['H','HIT']) ] )
					])) 
			])).

ac_pattern('acceptable_risk',
		[arg('H',system:hazard), arg('HIT',system:arch)],
		goal(g1_1_1, 'G1.1.1: Acceptable risk - Residual risk of hazard {H} has been \c
			 controlled to an acceptable level in {HIT}',
			[],
			[evidence(hazard_log,'Soln 1.1.1.1 - Hazard log identifies risk assessment',[])
			])).

ac_pattern('accepted_risk',
		[arg('H',system:hazard), arg('HIT',system:arch)],
		goal(g1_1_2, 'G1.1.2: Accepted risk - Clinical benefits outweigh residual risk \c
			 of hazard {H} where further risk control is not practicable in {HIT}',
			[],
			[evidence(hazard_log,'Soln 1.1.2.1 - Hazard log identifies risk assessment',[]),
			 evidence(risk_acceptance,'Authority accepts risk of hazard {H} in {HIT}',[])
			])).
