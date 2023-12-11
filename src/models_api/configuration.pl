:- module(configuration, [ pp_configuration/1 ]).

:- use_module(common).

                                %
                                % configuration pretty printing
                                %

pp_configuration(X) :-
        pp_platform_configuration(X, '').

pp_platform_configuration(PlatformId-cx(nodes(NodeConfigs)), Indent) :-
        format('~aPlatform ~a Configuration~n', [Indent, PlatformId]),
        string_concat(Indent, '  ', NewIndent),
        pp_node_configurations(NodeConfigs, NewIndent),
        format('~a-- End Platform ~a', [Indent, PlatformId]).

pp_node_configuration(NodeId-cx(subjects(SIds), objects(OIds), ss_flows(SSIds), so_flows(SOIds),
                                processors(ProcConfigs), memories(MemConfigs), devices(DevConfigs)), Indent) :-
        format('~aNode ~a~n', [Indent, NodeId]),
        string_concat(Indent, '  ', NewIndent),
        pp_rawlist(NewIndent, 'subjects', SIds),
        pp_rawlist(NewIndent, 'objects', OIds),
        pp_rawlist(NewIndent, 'ss flows', SSIds),
        pp_rawlist(NewIndent, 'so flows', SOIds),
        pp_processor_configurations(ProcConfigs, NewIndent),
        pp_memory_configurations(MemConfigs, NewIndent),
        pp_device_configurations(DevConfigs, NewIndent),
        format('~a-- End Node ~a~n', [Indent, NodeId]).

pp_processor_configuration(ProcId-cx(support(XIds),schedule(Schedule)), Indent) :-
        format('~aProcessor ~a~n', [Indent, ProcId]),
        string_concat(Indent, '  ', NewIndent),
        pp_rawlist(NewIndent, 'support', XIds),
        pp_rawlist(NewIndent, 'schedule', Schedule).

pp_memory_configuration(MemId-cx(support(XIds),map(Map)), Indent) :-
        format('~aMemory ~a~n', [Indent, MemId]),
        string_concat(Indent, '  ', NewIndent),
        pp_rawlist(NewIndent, support, XIds),
        pp_rawlist(NewIndent, map, Map).

pp_device_configuration(DevId-cx(support(XIds),schedule(Schedule)), Indent) :-
        format('~aDevice ~a~n', [Indent, DevId]),
        string_concat(Indent, '  ', NewIndent),
        pp_rawlist(NewIndent, 'support', XIds),
        pp_rawlist(NewIndent, 'schedule', Schedule).

pp_node_configurations([], _).
pp_node_configurations([C | Cs], Indent) :-
        pp_node_configuration(C, Indent), pp_node_configurations(Cs, Indent).

pp_processor_configurations([], _).
pp_processor_configurations([C | Cs], Indent) :-
        pp_processor_configuration(C, Indent), pp_processor_configurations(Cs, Indent).

pp_memory_configurations([], _).
pp_memory_configurations([C | Cs], Indent) :-
        pp_memory_configuration(C, Indent), pp_memory_configurations(Cs, Indent).

pp_device_configurations([], _).
pp_device_configurations([C | Cs], Indent) :-
        pp_device_configuration(C, Indent), pp_device_configurations(Cs, Indent).

pp_rawlist(Indent,Tag,List) :-
        List \= [] -> (format('~a~a ',[Indent, Tag]), write(List), nl); true.

