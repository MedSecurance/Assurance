
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


ac_pattern('programming_team2',
	[arg('Qualifications', team:qualifications),
	 arg('Members', team:members)],
	goal(g0, 'The members of the programming team possess the necessary qualifications',
		[context('IoMT system')],
		[goal(g1, 'all members meet specified qualifications', [],
			[strategy('no. of members',
				iterate( 'Member', team:member, list('{Members}') ),
				[],
				[ ac_pattern_ref('person', ['Member','{Qualifications}'])])
			]
		 )]
		)
	).
	