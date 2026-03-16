:- module(instantiate, [ instantiate_pattern/3,
			 instantiate_pattern_list/2 ] ).

:- use_module(models_api/model).
:- use_module(patterns).
:- use_module(assurance).
:- use_module(evidence).
% :- use_module(agent).
:- use_module(agent_interface).

:- use_module(stringutil).
:- use_module(com/ui).

:- dynamic ac_pattern_pending/4, ac_pattern_running/4, ac_occurrence_done/1.
% ac_pattern_pending(OccId, PatternId, AArgs, InstId).
% ac_pattern_running(OccId, PatternId, AArgs, InstId).



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
	retractall( ac_pattern_pending(_,_,_,_) ),
	retractall( ac_pattern_running(_,_,_,_) ),
	retractall( ac_occurrence_done(_) ),
	RootOccId = occ(none, callpos([]), kpath([])),
	insert_ac_occurrence(RootOccId, PatternId0, AArgs0, InstId0),
	assertz( ac_pattern_pending(RootOccId, PatternId0, AArgs0, InstId0) ),
	repeat,

	( ac_pattern_pending(OccId, PatternId, AArgs, InstId)
	->	( ui:vformat('*** instantiating pattern ~a ... ', PatternId),
			% pattern lookup, instantiate, store
			(   once(ac_pattern(PatternId, _FArgs, GoalP))
			->  assertz(ac_pattern_running(OccId, PatternId, AArgs, InstId)),
				(   instantiate_goal(GoalP, AArgs, [], kpath([]), GoalI, Log)
				->  insert_ac_instance(PatternId, AArgs, InstId, GoalI, Log),
					record_instance_provenance(PatternId, AArgs, GoalI),
					assertz(ac_occurrence_done(OccId)),
					ui:vformat('done.~n')
				;   instantiate_null_goal(GoalP, AArgs, [], kpath([]), NullGoalI),
					insert_ac_instance(PatternId, AArgs, InstId, NullGoalI, []),
					record_instance_provenance(PatternId, AArgs, NullGoalI),
					assertz(ac_occurrence_done(OccId)),
					ui:vformat('failed.~n')
				)
			;   % Pattern not found: MUST consume the pending item or the loop never terminates.
				% Do NOT create a separate null ac_instance/5. Undefined-ness is rendered at the
				% reference site (module/pattern-ref node) during export.
				ui:vformat('*** pending pattern ~a not found; leaving reference UNDEFINED.~n', [PatternId]),
				assertz(ac_occurrence_done(OccId))
			% to be retired:
			% ;   % Pattern not found: MUST consume the pending item or the loop never terminates
			% 	ui:vformat('*** pending pattern ~a not found; recording null instance.~n', [PatternId]),
			% 	% Record a minimal null goal to keep the CASES repository consistent.
			% 	insert_ac_instance(PatternId, AArgs, InstId,
			% 					goal('G_NULL', missingPattern,
			% 							missing_pattern_ref(PatternId, AArgs), [], []),
			% 					[[missing_pattern(PatternId, AArgs, OccId)]]),
			% 	% insert_ac_instance(PatternId, AArgs, InstId,
			% 	% 				goal('G_NULL', missingPattern,
			% 	% 						'Pattern not found during instantiation.', [], []),
			% 	% 				[[missing_pattern(PatternId, AArgs, OccId)]]),					
			% 	assertz(ac_occurrence_done(OccId))
			),
			retractall(ac_pattern_running(_,_,_,_)),
			retractall(ac_pattern_pending(OccId, PatternId, AArgs, InstId)),
			fail
		
	% 		once( ac_pattern(PatternId, _FArgs, GoalP) ), % in case PatternId multiply defined
	% 		assertz( ac_pattern_running(OccId, PatternId, AArgs, InstId) ),
	% 		( instantiate_goal(GoalP, AArgs, [], kpath([]), GoalI, Log)
	% 		-> ( insert_ac_instance(PatternId, AArgs, InstId, GoalI, Log),
	% 			 record_instance_provenance(PatternId, AArgs, GoalI),
	% 			assertz(ac_occurrence_done(OccId)),
	% 				ui:vformat('done.~n'))
	% 		;  ( instantiate_null_goal(GoalP, AArgs, [], kpath([]), NullGoalI),
	% 			insert_ac_instance(PatternId, AArgs, InstId, NullGoalI, []),
	% 			 record_instance_provenance(PatternId, AArgs, NullGoalI),
	% 			assertz(ac_occurrence_done(OccId)),
	% 			ui:vformat('failed.~n') 
	% 			) 
	% 		),
	% 		retractall( ac_pattern_running(_,_,_,_) ),
	% 		retractall( ac_occurrence_done(_) ),
	% 		retractall( ac_pattern_pending(OccId, PatternId, AArgs, InstId) ),
	% 		fail 
		)
	; ( ! ) 
	).


				% record_instance_provenance(+PatternId, +AArgs, +GoalI)

