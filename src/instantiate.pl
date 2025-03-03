:- module(instantiate, [ instantiate_pattern/3,
			 instantiate_pattern_list/2 ] ).

:- use_module(models_api/model).
:- use_module(patterns).
:- use_module(assurance).
:- use_module(evidence).
:- use_module(agent).

:- use_module(stringutil).

:- dynamic ac_pattern_pending/2, ac_pattern_running/2.


				%
				% instatiate_pattern(+PatternId, +TopArgs, +CaseId)
				% instatiate_pattern(+PatternList, +CaseId)
				% instatiate_pattern_list(+PatternList, +CaseId)
				%

instantiate_pattern(PatternId, TopArgs, CaseId) :-
	init_assurance_repository(CaseId),
	instantiate_pattern_main(PatternId, TopArgs).

instantiate_pattern(List, CaseId) :- % is_list(List), !,
        instantiate_pattern_list(List, CaseId).

instantiate_pattern_list(List, CaseId) :- % is_list(List), !,
	init_assurance_repository(CaseId),
	instantiate_pattern_list_aux(List).

instantiate_pattern_list_aux([]).

instantiate_pattern_list_aux([PatternId-TopArgs | List]) :-
	instantiate_pattern_main(PatternId, TopArgs),
	instantiate_pattern_list_aux(List).


				%
				% instantiate_pattern_main(+PatternId, +TopArgs)
				%

instantiate_pattern_main(PatternId, TopArgs) :-
	ac_pattern(PatternId, FArgs, _GoalP)
	-> ( bind_top_arguments(FArgs, TopArgs, AArgs)
	   -> ( instantiate_pattern_loop(PatternId, AArgs) )
	   ;  ( ui:vformat('*** top pattern arguments mismatch.~n'), fail ) )
	;  ( ui:vformat('*** top pattern ~a not found.~n', PatternId), fail ).

				% instantiate_pattern_loop(+PatternId, +AArgs)

instantiate_pattern_loop(PatternId0, AArgs0) :-
	retractall( ac_pattern_pending(_,_) ),
	assertz( ac_pattern_pending(PatternId0, AArgs0) ),
	repeat,
	( ac_pattern_pending(PatternId, AArgs)
	-> ( ui:vformat('*** instantiating pattern ~a ... ', PatternId),
				% pattern lookup, instantiate, store
	     once( ac_pattern(PatternId, _FArgs, GoalP) ), % in case PatternId multiply defined
	     assertz( ac_pattern_running(PatternId, AArgs) ),
	     ( instantiate_goal(GoalP, AArgs, GoalI, Log)
	     -> ( insert_ac_instance(PatternId, AArgs, GoalI, Log),
		  ui:vformat('done.~n'))
	     ;  ( instantiate_null_goal(GoalP, AArgs, NullGoalI),
		  insert_ac_instance(PatternId, AArgs, NullGoalI, []),
		  ui:vformat('failed.~n'))),
	     retractall( ac_pattern_running(_,_) ),
	     retractall( ac_pattern_pending(PatternId, AArgs) ),
	     fail )
	; ( ! ) ).

				% bind_top_arguments(+FArgs, +TopArgs, -AArgs)

bind_top_arguments([], [], []).

bind_top_arguments([arg(Name, Category) | FArgs], [TopArg | TopArgs],
		   [arg(Name, Category, TopArg) | AArgs]) :-
	bind_top_arguments(FArgs, TopArgs, AArgs).




				%
				%
				% instantiate_goal(+GoalP, +AArgs, -GoalI, -Log)
				%

instantiate_goal(goal(Id, ClaimP, ContextP, BodyP), AArgs,
		 goal(IdArgs, ClaimI, ContextI, BodyI), Log) :-
	instantiate_id(Id, AArgs, IdArgs),
	instantiate_text(ClaimP, AArgs, ClaimI, Log1),
	instantiate_context(ContextP, AArgs, ContextI, Log2),
	instantiate_subgoal_list(BodyP, AArgs, BodyI, Log3),
	append(Log1, Log2, Log12), append(Log12, Log3, Log).

instantiate_null_goal(goal(Id, _ClaimP, _ContextP, _BodyP), AArgs,
		      null_goal(IdArgs)) :-
	instantiate_id(Id, AArgs, IdArgs).

				% instantiate_subgoal_list(+GoalPList, +AArgs, -GoalIList, -Log)

instantiate_subgoal_list([], _AArgs, [], []).

