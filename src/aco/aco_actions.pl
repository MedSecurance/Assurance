:- module(aco_actions,
          [ action_kind/2,
            action_name/2,
            action_target/2,
            action_params/2,
            action_target_kind/2,
            empty_action_doc/1,
            is_empty_action_doc/1,
            observe_action_candidates/2,
            observe_constructor_candidates/2,
            observe_rewrite_candidates/2,
            applicable_action/2,
            applicable_action/3,
            rank_action_candidates/3,
            score_action_candidate/3,
            apply_action/4,
            dispatch_action/4,
            validate_doc_invariants/3,
            normalise_ranked_candidates/2
          ]).

/*
   aco_actions.pl

   First-cut action framework for ACO construction and rewrite actions.

   Purpose:
   - provide a uniform action vocabulary spanning constructors and rewrites
   - enumerate currently applicable actions over an aco_doc/2
   - keep ranking pluggable so deterministic and intelligent alternatives can
     coexist behind the same API
   - provide a clean layer above aco_core / aco_processor / aco_transforms

   Notes:
   - this is an architectural shell and executable first version, not yet the
     final integration with the existing concrete edit machinery
   - worker predicates for specific constructors/rewrites are declared as hooks
     and currently default to structured stubs
   - the canonical action form is action(Name, Kind, Target, Params)
   - pair/2 is retained as a target form for insertion between existing nodes
     or across an edge-like relation, pending reconciliation with the prior
     target conventions already used elsewhere in O-ETB
*/

:- multifile
       constructor_worker/5,
       rewrite_worker/5,
       deterministic_ranker/3,
       intelligent_ranker/3,
       doc_node_ids/2,
       doc_node_kind/3,
       doc_unit_ids/2,
       doc_has_unit/2,
       doc_root_goal_ids/2,
       doc_goal_ids/2,
       doc_strategy_ids/2,
       doc_goal_without_strategy/2,
       doc_goal_without_context/2,
       doc_goal_without_evidence/2,
       doc_goal_with_direct_evidence/2,
       doc_goal_with_direct_goal_children/2,
       doc_can_attach_context/2,
       doc_can_attach_justification/2,
       doc_can_attach_assumption/2,
       doc_can_attach_evidence/2,
       doc_can_attach_strategy/2,
       doc_can_attach_subgoal/2,
       doc_can_attach_module_ref/2,
       doc_can_add_module/1,
       doc_supports_pair_target/3,
       doc_is_empty_case_shell/1,
       validate_structural_invariants/1,
       validate_unit_invariants/2,
       validate_id_invariants/1,
       validate_text_hygiene/1.

:- discontiguous
       dispatch_action/4.


/* ------------------------------------------------------------------
   Action representation
   ------------------------------------------------------------------ */

/*
   action(Name, Kind, Target, Params)

   Name   = action name atom
   Kind   = constructor | rewrite
   Target = root | node(NodeId) | unit(UnitId) | pair(Left,Right) |
            after(NodeId) | before(NodeId)
   Params = structured term specific to action name
*/

action_kind(action(_Name, Kind, _Target, _Params), Kind).
action_name(action(Name, _Kind, _Target, _Params), Name).
action_target(action(_Name, _Kind, Target, _Params), Target).
action_params(action(_Name, _Kind, _Target, Params), Params).

action_target_kind(root, root).
action_target_kind(node(_), node).
action_target_kind(unit(_), unit).
action_target_kind(pair(_,_), pair).
action_target_kind(after(_), after).
action_target_kind(before(_), before).

constructor_name(add_goal).
constructor_name(add_subgoal).
constructor_name(add_strategy).
constructor_name(add_context).
constructor_name(add_justification).
constructor_name(add_assumption).
constructor_name(add_evidence).
constructor_name(add_module).
constructor_name(add_module_ref).
constructor_name(add_away_goal).
constructor_name(add_away_solution).
constructor_name(add_away_context).
constructor_name(add_contract).

rewrite_name(t1_slim_evidence).
rewrite_name(t2_insert_goal).
rewrite_name(t3).
rewrite_name(t4).
rewrite_name(t5a).
rewrite_name(t5b).
rewrite_name(t6_modularize).
rewrite_name(t7_insert_strategy).


/* ------------------------------------------------------------------
   Empty document model
   ------------------------------------------------------------------ */

/*
   The action layer prefers an explicit empty case shell over a truly empty file.
   This avoids overloading add_goal with file creation concerns.
*/

empty_action_doc(aco_doc([], meta{state:empty_shell, lines:[]})).

is_empty_action_doc(Doc) :-
    nonvar(Doc),
    (   Doc = aco_doc([], meta{state:empty_shell, lines:_})
    ;   call_multifile(doc_is_empty_case_shell(Doc))
    ).