record_instance_provenance(PatternId, AArgs, GoalI) :-
	goal_root_id(GoalI, RootId),
	( patterns:ac_pattern_sig(PatternId, PatternSig)
	-> true
	;  PatternSig = nosig
	),
	assurance:insert_ac_instance_id_args(PatternId, PatternSig, RootId, AArgs, _Index).

goal_root_id(goal(Id, _Claim, _Ctx, _Body), Id) :- !.
goal_root_id(goal(Id, _Label, _Claim, _Ctx, _Body), Id) :- !.

				% bind_top_arguments(+FArgs, +TopArgs, -AArgs)

bind_top_arguments([], [], []).

bind_top_arguments([arg(Name, Category) | FArgs], [TopArg | TopArgs],
		   [arg(Name, Category, TopArg) | AArgs]) :-
	bind_top_arguments(FArgs, TopArgs, AArgs).




				%
				%
								%
				%
				% instantiate_goal(+GoalP, +AArgs, +Pos, +KPath, -GoalI, -Log)
				%
				% Pos is a structural path within the caller's pattern AST (opaque, stable).
				% KPath represents the execution index(es) that distinguish repeated
				% executions at the same CallPos (e.g., iterator expansions).
				%


instantiate_goal(goal(Id, LabelP, ClaimP, ContextP, BodyP), AArgs, Pos, KPath,
		 goal(IdArgs, LabelI, ClaimI, ContextI, BodyI), Log) :-
	current_instid(InstId),
	lift_id(Id, InstId, KPath, IdArgs),
	once(instantiate_text(LabelP, AArgs, LabelI, Log0)),
	once(instantiate_text(ClaimP, AArgs, ClaimI, Log1)),
	once(instantiate_context(ContextP, AArgs, ContextI, Log2)),
	once(instantiate_subgoal_list(BodyP, AArgs, Pos, KPath, BodyI, Log3)),
	append(Log0, Log1, Log01), append(Log01, Log2, Log012), append(Log012, Log3, Log).

instantiate_goal(goal(Id, ClaimP, ContextP, BodyP), AArgs, Pos, KPath,
		 goal(IdArgs, ClaimI, ContextI, BodyI), Log) :-
	current_instid(InstId),
	lift_id(Id, InstId, KPath, IdArgs),
	once(instantiate_text(ClaimP, AArgs, ClaimI, Log1)),
	once(instantiate_context(ContextP, AArgs, ContextI, Log2)),
	once(instantiate_subgoal_list(BodyP, AArgs, Pos, KPath, BodyI, Log3)),
	append(Log1, Log2, Log12), append(Log12, Log3, Log).


instantiate_null_goal(goal(Id, _LabelP, _ClaimP, _ContextP, _BodyP), _AArgs, _Pos, KPath,
			   goal(IdArgs, '', 'instantiation failure', [], [])) :-
	current_instid(InstId),
	lift_id(Id, InstId, KPath, IdArgs).

instantiate_null_goal(goal(Id, _ClaimP, _ContextP, _BodyP), _AArgs, _Pos, _KPath,
		      null_goal(IdArgs)) :-
	current_instid(InstId),
	lift_id(Id, InstId, kpath([]), IdArgs).

				% instantiate_subgoal_list(+GoalPList, +AArgs, +Pos0, +KPath, -GoalIList, -Log)

instantiate_subgoal_list(GoalsP, AArgs, Pos0, KPath, GoalsI, Log) :-
	instantiate_subgoal_list_aux(GoalsP, AArgs, Pos0, KPath, 1, GoalsI, Log).

instantiate_subgoal_list_aux([], _AArgs, _Pos0, _KPath, _N, [], []).

