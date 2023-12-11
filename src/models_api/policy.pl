:- module(policy, [ policy_id/2, policy_subjects/2, policy_objects/2,
		    policy_ss_flows/2, policy_so_flows/2, policy_attributes/2,
		    policy_constraints/2, pp_policy/1,
		  
		    subject_id/2, subject_ports/2, subject_attributes/2,
		    subject_constraints/2, pp_subject/1,
		    
		    object_id/2, object_attributes/2, object_constraints/2, pp_object/1,

		    aport_id/2, aport_attributes/2, aport_constraints/2, pp_aport/1,
		    
		    ss_flow_id/2, ss_flow_source/2, ss_flow_target/2, ss_flow_attributes/2,
		    ss_flow_constraints/2, pp_ss_flow/1,
		    
		    so_flow_id/2, so_flow_source/2, so_flow_target/2, so_flow_attributes/2,
		    so_flow_constraints/2, pp_so_flow/1
		  
		  ] ).

:- use_module(common).


% policy(id, subjects, objects, ssflows, soflows, attributes, constraints)

policy_id(policy(Id, _Subjects, _Objects, _SSFlows, _SOFlows, _Attrs, _Constraints), Id).

policy_subjects(policy(_Id, Subjects, _Objects, _SSFlows, _SOFlows, _Attrs, _Constraints), Subjects).

policy_objects(policy(_Id, _Subjects, Objects, _SSFlows, _SOFlows, _Attrs, _Constraints), Objects).

policy_ss_flows(policy(_Id, _Subjects, _Objects, SSFlows, _SOFlows, _Attrs, _Constraints), SSFlows).

policy_so_flows(policy(_Id, _Subjects, _Objects, _SSFlows, SOFlows, _Attrs, _Constraints), SOFlows).

policy_attributes(policy(_Id, _Subjects, _Objects, _SSFlows, _SOFlows, Attrs, _Constraints), Attrs).

policy_constraints(policy(_Id, _Subjects, _Objects, _SSFlows, _SOFlows, _Attrs, Constraints), Constraints).

pp_policy(policy(Id, Subjects, Objects, SSFlows, SOFlows, Attrs, Constraints)) :-
	format('Policy ~a~n', Id),
	pp_subjects(Subjects, '  ', ''),
	pp_objects(Objects, '  ', ''),
	pp_ss_flows(SSFlows, '  ', ''),
	pp_so_flows(SOFlows, '  ', ''),
	pp_attributes(Attrs, '  ', '~n'),
	pp_constraints(Constraints, '  ', '~n').

pp_policies([], _, _).
pp_policies([P | Ps], Pre, Post) :- format(Pre), pp_policy(P), format(Post),
	pp_policies(Ps, Pre, Post).


% subject(id, ports, attributes, constraints)

subject_id(subject(Id, _Ports, _Attrs, _Constraints), Id).

subject_ports(subject(_Id, Ports, _Attrs, _Constraints), Ports).

subject_attributes(subject(_Id, _Ports, Attrs, _Constraints), Attrs).

subject_constraints(subject(_Id, _Ports, _Attrs, Constraints), Constraints).

pp_subject(subject(Id, Ports, Attrs, Constraints)) :-
	format('Subject ~a~n', Id),
	pp_aports(Ports, '    ', ''),
	pp_attributes(Attrs, '    ', '~n'),
	pp_constraints(Constraints, '    ', '~n').


pp_subjects([], _, _).
pp_subjects([S | Ss], Pre, Post) :- format(Pre), pp_subject(S), format(Post),
	pp_subjects(Ss, Pre, Post).


% port(id, attributes, constraints)

aport_id(port(Id, _Attrs, _Constraints), Id).

aport_attributes(port(_Id, Attrs, _Constraints), Attrs).

aport_constraints(port(_Id, _Attrs, Constraints), Constraints).

pp_aport(port(Id, Attrs, Constraints)) :-
	format('Port ~a~n', Id),
	pp_attributes(Attrs, '      ', '~n'),
	pp_constraints(Constraints, '      ', '~n').

pp_aports([], _, _).

pp_aports([P | Ps], Pre, Post) :- format(Pre), pp_aport(P), format(Post),
	pp_aports(Ps, Pre, Post).

% object(id, attributes, constraints)

object_id(object(Id, _Attrs, _Constraints), Id).

object_attributes(object(_Id, Attrs, _Constraints), Attrs).

object_constraints(object(_Id, _Attrs, Constraints), Constraints).

pp_object(object(Id, Attrs, Constraints)) :-
	format('Object ~a~n', Id),
	pp_attributes(Attrs, '    ', '~n'),
	pp_constraints(Constraints, '    ', '~n').


pp_objects([], _, _).
pp_objects([O | Os], Pre, Post) :- format(Pre), pp_object(O), format(Post),
	pp_objects(Os, Pre, Post).




% ss_flow(id, source, target, attributes, constraints)

ss_flow_id(ss_flow(Id, _Source, _Target, _Attrs, _Constraints), Id).

ss_flow_source(ss_flow(_Id, Source, _Target, _Attrs, _Constraints), Source).

ss_flow_target(ss_flow(_Id, _Source, Target, _Attrs, _Constraints), Target).

ss_flow_attributes(ss_flow(_Id, _Source, _Target, Attrs, _Constraints), Attrs).

ss_flow_constraints(ss_flow(_Id, _Source, _Target, _Attrs, Constraints), Constraints).

pp_ss_flow(ss_flow(Id, Source, Target, Attrs, Constraints)) :-
	format('Subject-to-Subject Flow ~a~n', Id),
	format('    From '), pp_x_flow_endpoint(Source), format('~n'),
	format('    To   '), pp_x_flow_endpoint(Target), format('~n'),
	pp_attributes(Attrs, '    ', '~n'),
	pp_constraints(Constraints, '    ', '~n').

pp_ss_flows([], _, _).
pp_ss_flows([F | Fs], Pre, Post) :- format(Pre), pp_ss_flow(F), format(Post),
	pp_ss_flows(Fs, Pre, Post).



% so_flow(id, source, target, attributes, constraints)

so_flow_id(so_flow(Id, _Source, _Target, _Attrs, _Constraints), Id).

so_flow_source(so_flow(_Id, Source, _Target, _Attrs, _Constraints), Source).

so_flow_target(so_flow(_Id, _Source, Target, _Attrs, _Constraints), Target).

so_flow_attributes(so_flow(_Id, _Source, _Target, Attrs, _Constraints), Attrs).

so_flow_constraints(so_flow(_Id, _Source, _Target, _Attrs, Constraints), Constraints).

pp_so_flow(so_flow(Id, Source, Target, Attrs, Constraints)) :-
	format('Subject-to-Object Flow ~a~n', Id),
	format('    From '), pp_x_flow_endpoint(Source), format('~n'),
	format('    To   '), pp_x_flow_endpoint(Target), format('~n'),
	pp_attributes(Attrs, '    ', '~n'),
	pp_constraints(Constraints, '    ', '~n').

pp_so_flows([], _, _).
pp_so_flows([F | Fs], Pre, Post) :- format(Pre), pp_so_flow(F), format(Post),
	pp_so_flows(Fs, Pre, Post).
	
pp_x_flow_endpoint([]).
pp_x_flow_endpoint([ X | Xs] ) :-
	format('~a / ', X),
	pp_x_flow_endpoint(Xs).