/* ------------------------------------------------------------------
   Observation
   ------------------------------------------------------------------ */

observe_action_candidates(Doc, Candidates) :-
    observe_constructor_candidates(Doc, ConstructorCandidates),
    observe_rewrite_candidates(Doc, RewriteCandidates),
    append(ConstructorCandidates, RewriteCandidates, Candidates).

observe_constructor_candidates(Doc, Candidates) :-
    findall(Candidate,
            observed_constructor_candidate(Doc, Candidate),
            Candidates0),
    sort(Candidates0, Candidates).

observe_rewrite_candidates(Doc, Candidates) :-
    findall(Candidate,
            observed_rewrite_candidate(Doc, Candidate),
            Candidates0),
    sort(Candidates0, Candidates).

observed_constructor_candidate(Doc,
    candidate(action(add_goal, constructor, root,
                     goal_params('AUTHOR CHECK: state top claim', [])),
              pending,
              [state(empty_or_case_shell), enabled(add_goal)],
              [opportunity(start_argument)])) :-
    is_empty_action_doc(Doc),
    !.

observed_constructor_candidate(Doc,
    candidate(action(add_context, constructor, node(GoalId),
                     context_params('AUTHOR CHECK: add relevant context', [])),
              pending,
              [target(goal(GoalId)), deficit(missing_context)],
              [deficit(missing_context), opportunity(add_context)])) :-
    call_multifile(doc_goal_without_context(Doc, GoalId)).

observed_constructor_candidate(Doc,
    candidate(action(add_evidence, constructor, node(GoalId),
                     evidence_params('AUTHOR CHECK: cite supporting evidence', [])),
              pending,
              [target(goal(GoalId)), deficit(missing_evidence)],
              [deficit(missing_evidence), opportunity(add_evidence)])) :-
    call_multifile(doc_goal_without_evidence(Doc, GoalId)).

observed_constructor_candidate(Doc,
    candidate(action(add_strategy, constructor, node(GoalId),
                     strategy_params('AUTHOR CHECK: describe argument approach', [])),
              pending,
              [target(goal(GoalId)), opportunity(explicit_strategy)],
              [opportunity(add_strategy)])) :-
    call_multifile(doc_goal_without_strategy(Doc, GoalId)).

observed_constructor_candidate(Doc,
    candidate(action(add_subgoal, constructor, node(GoalId),
                     subgoal_params('AUTHOR CHECK: add supporting subgoal', [])),
              pending,
              [target(goal(GoalId)), opportunity(goal_refinement)],
              [opportunity(add_subgoal)])) :-
    call_multifile(doc_can_attach_subgoal(Doc, GoalId)).

observed_constructor_candidate(Doc,
    candidate(action(add_module, constructor, root,
                     module_params('AUTHOR CHECK: add module description', [])),
              pending,
              [opportunity(modular_argument_structure)],
              [opportunity(add_module)])) :-
    call_multifile(doc_can_add_module(Doc)).

observed_rewrite_candidate(Doc,
    candidate(action(t1_slim_evidence, rewrite, node(GoalId), t1_params([])),
              pending,
              [target(goal(GoalId)), pattern(direct_evidence_support)],
              [opportunity(t1)])) :-
    call_multifile(doc_goal_with_direct_evidence(Doc, GoalId)).

observed_rewrite_candidate(Doc,
    candidate(action(t2_insert_goal, rewrite, node(GoalId),
                     t2_params('AUTHOR CHECK: add evidence-discharge goal', [])),
              pending,
              [target(goal(GoalId)), pattern(direct_evidence_support)],
              [opportunity(t2)])) :-
    call_multifile(doc_goal_with_direct_evidence(Doc, GoalId)).

observed_rewrite_candidate(Doc,
    candidate(action(t7_insert_strategy, rewrite, node(GoalId),
                     t7_params('AUTHOR CHECK: describe argument approach',
                               'AUTHOR CHECK: add wrapper goal if needed', [])),
              pending,
              [target(goal(GoalId)), pattern(goal_children_without_strategy)],
              [opportunity(t7)])) :-
    call_multifile(doc_goal_with_direct_goal_children(Doc, GoalId)).


/* ------------------------------------------------------------------
   Applicability
   ------------------------------------------------------------------ */

applicable_action(Doc, Action) :-
    applicable_action(Doc, Action, _Why).

applicable_action(Doc, action(add_goal, constructor, root, goal_params(_Claim, _Opts)), Why) :-
    is_empty_action_doc(Doc),
    Why = [precond(empty_case_shell), precond(root_target)].

applicable_action(Doc, action(add_goal, constructor, node(NodeId), goal_params(_Claim, _Opts)), Why) :-
    call_multifile(doc_can_attach_subgoal(Doc, NodeId)),
    Why = [precond(target_exists(NodeId)), precond(goal_like_parent(NodeId))].