instantiate_subgoal_list_aux([SubgoalP | BodyP], AArgs, Pos0, KPath, N, SubgoalIList, Log) :-
	pos_extend(Pos0, N, Pos1),
	instantiate_subgoal(SubgoalP, AArgs, Pos1, KPath, SubgoalI, Log1),
	N1 is N + 1,
	instantiate_subgoal_list_aux(BodyP, AArgs, Pos0, KPath, N1, BodyI, Log2),
	(SubgoalI \= no_goal -> SubgoalIList = [SubgoalI | BodyI] ; SubgoalIList = BodyI),
	append(Log1, Log2, Log).

				% instantiate_subgoal(+GoalP, +AArgs, +Pos, +KPath, -GoalI, -Log)

instantiate_subgoal(goal(Id, LabelP, ClaimP, ContextP, BodyP), AArgs, Pos, KPath, SubgoalI, Log) :-
	instantiate_goal(goal(Id, LabelP, ClaimP, ContextP, BodyP), AArgs, Pos, KPath, SubgoalI, Log).

instantiate_subgoal(goal(Id, ClaimP, ContextP, BodyP), AArgs, Pos, KPath, SubgoalI, Log) :-
	instantiate_goal(goal(Id, ClaimP, ContextP, BodyP), AArgs, Pos, KPath, SubgoalI, Log).

instantiate_subgoal(goal_ref(Id), _AArgs, _Pos, KPath, goal_ref(IdArgs), []) :-
	current_instid(InstId),
	lift_id(Id, InstId, KPath, IdArgs).


instantiate_subgoal(strategy(Id, LabelP, ClaimP, ContextP, BodyP), AArgs, Pos, KPath,
		    strategy(IdArgs, LabelI, ClaimI, ContextI, BodyI), Log) :-
	current_instid(InstId),
	lift_id(Id, InstId, KPath, IdArgs),
	once(instantiate_text(LabelP, AArgs, LabelI, Log0)),
	once(instantiate_text(ClaimP, AArgs, ClaimI, Log1)),
	once(instantiate_context(ContextP, AArgs, ContextI, Log2)),
	once(instantiate_subgoal_list(BodyP, AArgs, Pos, KPath, BodyI, Log3)),
	append(Log0, Log1, Log01), append(Log01, Log2, Log012), append(Log012, Log3, Log).

instantiate_subgoal(strategy(ClaimP, Iterator, ContextP, BodyP), AArgs, Pos, KPath,
		    strategy(ClaimI, ContextI, BodyI), Log) :-
	once(instantiate_text(ClaimP, AArgs, ClaimI, Log1)),
	once(instantiate_context(ContextP, AArgs, ContextI, Log2)),
				% expand iterator, instantiate subgoals...
    instantiate_iterator(Iterator, AArgs, IteratorI0, Log2a),
	iterand_to_term(IteratorI0,IteratorI),
	findall( AArgIt, strategy_iterator_match(IteratorI, AArgs, AArgIt), AArgItList),
	instantiate_strategy_iterations(AArgItList, AArgs, BodyP, Pos, KPath, BodyI, Logs3),
	append(Log1, Log2, Log12), append(Log12, Log2a, Log12a),
        flatten(Logs3, Log3), append(Log12a, Log3, Log).

instantiate_subgoal(strategy(ClaimP, ContextP, BodyP), AArgs, Pos, KPath,
		    strategy(ClaimI, ContextI, BodyI), Log) :-
	once(instantiate_text(ClaimP, AArgs, ClaimI, Log1)),
	once(instantiate_context(ContextP, AArgs, ContextI, Log2)),
	once(instantiate_subgoal_list(BodyP, AArgs, Pos, KPath, BodyI, Log3)),
	append(Log1, Log2, Log12), append(Log12, Log3, Log).