instantiate_subgoal_list([SubgoalP | BodyP], AArgs, SubgoalIList, Log) :-
	instantiate_subgoal(SubgoalP, AArgs, SubgoalI, Log1),
	instantiate_subgoal_list(BodyP, AArgs, BodyI, Log2),
	(SubgoalI \= no_goal -> SubgoalIList = [SubgoalI | BodyI] ; SubgoalIList = BodyI),
	append(Log1, Log2, Log).



				% instantiate_subgoal(+GoalP, +AArgs, -GoalI, -Log)

instantiate_subgoal(goal(Id, ClaimP, ContextP, BodyP), AArgs, SubgoalI, Log) :-
	instantiate_goal(goal(Id, ClaimP, ContextP, BodyP), AArgs, SubgoalI, Log).

instantiate_subgoal(goal_ref(Id), AArgs, goal_ref(IdArgs) , []) :-
	instantiate_id(Id, AArgs, IdArgs).

instantiate_subgoal(strategy(ClaimP, Iterator, ContextP, BodyP), AArgs,
		    strategy(ClaimI, ContextI, BodyI), Log) :-
	instantiate_text(ClaimP, AArgs, ClaimI, Log1),
	instantiate_context(ContextP, AArgs, ContextI, Log2),
				% expand iterator, instantiate subgoals...
        instantiate_iterator(Iterator,AArgs,IteratorI,Log2a),
	findall( [AArgIt], strategy_iterator_match(IteratorI, AArgs, AArgIt), AArgItList),
	maplist( append(AArgs), AArgItList, AArgsExtList ),
	maplist( instantiate_subgoal_list(BodyP), AArgsExtList, BodyIs, Logs3 ),
	flatten(BodyIs, BodyI),
	append(Log1, Log2, Log12), append(Log12, Log2a, Log12a),
        flatten(Logs3, Log3), append(Log12a, Log3, Log).

instantiate_subgoal(strategy(ClaimP, ContextP, BodyP), AArgs,
		    strategy(ClaimI, ContextI, BodyI), Log) :-
	instantiate_text(ClaimP, AArgs, ClaimI, Log1),
	instantiate_context(ContextP, AArgs, ContextI, Log2),
	instantiate_subgoal_list(BodyP, AArgs, BodyI, Log3),
	append(Log1, Log2, Log12), append(Log12, Log3, Log).

instantiate_subgoal(ac_pattern_ref(PatternId, Args), AArgs,
		    away_goal_ref(IdArgs), []) :-
				% pattern lookup, actual arguments binding
	ac_pattern(PatternId, FArgs, goal( Id, _, _, _)),
	bind_call_arguments(FArgs, Args, AArgs, AArgsForCall),
				% instantiate id in the callee context
	instantiate_id(PatternId, Id, AArgsForCall, IdArgs),
				% update dynamic
	( ( \+ ac_instance(PatternId, AArgsForCall, _, _),
	    \+ ac_pattern_pending(PatternId, AArgsForCall))
	-> assertz( ac_pattern_pending(PatternId, AArgsForCall) )
	;  true).

instantiate_subgoal(ac_pattern_ref(PatternId, Args), AArgs,
		    missing_goal, [ [ 'pattern ref arguments mismatch', [] ] ] ) :-
	ac_pattern(PatternId, FArgs, _),
	\+ bind_call_arguments(FArgs, Args, AArgs, _AArgsForCall).

instantiate_subgoal(ac_pattern_ref(PatternId, _Args), _AArgs,
		    missing_goal, [ [ 'pattern ref (~a) not found', [PatternId] ] ]) :-
	\+ ac_pattern(PatternId, _, _).

instantiate_subgoal(evidence(Category, ClaimP, ContextP), AArgs,
		    evidence(Category, ClaimI, ContextI, XRef), Log) :-
	instantiate_text(ClaimP, AArgs, ClaimI, Log1),
	instantiate_context(ContextP, AArgs, ContextI, Log2),
	append(Log1, Log2, Log),
	( ac_evidence(Category, ClaimI, ContextI, AArgs, _, _)
	-> ( ac_evidence(Category, ClaimI, ContextI, AArgs, XRef, _) )
	;  ( insert_ac_evidence(Category, ClaimI, ContextI, AArgs, XRef, pending),
	     evidence_validate(Category, ClaimI, ContextI, AArgs, XRef) ) ).

