:-module(certificate_agent, [certificate_validate/5]).

certificate_validate(_Claim, _Context, _AArgs, _XRef, 'ongoing') :-
				% not yet completed: require the certificate for some authority
	true.