applicable_action(Doc, action(add_subgoal, constructor, node(NodeId), subgoal_params(_Claim, _Opts)), Why) :-
    call_multifile(doc_can_attach_subgoal(Doc, NodeId)),
    Why = [precond(target_exists(NodeId)), precond(subgoal_attachment_permitted(NodeId))].

applicable_action(Doc, action(add_strategy, constructor, node(NodeId), strategy_params(_Text, _Opts)), Why) :-
    call_multifile(doc_can_attach_strategy(Doc, NodeId)),
    Why = [precond(target_exists(NodeId)), precond(strategy_under_goal(NodeId))].

applicable_action(Doc, action(add_context, constructor, node(NodeId), context_params(_Text, _Opts)), Why) :-
    call_multifile(doc_can_attach_context(Doc, NodeId)),
    Why = [precond(target_exists(NodeId)), precond(context_link_permitted(NodeId))].

applicable_action(Doc, action(add_justification, constructor, node(NodeId), justification_params(_Text, _Opts)), Why) :-
    call_multifile(doc_can_attach_justification(Doc, NodeId)),
    Why = [precond(target_exists(NodeId)), precond(justification_link_permitted(NodeId))].

applicable_action(Doc, action(add_assumption, constructor, node(NodeId), assumption_params(_Text, _Opts)), Why) :-
    call_multifile(doc_can_attach_assumption(Doc, NodeId)),
    Why = [precond(target_exists(NodeId)), precond(assumption_link_permitted(NodeId))].

applicable_action(Doc, action(add_evidence, constructor, node(NodeId), evidence_params(_Text, _Opts)), Why) :-
    call_multifile(doc_can_attach_evidence(Doc, NodeId)),
    Why = [precond(target_exists(NodeId)), precond(evidence_link_permitted(NodeId))].

applicable_action(Doc, action(add_module, constructor, root, module_params(_Text, _Opts)), Why) :-
    call_multifile(doc_can_add_module(Doc)),
    Why = [precond(module_creation_permitted)].

applicable_action(Doc, action(add_module_ref, constructor, node(NodeId), module_ref_params(_Module, _Args, _Opts)), Why) :-
    call_multifile(doc_can_attach_module_ref(Doc, NodeId)),
    Why = [precond(target_exists(NodeId)), precond(module_ref_permitted(NodeId))].

applicable_action(Doc, action(Name, constructor, pair(Left, Right), Params), Why) :-
    pair_target_constructor_name(Name),
    call_multifile(doc_supports_pair_target(Doc, Left, Right)),
    Why = [precond(pair_target_supported(Left, Right)), precond(params(Params))].

applicable_action(_Doc, action(Name, rewrite, Target, _Params), Why) :-
    rewrite_name(Name),
    Why = [precond(rewrite_target(Target))].

pair_target_constructor_name(add_goal).
pair_target_constructor_name(add_subgoal).
pair_target_constructor_name(add_strategy).
pair_target_constructor_name(add_context).
pair_target_constructor_name(add_justification).
pair_target_constructor_name(add_assumption).
pair_target_constructor_name(add_evidence).
pair_target_constructor_name(add_module_ref).


/* ------------------------------------------------------------------
   Ranking
   ------------------------------------------------------------------ */

rank_action_candidates(Doc, Candidates, Ranked) :-
    (   call_multifile(deterministic_ranker(Doc, Candidates, Ranked0))
    ->  true
    ;   default_deterministic_ranker(Doc, Candidates, Ranked0)
    ),
    normalise_ranked_candidates(Ranked0, Ranked).

score_action_candidate(Doc, Candidate, Score) :-
    (   call_multifile(deterministic_ranker(Doc, [Candidate], [candidate(_Action, Score0, _Why, _Diag)]))
    ->  Score = Score0
    ;   default_candidate_score(Doc, Candidate, Score)
    ).

normalise_ranked_candidates(Candidates, Ranked) :-
    predsort(compare_candidate_score_desc, Candidates, Ranked).

compare_candidate_score_desc(Order,
                             candidate(_A1, S1, _R1, _D1),
                             candidate(_A2, S2, _R2, _D2)) :-
    candidate_numeric_score(S1, N1),
    candidate_numeric_score(S2, N2),
    compare(Order0, N2, N1),
    normalise_compare(Order0, Order).

normalise_compare(=, <).
normalise_compare(Order, Order).

candidate_numeric_score(pending, 0.0).
candidate_numeric_score(Score, Score) :-
    number(Score),
    !.
candidate_numeric_score(_, 0.0).

default_deterministic_ranker(Doc, Candidates, Ranked) :-
    maplist(default_candidate_score_wrap(Doc), Candidates, Ranked).