instantiate_subgoal(ac_pattern_ref(Id, LabelP, PatternId, Args), AArgs, Pos, KPath,
			ac_pattern_ref(IdArgs, LabelI, PatternId, Args, RefInfo), Log) :-
	current_instid(InstId),
	lift_id(Id, InstId, KPath, IdArgs),
	instantiate_text(LabelP, AArgs, LabelI, Log0),

	% Compute child occurrence identity for deterministic navigation / provenance
	occid_child(Pos, KPath, ChildOccId),

	% Determine callee binding status and (if defined) enqueue it
	(   ac_pattern(PatternId, FArgsCallee, GoalTerm), goal_root_id(GoalTerm, BaseGoalId),
	    bind_call_arguments(FArgsCallee, Args, AArgs, AArgsForCall)
	->  insert_ac_occurrence(ChildOccId, PatternId, AArgsForCall, ChildInstId),
	    assertz( ac_pattern_pending(ChildOccId, PatternId, AArgsForCall, ChildInstId) ),
	    lift_id(BaseGoalId, ChildInstId, kpath([]), CalleeRootId),
	    RefInfo = pref_info(CalleeRootId, ChildInstId, ChildOccId, defined)
	;   (   ac_pattern(PatternId, _FArgsCallee, goal(_BaseGoalId, _L, _Ctx, _Body))
	    ->  RefInfo = pref_info('G_BADARGS', none, ChildOccId, arg_mismatch)
	    ;   RefInfo = pref_info('G_UNDEF', none, ChildOccId, undefined)
	    )
	),

	Log = Log0,
	!.

% the following was replaced by the above
% instantiate_subgoal(ac_pattern_ref(Id, LabelP, PatternId, Args), AArgs, Pos, KPath,
% 		    ac_pattern_ref(IdArgs, LabelI, PatternId, Args), Log) :-
% 	current_instid(InstId),
% 	lift_id(Id, InstId, KPath, IdArgs),
% 	instantiate_text(LabelP, AArgs, LabelI, Log0),
% 	occid_child(Pos, KPath, ChildOccId),
% 	insert_ac_occurrence(ChildOccId, PatternId, Args, ChildInstId),
% 	assertz( ac_pattern_pending(ChildOccId, PatternId, Args, ChildInstId) ),
% 	Log = Log0,
% 	!.

% the following clause has been commented-out as it has been replaced by
% 	the ac_pattern_ref/4 version above.
%	Remove when there are no calls to this variant.
% the load-time normalization of ac_pattern_ref should keep this code unnecessary
% instantiate_subgoal(ac_pattern_ref(PatternId, Args), AArgs, Pos, KPath,
% 			ac_pattern_ref(IdArgs, '', PatternId, Args, RefInfo), []) :-
% 	% Synthesize a stable base id from the call position within the caller pattern.
% 	synth_pattern_ref_id(Pos, SynthBaseId),
% 	current_instid(InstId),
% 	lift_id(SynthBaseId, InstId, KPath, IdArgs),
% 	% Compute child occurrence identity for deterministic navigation / provenance
% 	occid_child(Pos, KPath, ChildOccId),
% 	% Determine callee binding status and (if defined) enqueue it
% 	(   ac_pattern(PatternId, FArgsCallee, goal(BaseGoalId, _L, _Ctx, _Body)),
% 	    bind_call_arguments(FArgsCallee, Args, AArgs, AArgsForCall)
% 	->  insert_ac_occurrence(ChildOccId, PatternId, AArgsForCall, ChildInstId),
% 	    assertz( ac_pattern_pending(ChildOccId, PatternId, AArgsForCall, ChildInstId) ),
% 	    lift_id(BaseGoalId, ChildInstId, kpath([]), CalleeRootId),
% 	    RefInfo = pref_info(CalleeRootId, ChildInstId, ChildOccId, defined)
% 	;   (   ac_pattern(PatternId, _FArgsCallee, goal(_BaseGoalId, _L, _Ctx, _Body))
% 	    ->  RefInfo = pref_info('G_BADARGS', none, ChildOccId, arg_mismatch)
% 	    ;   RefInfo = pref_info('G_UNDEF', none, ChildOccId, undefined)
% 	    )
% 	).

instantiate_subgoal(evidence(Id, LabelP, Category, ClaimP, ContextP), AArgs, _Pos, KPath,
		    evidence(IdArgs, LabelI, Category, ClaimI, ContextI, XRef), Log) :-
	current_instid(InstId),
	lift_id(Id, InstId, KPath, IdArgs),
	instantiate_text(LabelP, AArgs, LabelI, Log0),
	instantiate_text(ClaimP, AArgs, ClaimI, Log1),
	instantiate_context(ContextP, AArgs, ContextI, Log2),
	append(Log0, Log1, Log01), append(Log01, Log2, Log),
	( select_existing_evidence_xref(Category, ClaimI, ContextI, AArgs, XRef)
	-> true
	;  ( insert_ac_evidence(Category, ClaimI, ContextI, AArgs, XRef, pending),
	     once(evidence_validate(Category, ClaimI, ContextI, AArgs, XRef)) )
	),
	!.