instantiate_subgoal(conditional(Condition, GoalP), AArgs, GoalI, Log) :-
	condition_holds(Condition, AArgs),
	instantiate_subgoal(GoalP, AArgs, GoalI, Log).

instantiate_subgoal(conditional(Condition, _GoalP), AArgs, no_goal, []) :-
	\+ condition_holds(Condition, AArgs).

instantiate_subgoal(alternatives(GoalPList), AArgs, GoalIList, Log) :-
                                % to do - choose among alternatives
        instantiate_subgoal_list(GoalPList, AArgs, GoalIList, Log).

				% bind_call_arguments(+FArgs, +Args, +AArgs, -AArgsForCall)

bind_call_arguments([], [], _AArgs, []).

bind_call_arguments([arg(Name, Category) | FArgs], [ UName | Args], AArgs,
		    [arg(Name, Category, Value) | AArgsForCall]) :-
	member( arg(UName, Category, Value), AArgs),
	bind_call_arguments( FArgs, Args, AArgs, AArgsForCall ).

				% strategy_iterator_match(+Iterator, +AArgs, -AArgIt)

strategy_iterator_match( iterate(Name, Category, list(Values)), _AArgs,
			 arg(Name, Category, Value)) :-
	member(Value, Values).

strategy_iterator_match( iterate(Name, Category, expand(AArgName)), AArgs,
			 arg(Name, Category, Value)) :-
	member(arg(AArgName, _, AArgValue), AArgs),
	is_list(AArgValue),
	member(Value, AArgValue).

				%

strategy_iterator_match( iterate(Name, Category, subjects(PolicyArgName) ), AArgs,
			 arg(Name, Category, Subject)) :-
	member(arg(PolicyArgName, _, Policy), AArgs),
	policy:policy_subjects(Policy, Subjects),
	member(Subject, Subjects).

strategy_iterator_match( iterate(Name, Category, processes(PolicyArgName) ), AArgs,
			 arg(Name, Category, Process)) :-
	member(arg(PolicyArgName, _, Policy), AArgs),
	policy:policy_processes(Policy, Processes),
	member(Process,  Processes).

strategy_iterator_match( iterate(Name, Category, ss_flows(PolicyArgName) ), AArgs,
			 arg(Name, Category, Flow)) :-
	member(arg(PolicyArgName, _, Policy), AArgs),
	policy:policy_ss_flows(Policy, Flows),
	member(Flow, Flows).

strategy_iterator_match( iterate(Name, Category, ipc_flows(PolicyArgName) ), AArgs,
			 arg(Name, Category, Flow)) :-
	member(arg(PolicyArgName, _, Policy), AArgs),
	policy:policy_ipc_flows(Policy, Flows),
	member(Flow, Flows).

strategy_iterator_match( iterate(Name, Category, nodes(PlatformArgName) ), AArgs,
			 arg(Name, Category, Node)) :-
	member(arg(PlatformArgName, _, Platform), AArgs),
	platform:platform_nodes(Platform, Nodes),
	member(Node, Nodes).

strategy_iterator_match( iterate(Name, Category, modes(_Subject) ), _AArgs,
			 arg(Name, Category, Mode)) :-
				% not yet implemented -
				% actually, there are no modes defined for subjects...
	member(Mode, ['a-mode']).

strategy_iterator_match( iterate(Name, Category, transitions(_Subject) ), _AArgs,
			 arg(Name, Category, Transition)) :-
				% not yet implemented -
				% actually, there are no transitions defined for subjects...
	member(Transition, ['a-transition']).

strategy_iterator_match( iterate(Name, Category, hazards(_PolicyArgName) ), _AArgs,
			 arg(Name, Category, Hazard)) :-
				% not yet implemented -
	%member(arg(PolicyArgName, _, Policy), AArgs),
	%policy:policy_hazards(Policy, Hazards),
	member(Hazard, ['a-hazard', 'b-hazard']).

				% condition holds

condition_holds( true, _AArgs ).

condition_holds( eq(Name, Value), AArgs) :-
	member( arg(Name, _, Value), AArgs).


				%
				%
				% instantiate_context(+ContextP, +AArgs, -ContextI, -Log)
				%

instantiate_context([], _AArgs, [], []).

instantiate_context([ClauseP | ContextP], AArgs, [ClauseI | ContextI], Log) :-
	instantiate_context_clause(ClauseP, AArgs, ClauseI, Log1),
	instantiate_context(ContextP, AArgs, ContextI, Log2),
	append(Log1, Log2, Log).