default_candidate_score_wrap(Doc,
                             candidate(Action, OldScore, Why, Diag),
                             candidate(Action, Score, Why, Diag)) :-
    default_candidate_score(Doc, candidate(Action, OldScore, Why, Diag), Score).

default_candidate_score(_Doc, candidate(action(add_goal, constructor, root, _), _S, _W, _D), 1.00) :- !.
default_candidate_score(_Doc, candidate(action(t7_insert_strategy, rewrite, _Target, _), _S, _W, _D), 0.90) :- !.
default_candidate_score(_Doc, candidate(action(t2_insert_goal, rewrite, _Target, _), _S, _W, _D), 0.85) :- !.
default_candidate_score(_Doc, candidate(action(t1_slim_evidence, rewrite, _Target, _), _S, _W, _D), 0.80) :- !.
default_candidate_score(_Doc, candidate(action(add_strategy, constructor, _Target, _), _S, _W, _D), 0.70) :- !.
default_candidate_score(_Doc, candidate(action(add_subgoal, constructor, _Target, _), _S, _W, _D), 0.68) :- !.
default_candidate_score(_Doc, candidate(action(add_context, constructor, _Target, _), _S, _W, _D), 0.60) :- !.
default_candidate_score(_Doc, candidate(action(add_evidence, constructor, _Target, _), _S, _W, _D), 0.58) :- !.
default_candidate_score(_Doc, candidate(action(Name, constructor, _Target, _), _S, _W, _D), 0.50) :-
    constructor_name(Name),
    !.
default_candidate_score(_Doc, candidate(action(Name, rewrite, _Target, _), _S, _W, _D), 0.50) :-
    rewrite_name(Name),
    !.
default_candidate_score(_Doc, candidate(_Action, _S, _W, _D), 0.0).


/* ------------------------------------------------------------------
   Application
   ------------------------------------------------------------------ */

apply_action(Action, DocIn, DocOut, Report) :-
    applicable_action(DocIn, Action, Why),
    dispatch_action(Action, DocIn, DocOut, Report0),
    validate_doc_invariants(DocOut, Action, Report1),
    merge_reports(Why, Report0, Report1, Report).

dispatch_action(action(Name, constructor, Target, Params), DocIn, DocOut, Report) :-
    !,
    (   call_multifile(constructor_worker(Name, Target, Params, DocIn, worker_result(DocOut, Report)))
    ->  true
    ;   stub_constructor(Name, Target, Params, DocIn, DocOut, Report)
    ).

dispatch_action(action(Name, rewrite, Target, Params), DocIn, DocOut, Report) :-
    !,
    (   call_multifile(rewrite_worker(Name, Target, Params, DocIn, worker_result(DocOut, Report)))
    ->  true
    ;   stub_rewrite(Name, Target, Params, DocIn, DocOut, Report)
    ).

stub_constructor(Name, Target, Params, DocIn, DocOut,
                 report(action(Name, constructor, Target, Params),
                        stub,
                        [],
                        [note(no_constructor_worker_registered(Name))])) :-
    constructor_name(Name),
    DocOut = DocIn.

stub_rewrite(Name, Target, Params, DocIn, DocOut,
             report(action(Name, rewrite, Target, Params),
                    stub,
                    [],
                    [note(no_rewrite_worker_registered(Name))])) :-
    rewrite_name(Name),
    DocOut = DocIn.

merge_reports(Why,
              report(Action, Status0, Edits0, Notes0),
              report(_ValidationAction, validation, Edits1, Notes1),
              report(Action, Status0, Edits, Notes)) :-
    append(Edits0, Edits1, Edits),
    append([why(Why)|Notes0], Notes1, Notes).


/* ------------------------------------------------------------------
   Validation
   ------------------------------------------------------------------ */

validate_doc_invariants(Doc, Action,
                        report(Action, validation, [], Notes)) :-
    validate_with_optional_hook(validate_structural_invariants(Doc),
                                note(structural_invariants_assumed), Note1),
    validate_with_optional_hook(validate_unit_invariants(Doc, Action),
                                note(unit_invariants_assumed), Note2),
    validate_with_optional_hook(validate_id_invariants(Doc),
                                note(id_invariants_assumed), Note3),
    validate_with_optional_hook(validate_text_hygiene(Doc),
                                note(text_hygiene_assumed), Note4),
    Notes = [Note1, Note2, Note3, Note4].

validate_with_optional_hook(Goal, FallbackNote, Note) :-
    (   call_multifile(Goal)
    ->  Note = note(validated(Goal))
    ;   Note = FallbackNote
    ).


/* ------------------------------------------------------------------
   Utility
   ------------------------------------------------------------------ */

call_multifile(Goal) :-
    call(Goal).