instantiate_subgoal(evidence(Category, ClaimP, ContextP), AArgs, _Pos, _KPath,
		    evidence(Category, ClaimI, ContextI, XRef), Log) :-
	instantiate_text(ClaimP, AArgs, ClaimI, Log1),
	instantiate_context(ContextP, AArgs, ContextI, Log2),
	append(Log1, Log2, Log),
	( select_existing_evidence_xref(Category, ClaimI, ContextI, AArgs, XRef)
	-> true
	;  ( insert_ac_evidence(Category, ClaimI, ContextI, AArgs, XRef, pending),
	     once(evidence_validate(Category, ClaimI, ContextI, AArgs, XRef)) )
	),
	!.


				%   ac_shared_goal_ref(SharingKey, Args)
				%   - First occurrence for a given SharingKey is DEFINING and instantiates once.
				%   - Later occurrences are ALIASES and do not instantiate.
				%   - Each occurrence gets its own local Id (lifted), but points to the same
				%     shared instance root for navigation and single-evidence semantics.

instantiate_subgoal(ac_shared_goal_ref(SharingKey, Args), AArgs, Pos, KPath,
                    ac_shared_goal_ref(IdArgs, '', SharingKey, Args, RefInfo), []) :-

    % Synthesize a stable base id from call position within caller pattern.
    synth_pattern_ref_id(Pos, SynthBaseId),
    current_instid(InstId),
    lift_id(SynthBaseId, InstId, KPath, IdArgs),

    % Compute this occurrence id (for provenance); used for linkability.
    occid_child(Pos, KPath, ThisOccId),

    % Resolve (or define) the shared instance for SharingKey.
    (   ac_shared_defined(SharingKey, SharedOccId, SharedInstId, SharedRootId)
    ->  % Alias occurrence: no instantiation, just link to the existing shared instance.
        RefInfo = sref_info(SharedRootId, SharedInstId, SharedOccId, defined)

    ;   % Defining occurrence: instantiate exactly once.
        % We model the shared argument body as a normal pattern instantiation
        % under a canonical "shared wrapper" pattern id derived from SharingKey.
        %
        % The wrapper must exist as an ac_pattern/3, or you can implement a
        % different backing mechanism. For now we treat SharingKey as a pattern id.
        %
        % IMPORTANT: This is the only "policy" choice here:
        % Either SharingKey names a pattern directly, or it names a shared identity
        % which maps to a pattern. For now we use SharingKey as the pattern id.

        SharingKey = sharing(PatternId, _KeyArgs),  % SharingKey carries the callee PatternId
        (   ac_pattern(PatternId, FArgsCallee, GoalTerm),
            goal_root_id(GoalTerm, BaseGoalId),
            bind_call_arguments(FArgsCallee, Args, AArgs, AArgsForCall)
        ->  insert_ac_occurrence(ThisOccId, PatternId, AArgsForCall, SharedInstId),
            assertz(ac_pattern_pending(ThisOccId, PatternId, AArgsForCall, SharedInstId)),
            lift_id(BaseGoalId, SharedInstId, kpath([]), SharedRootId),
            SharedOccId = ThisOccId,
            assertz(ac_shared_defined(SharingKey, SharedOccId, SharedInstId, SharedRootId)),
            RefInfo = sref_info(SharedRootId, SharedInstId, SharedOccId, defined)

        ;   (   ac_pattern(PatternId, _FArgsCallee, _GoalTerm)
            ->  RefInfo = sref_info('G_BADARGS', none, ThisOccId, arg_mismatch)
            ;   RefInfo = sref_info('G_UNDEF', none, ThisOccId, undefined)
            )
        )
    ).


instantiate_subgoal(conditional(Condition, GoalP), AArgs, Pos, KPath, GoalI, Log) :-
	condition_holds(Condition, AArgs),
	instantiate_subgoal(GoalP, AArgs, Pos, KPath, GoalI, Log).

instantiate_subgoal(conditional(Condition, _GoalP), AArgs, _Pos, _KPath, no_goal, []) :-
	\+ condition_holds(Condition, AArgs).

instantiate_subgoal(alternatives(GoalPList), AArgs, Pos, KPath, GoalIList, Log) :-
                                % to do - choose among alternatives
        instantiate_subgoal_list(GoalPList, AArgs, Pos, KPath, GoalIList, Log).

								% instantiate_strategy_iterations(+IteratorMatches, +AArgs, +BodyP, +Pos, +KPath, -BodyI, -Logs)
				%   IteratorMatches is a list of iterator-produced actual-argument terms.
				%   Each expansion is distinguished by extending KPath with the 1-based
				%   iterator index.

