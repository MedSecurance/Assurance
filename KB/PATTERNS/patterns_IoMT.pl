
				%
				% the MedSecurance patterns collection (experimental)
				%

				%
				% TVRA patterns
				%


				%
				%
				% people patterns
				%
				%
/*
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
*/

ac_pattern('programming_teamN',
	[arg('Qualifications', team:qualifications),
	 arg('Members', team:members)],
	goal(g0, 'The members of the programming team possess the necessary qualifications',
		[context('IoMT system')],
		[goal(g1, 'all members meet specified qualifications', [],
			[strategy('no. of members',
				iterate('Member', team:member, '{Members}'),
				[],
				[ ac_pattern_ref('person', ['Member','{Qualifications}'])])
			]
		 )]
	    )
	).


ac_pattern('qualified_person',
	[arg('Qualification', person:activity),
	 arg('Person', person:participant)
	],
	goal(g0, 'The programming team possesses the necessary qualifications',
		[context('IoMT system')],
		[goal(g1, 'all members meet specified qualification {Qualification}', [],
			[strategy('establish qualification for the person to do activity',
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
		[goal(g1, 'both members meet specified qualification: {Qualification}', [],
			[strategy('establish qualification for all members',
				iterate( 'Member', person:participant, 'TeamMembers'),
				[],
				[ ac_pattern_ref('person', ['Member','Qualification'])])
			]
		)]
	)
).
