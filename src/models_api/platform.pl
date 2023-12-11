:- module(platform, [ platform_id/2,  platform_nodes/2, platform_switches/2,
		      platform_phylinks/2, platform_attributes/2, pp_platform/1,

		      node_id/2, node_memories/2, node_processors/2,
		      node_devices/2, node_ports/2, node_attributes/2, pp_node/1,

		      memory_id/2, memory_attributes/2, pp_memory/1,

		      processor_id/2, processor_attributes/2, pp_processor/1,

		      device_id/2, device_ports/2, device_attributes/2, pp_device/1,

		      port_id/2, port_attributes/2, pp_port/1, pp_ports/3,

		      switch_id/2, switch_ports/2, switch_attributes/2, pp_switch/1,

		      phylink_id/2, phylink_source/2, phylink_target/2,
		      phylink_attributes/2, pp_phylink/1
		    
		    ] ).

	 
:- use_module(common).


% platform(id, nodes, switches, phylinks, attributes)

platform_id(platform(Id, _Nodes, _Switches, _Phylinks, _Attrs), Id).

platform_nodes(platform(_Id, Nodes, _Switches, _Phylinks, _Attrs), Nodes).

platform_switches(platform(_Id, _Nodes, Switches, _Phylinks, _Attrs), Switches).

platform_phylinks(platform(_Id, _Nodes, _Switches, Phylinks, _Attrs), Phylinks).

platform_attributes(platform(_Id, _Nodes, _Switches, _Phylinks, Attrs), Attrs).

pp_platform( platform(Id, Nodes, Switches, Phylinks, Attrs) ) :-
	format('Platform ~a~n', Id),
	pp_nodes(Nodes, '  ', ''),
	pp_switches(Switches, '  ', ''),
	pp_phylinks(Phylinks, '  ', ''),
	pp_attributes(Attrs, '  ', '~n').

pp_platforms([], _, _).
pp_platforms([P | Ps], Pre, Post) :- format(Pre), pp_platform(P), format(Post),
	pp_platforms(Ps, Pre, Post).



% node(id, memories, processors, devices, ports, attributes)

node_id(node(Id, _Memories, _Processors, _Devices, _Ports, _Attrs), Id).

node_memories(node(_Id, Memories, _Processors, _Devices, _Ports, _Attrs), Memories).

node_processors(node(_Id, _Memories, Processors, _Devices, _Ports, _Attrs), Processors).

node_devices(node(_Id, _Memories, _Processors, Devices, _Ports, _Attrs), Devices).

node_ports(node(_Id, _Memories, _Processors, _Devices, Ports, _Attrs), Ports).

node_attributes(node(_Id, _Memories, _Processors, _Devices, _Ports, Attrs), Attrs).

pp_node( node(Id, Memories, Processors, Devices, Ports, Attrs) ) :-
	format('Node ~a~n', Id),
	pp_memories(Memories, '    ', ''),
	pp_processors(Processors, '    ', ''),
	pp_devices(Devices, '    ', ''),
	pp_ports(Ports, '    ', ''),
	pp_attributes(Attrs, '    ', '~n').

pp_nodes([], _, _).
pp_nodes([N | Ns], Pre, Post) :- format(Pre), pp_node(N), format(Post),
	pp_nodes(Ns, Pre, Post).



% memory(id, attributes)

memory_id(memory(Id, _Attrs), Id).

memory_attributes(memory(_Id, Attrs), Attrs).

pp_memory( memory(Id, Attrs)) :-
	format('Memory ~a~n', Id),
	pp_attributes(Attrs, '      ', '~n').

pp_memories([], _, _).
pp_memories([M | Ms], Pre, Post) :- format(Pre), pp_memory(M), format(Post),
	pp_memories(Ms, Pre, Post).



% processor(id, attributes)

processor_id(processor(Id, _Attrs), Id).

processor_attributes(processor(_Id, Attrs), Attrs).

pp_processor( processor(Id, Attrs)) :-
	format('Processor ~a~n', Id),
	pp_attributes(Attrs, '      ', '~n').

pp_processors([], _, _).
pp_processors([P | Ps], Pre, Post) :- format(Pre), pp_processor(P), format(Post),
	pp_processors(Ps, Pre, Post).



% device(id, ports, attributes)

device_id(device(Id, _Ports, _Attrs), Id).

device_ports(device(_Id, Ports, _Attrs), Ports).

device_attributes(device(_Id, _Ports, Attrs), Attrs).

pp_device( device(Id, Ports, Attrs)) :-
	format('Device ~a~n', Id),
	pp_ports(Ports, '      ', ''),
	pp_attributes(Attrs, '      ', '~n').

pp_devices([],_,_).
pp_devices([D | Ds], Pre, Post) :- format(Pre), pp_device(D), format(Post),
	pp_devices(Ds, Pre, Post).



% port(id, attributes)

port_id(port(Id, _Attrs), Id).

port_attributes( port(_Id, Attrs), Attrs).

pp_port( port(Id, Attrs)) :-
	format('Port ~a~n', Id),
	pp_attributes(Attrs, '        ', '~n').

pp_ports([], _, _).
pp_ports([P | Ps], Pre, Post) :-  format(Pre), pp_port(P), format(Post),
	pp_ports(Ps, Pre, Post).



% switch(id, ports, attributes)

switch_id(switch(Id, _Ports, _Attrs), Id).

switch_ports(switch(_Id, Ports, _Attrs), Ports).

switch_attributes(switch(_Id, _Ports, Attrs), Attrs).

pp_switch( switch(Id, Ports, Attrs)) :-
	format('Switch ~a~n', Id),
	pp_ports(Ports, '    ', ''),
	pp_attributes(Attrs, '    ', '~n').

pp_switches([],_,_).
pp_switches([S | Ss], Pre, Post) :- format(Pre), pp_switch(S), format(Post),
	pp_switches(Ss, Pre, Post).



% phylink(id, port-ref, port-ref, attributes)

phylink_id(phylink(Id, _Source, _Target, _Attrs), Id).

phylink_source(phylink(_Id, Source, _Target, _Attrs), Source).

phylink_target(phylink(_Id, _Source, Target, _Attrs), Target).

phylink_attributes(phylink(_Id, _Source, _Target, Attrs), Attrs).

pp_phylink( phylink(Id, Source, Target, Attrs)) :-
	format('Physical Link ~a~n', Id),
	format('    From '), pp_phylink_endpoint(Source), format('~n'),
	format('    To   '), pp_phylink_endpoint(Target), format('~n'),
	pp_attributes(Attrs, '    ', '~n').

pp_phylink_endpoint([]).
pp_phylink_endpoint([ X | Xs]) :-
	format('~a / ', X),
	pp_phylink_endpoint(Xs).

pp_phylinks([], _, _).
pp_phylinks([P | Ps], Pre, Post) :- format(Pre), pp_phylink(P), format(Post),
	pp_phylinks(Ps, Pre, Post).