instantiate_strategy_iterations(AArgItList, AArgs, BodyP, Pos, kpath(Ks), BodyI, Logs) :-
	findall( BodyI_k-Log_k,
		 ( nth1(K, AArgItList, AArgIt),
		   append(AArgs, [AArgIt], AArgsExt),
		   KPath1 = kpath([K|Ks]),
		   instantiate_subgoal_list(BodyP, AArgsExt, Pos, KPath1, BodyI_k, Log_k)
		 ),
		 Pairs),
	findall(BI, member(BI-_, Pairs), BodyIs),
	findall(L, member(_-L, Pairs), Logs),
	flatten(BodyIs, BodyI).

% select_existing_evidence_xref(+Category, +Claim, +Context, +AArgs, -XRef)
%
% Ensure deterministic selection when multiple matching evidence records exist.
% We choose the smallest existing XRef.

select_existing_evidence_xref(Category, Claim, Context, AArgs, XRef) :-
	findall(X,
		ac_evidence(Category, Claim, Context, AArgs, X, _),
		Xs),
	Xs \= [],
	sort(Xs, [XRef|_]).

% bind_call_arguments(+FArgs, +Args, +AArgs, -AArgsForCall)

bind_call_arguments([], [], _AArgs, []).

% For pattern references, the "actuals" list may be either:
%   1) names of values already present in the caller's AArgs (i.e., "pass-through"), or
%   2) literal values to be used directly for the callee's parameters.
%
% We support both. If a caller binding exists for (UName, Category), we reuse it.
% Otherwise, we treat UName itself as the literal Value.

bind_call_arguments([arg(Name, Category) | FArgs], [UName | Args], AArgs,
                    [arg(Name, Category, Value) | AArgsForCall]) :-
    (   member(arg(UName, Category, Value0), AArgs)
    ->  Value = Value0
    ;   Value = UName
    ),
    bind_call_arguments(FArgs, Args, AArgs, AArgsForCall).

				% strategy_iterator_match(+Iterator, +AArgs, -AArgIt)

strategy_iterator_match( iterate(Name, Category, list(Values)), _AArgs,
			 arg(Name, Category, Value)) :- is_list(Values),
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


% iterand_to_term(Iterand, Iterand) :- nonvar(Iterand), \+ string(Iterand), !.
% iterand_to_term(S, Term) :- string(S), catch(term_string(Term, S), _, fail), !.

% Normalize an iterate/3 iterator so its Iterand is a term, not a string.
iterand_to_term(iterate(Var, Type, Iterand0), iterate(Var, Type, Iterand)) :-
    iterand_value_to_term(Iterand0, Iterand),
    !.
iterand_to_term(Other, Other).

% Accept already-term iterands as-is; convert strings via term_string/2.
iterand_value_to_term(S, Term) :-
    string(S),
    catch(term_string(Term, S), _, Term = S),
    !.
iterand_value_to_term(Term, Term).



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


instantiate_context_clause(context(Id, LabelP, TextP), AArgs, context(Id, LabelI, TextI), Log) :-
	once(instantiate_text(LabelP, AArgs, LabelI, Log0)),
	once(instantiate_text(TextP, AArgs, TextI, Log1)),
	append(Log0, Log1, Log).

instantiate_context_clause(assumption(Id, LabelP, TextP), AArgs, assumption(Id, LabelI, TextI), Log) :-
	once(instantiate_text(LabelP, AArgs, LabelI, Log0)),
	once(instantiate_text(TextP, AArgs, TextI, Log1)),
	append(Log0, Log1, Log).

instantiate_context_clause(justification(Id, LabelP, TextP), AArgs, justification(Id, LabelI, TextI), Log) :-
	once(instantiate_text(LabelP, AArgs, LabelI, Log0)),
	once(instantiate_text(TextP, AArgs, TextI, Log1)),
	append(Log0, Log1, Log).

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
                ->      value_to_string(Value, TokenI), Log = []
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
        string_concat('{', Name, X), string_concat(X, '}', Placeholder),
        TokenP == Placeholder,
        aarg_text_value(AArg, Value0),
        value_to_string(Value0, TokenI),
        !.

