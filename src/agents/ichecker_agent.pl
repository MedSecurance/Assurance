:- module(ichecker_agent, [ichecker_validate/5]).

ichecker_validate(_Claim, _Context, AArgs, XRef, Status) :-

	format('~n*** running ichecker agent...', []),
	
				% get the evidence placeholder
	atomic_list_concat(['evidence/ichecker/', XRef], Repository),
	
				% get the actual arguments
	member( arg(_, model:id, ModelId), AArgs),
	member( arg(_, property:id, PropertyId), AArgs),
	
				% copy the BIP model to the evidence repository
	atomic_list_concat( [ 'models/', ModelId, '/system.bip' ], BipFilename),
	copy_file(BipFilename, Repository),
		
				% copy the property to the evidence repository
	atomic_list_concat( [ 'models/', ModelId, '/properties/', PropertyId, '.pro'], PropertyFilename),
	copy_file(PropertyFilename, Repository),

				% copy the invariant specification to the evidence repository
	atomic_list_concat( [ 'models/', ModelId, '/system-invariants.inv'], InvFilename),
	copy_file(InvFilename, Repository),
	
				% run ichecker
	atomic_list_concat( [ PropertyId, '.pro'], PropertyId_Pro),
	
	process_create('/home/bozga/bip2dev/IFinder/ujf.verimag.bip.ifinder/bin/ichecker.sh',
		       [ '-p', 'system',  '-r', 'main', '-i', 'system-invariants.inv', '-s', PropertyId_Pro ],
		       [ cwd(Repository), stdout(pipe(Out)) ]),

				% interpret output
	read_stream_to_codes(Out, Codes), close(Out),
	(string_codes('valid\n', Codes) -> Status = 'valid' ; Status = 'invalid'),
	
				% done
	!.


ichecker_validate(_Claim, _Context, _AArgs, _XRef, 'ongoing') :-
				% default behavior, when the above fail...
	true.