instantiate_context_clause(context(TextP), AArgs, context(TextI), Log) :-
	instantiate_text(TextP, AArgs, TextI, Log).

instantiate_context_clause(assumption(TextP), AArgs, assumption(TextI), Log) :-
	instantiate_text(TextP, AArgs, TextI, Log).

instantiate_context_clause(justification(TextP), AArgs, justification(TextI), Log) :-
	instantiate_text(TextP, AArgs, TextI, Log).

				%
				%
				% instantiate_iterator(+Iterator, +AArgs, -IteratorI, -Log)
				%

instantiate_iterator(iterate(Name,Category,ITerm), AArgs, iterate(Name,Category,ITermI), Log) :-
        atomic(ITerm), !,
        split_string(ITerm, [IT]),
        instantiate_iterator_term(AArgs, IT, Category, ITermI, Log).

instantiate_iterator(iterate(Name,Category,ITerm), _AArgs, iterate(Name,Category,ITerm), []) :-
        compound(ITerm), !.

instantiate_iterator(I,_,I,[]).

instantiate_iterator_term(AArgs, TokenP, IteratorCategory, TokenI, Log) :-
        ground(IteratorCategory),
        member(AArg, AArgs),
        aarg_name(AArg, Name),
        string_concat('{', Name, X), string_concat(X, '}', TokenP),
                                % found a matching AArg
                                % to do: should also recognize variable/farg without { }
				% to do: transform the (term) value into a string if needed
                                % if the term is a list check category of list items
        aarg_category(AArg, ArgCategory), aarg_value(AArg, Value),
        (       ArgCategory = list(ArgListItemCategory) % check if list and extract category
	->      (       ArgListItemCategory == IteratorCategory
                ->      TokenI = Value, Log = []
		;       Log = ['Iterator category mismatch.']
                )
	;       % deal with other kinds of iterators here, otherwise log incompatibility
                TokenI = TokenP, Log = ['Argument category not compatible.']
        ),
	!.

instantiate_iterator_term(_AArgs, TokenP, TokenP).

				%
				%
				% instantiate_text(+TextP, +AArgs, -TextI, -Log)
				%

instantiate_text(TextP, AArgs, TextI, []) :-
	split_string(TextP, TokensP), % split_string(TextP, ' ', ' ', TokensP),
	maplist( instantiate_text_token(AArgs), TokensP, TokensI),
	atomics_to_string(TokensI, ' ', TextI).

instantiate_text_token(AArgs, TokenP, TokenI) :-
        member(AArg, AArgs),
        aarg_name(AArg, Name),
        string_concat('{', Name, X), string_concat(X, '}', TokenP),
				% not yet finished :
				% transform the (term) value into a string
        aarg_text_value(AArg, Value),
        string_concat('{', Value, Y), string_concat(Y, '}', TokenI),
	!.

instantiate_text_token(_AArgs, TokenP, TokenP).

				%
				%
				% instantiate_id(+Id, +AArgs, -IdArgs)
				%

instantiate_id(Id, AArgs, IdArgs) :-
	ac_pattern_running(PatternId, _),
	instantiate_id( PatternId, Id, AArgs, IdArgs).

				% instantiate_id(+PatternId, +Id, +AArgs, -IdArgs)

instantiate_id(PatternId, Id, AArgs, IdArgs) :-
	insert_ac_instance_id_args(PatternId, Id, AArgs, Index),
	atomic_list_concat([ Id, '_', Index], IdArgs).

				%
				%
				% aarg_name(+AArg, -Name),
				% aarg_value(+AArg, -Value), aarg_text_value(+AArg, -Value)
				%
				%

aarg_name( arg(Name, _, _), Name).

aarg_category( arg(_, Category, _), Category).

aarg_value( arg(_, _, Value), Value).

aarg_text_value( arg(_, _, policy(Value, _, _, _, _, _, _)), Value).

aarg_text_value( arg(_, _, subject(Value, _, _, _)), Value).

aarg_text_value( arg(_, _, process(Value, _, _, _)), Value).

aarg_text_value( arg(_, _, node(Value, _, _, _, _, _)), Value).

aarg_text_value( arg(_, _, object(Value, _, _)), Value).

aarg_text_value( arg(_, _, ss_flow(Value, _, _, _, _)), Value).

aarg_text_value( arg(_, _, ipc_flow(Value, _, _, _, _)), Value).

aarg_text_value( arg(_, _, Value), Value).