instantiate_text_token(_AArgs, TokenP, TokenP).

				%
				%
								%
				%
				% instantiate_id(+Id, +AArgs, -IdArgs)
				%
				% Backward-compatible wrapper retained for any legacy callers.
				% Under the occurrence/InstId scheme, node IDs are lifted by the
				% InstId of the current running occurrence:
				%     NewId = BaseId_InstId
				%

instantiate_id(Id, _AArgs, IdArgs) :-
	current_instid(InstId),
	lift_id(Id, InstId, IdArgs).

				% current_instid(-InstId), current_occurrence(-OccId)

current_instid(InstId) :-
	ac_pattern_running(_OccId, _PatternId, _AArgs, InstId), !.

current_occurrence(OccId) :-
	ac_pattern_running(OccId, _PatternId, _AArgs, _InstId), !.

% occid_child(+Pos, +KPath, -OccId)
% Compute the occurrence identity for a child pattern reference expanded within
% the currently running parent occurrence.
% OccId = occ(ParentOccId, callpos(Pos), KPath).
occid_child(Pos, KPath, OccId) :-
	current_occurrence(ParentOccId),
	CallPos = callpos(Pos),
	OccId = occ(ParentOccId, CallPos, KPath).


				% lift_id(+BaseId, +InstId, -LiftedId)

lift_id(BaseId, InstId, LiftedId) :-
	lift_id(BaseId, InstId, kpath([]), LiftedId).

% lift_id(+BaseId, +InstId, +KPath, -LiftedId)
% If KPath is non-empty, append a stable k-path suffix to disambiguate
% repeated expansions within the same instantiated pattern instance (e.g., iterator bodies).
lift_id(BaseId, InstId, kpath([]), LiftedId) :-
	atomic_list_concat([BaseId, '_', InstId], LiftedId).
lift_id(BaseId, InstId, kpath(Ks), LiftedId) :-
	Ks \= [],
	kpath_suffix(Ks, KSuffix),
	atomic_list_concat([BaseId, '_', InstId, '_', KSuffix], LiftedId).

number_atom(N, A) :-
	atom_number(A, N).

kpath_suffix(Ks, KSuffix) :-
	maplist(number_atom, Ks, KAtoms),
	( KAtoms = [First|Rest] ->
		atom_concat('k', First, FirstK),
		atomic_list_concat([FirstK|Rest], '_', KSuffix)
	; % empty Ks should not occur here, but be defensive
		KSuffix = 'k'
	).

% aarg_name(+AArg, -Name),
				% aarg_value(+AArg, -Value), aarg_text_value(+AArg, -Value)
				%
				%
				% value_to_string(+Value0, -String)
%   Convert an actual argument value to a string for text instantiation.
%   This is intentionally conservative and works for atoms, strings, numbers,
%   and arbitrary terms (rendered with term_string/2).
value_to_string(Value0, String) :-
	( string(Value0) -> String = Value0
	; atom(Value0)   -> atom_string(Value0, String)
	; number(Value0) -> number_string(Value0, String)
	; var(Value0)    -> String = ""
	;               term_string(Value0, String)
	).

% pos_extend(+Pos0, +Index, -Pos)
				%   Extend a structural position path with a 1-based child index.

pos_extend(Pos0, Index, Pos) :-
	( var(Pos0) -> Pos = [Index]
	; is_list(Pos0) -> append(Pos0, [Index], Pos)
	; % treat any non-list Pos0 as opaque root token
	  Pos = [Pos0, Index]
	).



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
% synth_pattern_ref_id(+Pos, -BaseId)
% Generate a stable base id for pattern references that do not carry an explicit
% author-supplied id. This is structural (CallPos-based), not source-location-based.
% BaseId is lifted later with InstId and KPath.

synth_pattern_ref_id(Pos, BaseId) :-
	( var(Pos) -> PosList = []
	; is_list(Pos) -> PosList = Pos
	; PosList = [Pos]
	),
	( PosList == []
	-> BaseId = 'M'
	;  maplist(pos_step_atom, PosList, PosAtoms),
	   atomic_list_concat(['M'|PosAtoms], '_', BaseId)
	).

pos_step_atom(Step, Atom) :-
	( number(Step) -> number_atom(Step, Atom)
	; atom(Step)   -> Atom = Step
	; string(Step) -> atom_string(Atom, Step)
	; term_to_atom(Step, Atom)
	).
