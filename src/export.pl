:- module(export, [ reset_CAP/0, ac_export/2, ac_format/3 ]).

:- use_module(assurance).
:- use_module(evidence).

:- use_module(stringutil).


reset_CAP :-
	shell('find -d ../CAP -not "(" -name "README.md" -or -name "CAP" ")" -delete').

				%
				%
				% ac_export(Filename, Format)
				%

ac_export(FileBasename, 'txt') :- atom(FileBasename),
	param:cap_directory_name(CapDir),
	atomic_list_concat(['../',CapDir,FileBasename,'.txt'],FullFilename),
	open(FullFilename, write, Output),
	forall(ac_instance(PatternId, AArgs, Goal, Log),
	       ac_format(Output, 'txt', ac_instance(PatternId, AArgs, Goal, Log))),
	close(Output), !.

ac_export(Dirname, 'html') :-
	param:cap_directory_name(CapDir),
	atomic_list_concat(['../',CapDir,Dirname,'/'],FullDirname),
	make_directory_path(FullDirname),
	atomic_list_concat([FullDirname, '/index.html'], Index_Html),
	open(Index_Html, write, Index_Output),
	format(Index_Output, '<frameset cols=200,* border=1>~n', []),
	format(Index_Output, '  <frame src="list.html" name=list>~n', []),
	format(Index_Output, '  <frame name=layout>~n', []),
	format(Index_Output, '</frameset>~n', []),
	close(Index_Output),
	atomic_list_concat([FullDirname, '/list.html'], List_Html),
	open(List_Html, write, List_Output),
	format(List_Output, '<h2>~a</h2>~n', [Dirname]),
	forall( ac_instance(PatternId, AArgs, Goal, Log),
		( ac_export_html_instance( ac_instance(PatternId, AArgs, Goal, Log), FullDirname, Basename),
		  format(List_Output, '<p><a href="~a.html" target=layout>~a</a>~n', [Basename, Basename]) ) ),
	close(List_Output).

				% ac_export_html_instance(+ACInstance, +Dirname, -Basename)

ac_export_html_instance( ac_instance(PatternId, AArgs, Goal, Log), Dirname, Basename ) :-
	ac_instance_basename(ac_instance(PatternId, AArgs, Goal, Log), Basename),
				% create dot file
	atomic_list_concat([ Dirname, Basename, '.dot'], Filename_Dot),
	open(Filename_Dot, write, Output_Dot),
	ac_format(Output_Dot, 'dot', ac_instance(PatternId, AArgs, Goal, Log)),
	close(Output_Dot),
				% convert dot into svg
	atomic_list_concat(['-o', Dirname, Basename, '.svg'], OFilename_Svg),
	fork_exec( dot( '-Tsvg', OFilename_Svg, Filename_Dot) ),
				% create html file
	atomic_list_concat([Dirname, Basename, '.html'], Filename_Html),
	open(Filename_Html, write, Output_Html),
	ac_format(Output_Html, 'html', ac_instance(PatternId, AArgs, Goal, Log)),
	close(Output_Html).


				%
				%
				% ac_format(+Output, +Format, +ACInstance)
				%

ac_format(Output, 'txt', ACInstance) :-
	ac_format_txt(Output, ACInstance).

ac_format(Output, 'dot', ACInstance) :-
	ac_format_dot(Output, ACInstance).

ac_format(Output, 'html', ACInstance) :-
	ac_format_html(Output, ACInstance).


				%
				%
				% ac_format_txt(+Output, +ACInstance)
				%

ac_format_txt(Output, ac_instance( _PatternId, _AArgs, Goal, _Log) ) :-
	ac_format_txt_goal(Output, Goal, '').

				% ac_format_txt_goal(+Output, +Goal, +Indent)

ac_format_txt_goal(Output, null_goal(Id), Indent) :-
	format(Output, '~anull goal ~a', [Indent, Id]).

ac_format_txt_goal(Output, goal(Id, Claim, Context, Subgoals), Indent ) :-
	atomic_concat(Indent, '  ', NewIndent),
	format(Output, '~agoal ~a : ~a~n', [ Indent, Id, Claim ]),
	ac_format_txt_context(Output, Context, NewIndent),
	ac_format_txt_goals(Output, Subgoals, NewIndent).

ac_format_txt_goal(Output, strategy(Claim, Context, Subgoals), Indent) :-
	atomic_concat(Indent, '  ', NewIndent),
	format(Output, '~astrategy : ~a~n', [Indent, Claim]),
	ac_format_txt_context(Output, Context, NewIndent),
	ac_format_txt_goals(Output, Subgoals, NewIndent).

ac_format_txt_goal(Output, goal_ref(Id), Indent) :-
	format(Output, '~agoal -> ~a~n', [ Indent, Id ] ).

ac_format_txt_goal(Output, away_goal_ref(Id), Indent) :-
	format(Output, '~aaway goal -> ~a~n', [ Indent, Id ] ).

ac_format_txt_goal(Output, missing_goal, Indent ) :-
	format(Output, '~amissing goal~n', Indent).

ac_format_txt_goal(Output, evidence(Category, Claim, Context, XRef), Indent ) :-
	ac_format_txt_evidence( Output, evidence(Category, Claim, Context, XRef), Indent).

				% ac_format_txt_evidence(+Output, +Evidence, +Indent)

ac_format_txt_evidence(Output, evidence(Category, Claim, Context, XRef), Indent) :-
	ac_evidence(Category, Claim, Context, _AArgs, XRef, Status),
	atomic_concat(Indent, '  ', NewIndent),
	format(Output, '~aevidence ~a : ~a~n', [Indent, Category, Claim]),
	ac_format_txt_context(Output, Context, NewIndent),
	format(Output, '~a   ~a reference -> ', [Indent, Status] ),
	writeq(Output, XRef),
	format(Output, '~n', []).

				% ac_format_txt_goals(+Output, +Goals, +Indent)

ac_format_txt_goals(_Output, [], _Indent).

ac_format_txt_goals(Output, [G | Goals], Indent) :-
	ac_format_txt_goal(Output, G, Indent),
	ac_format_txt_goals(Output, Goals, Indent).

				% ac_format_txt_context(+Output, +Context, +Indent)

ac_format_txt_context(_Output, [], _Indent).

ac_format_txt_context(Output, [context(X) | C], Indent) :-
	format(Output, "~a- context : ~a~n", [ Indent, X ] ),
	ac_format_txt_context(Output, C, Indent).

ac_format_txt_context(Output, [justification(X) | C], Indent) :-
	format(Output, "~a- justification : ~a~n", [ Indent, X ] ),
	ac_format_txt_context(Output, C, Indent).

ac_format_txt_context(Output, [assumption(X) | C], Indent) :-
	format(Output, "~a- assumption : ~a~n", [ Indent, X ]),
	ac_format_txt_context(Output, C, Indent).


				%
				%
				% ac_format_dot(+Output, +ACInstance)
				%

:- dynamic ac_format_dot_counter/1.

ac_format_dot(Output, ac_instance( PatternId, _AArgs, Goal, _Log) ) :-
	ac_format_dot_counter_init,
	format(Output, "digraph ~a {~n", PatternId),
	format(Output, "  node [fontsize=10]~n", []),
	ac_format_dot_goal( Output, null, 1, Goal),
	format(Output, "}~n", []).

				% ac_format_dot_goal(+Output, +ParentId, +Depth, +Goal)

ac_format_dot_goal(_Output, null, _Depth, null_goal(_Id)) :-
	true.

ac_format_dot_goal(Output, ParentId, Depth, goal(Id, Claim, Context, Subgoals)) :-
	ac_format_dot_label_br_ify(Claim, ClaimBr),
	format(Output, "~a [shape=rectangle label=<<b>goal</b><br/>~a>]~n",
	       [Id, ClaimBr]),
	( ParentId \= null -> format(Output, "~a -> ~a~n", [ParentId, Id]) ; true),
	maplist( ac_format_dot_context(Output, Id, Depth), Context),
	NextDepth is Depth + 1,
	maplist( ac_format_dot_goal(Output, Id, NextDepth), Subgoals).

ac_format_dot_goal(Output, ParentId, Depth, strategy(Claim, Context, Subgoals) ) :-
	ac_format_dot_counter_next(C),
	atomic_concat('strategy_', C, Id),
	ac_format_dot_label_br_ify(Claim, ClaimBr),
	format(Output, "~a [shape=parallelogram margin=0 label=<<b>strategy</b><br/>~a>]~n", [Id, ClaimBr]),
	format(Output, "~a -> ~a~n", [ParentId, Id]),
	maplist( ac_format_dot_context(Output, Id, Depth), Context),
	NextDepth is Depth + 1,
	maplist( ac_format_dot_goal(Output, Id, NextDepth), Subgoals).


ac_format_dot_goal(Output, ParentId, _Depth, goal_ref(Id) ) :-
	format(Output, "~a -> ~a~n", [ParentId, Id]).

ac_format_dot_goal(Output, ParentId, _Depth, away_goal_ref(AwayId) ) :-
				% lookup the referred ac instance
	ac_instance(PatternId, _AArgs, goal(AwayId, AwayClaim, _, _), _Log),
	ac_format_dot_counter_next(C),
	atomic_concat('away_goal_', C, Id),
	ac_format_dot_label_br_ify(AwayClaim, AwayClaimBr),
	format(Output, "~a [shape=rectangle label=<<b>away goal</b><br/>~a<br/>[ ~a_~a ]> color=blue]~n",
	       [Id, AwayClaimBr, PatternId, AwayId]),
	format(Output, "~a -> ~a~n", [ParentId, Id]), !.

ac_format_dot_goal(Output, ParentId, _Depth, away_goal_ref(AwayId) ) :-
	ac_format_dot_counter_next(C),
	atomic_concat('away_goal_', C, Id),
	format(Output, "~a [shape=rectangle label=<<b>away goal</b><br/>~a> color=red]~n", [Id, AwayId]),
	format(Output, "~a -> ~a~n", [ParentId, Id]).

ac_format_dot_goal(Output, ParentId, _Depth, missing_goal ) :-
	ac_format_dot_counter_next(C),
	atomic_concat('missing_goal_',C,Id),
	format(Output, "~a [shape=rectangle label=<<b>missing goal</b>> color=red]~n", Id),
	format(Output, "~a -> ~a~n", [ParentId, Id]).

ac_format_dot_goal(Output, ParentId, Depth, evidence(Category, Claim, Context, XRef) ) :-
	ac_format_dot_evidence(Output, ParentId, Depth, evidence(Category, Claim, Context, XRef)).

				% ac_format_dot_evidence(+Output, +ParentId, +Depth, +Evidence)

ac_format_dot_evidence(Output, ParentId, Depth, evidence(Category, Claim, Context, XRef)) :-
	ac_evidence(Category, Claim, Context, _AArgs, XRef, Status),
	ac_format_dot_counter_next(Index),
	atomic_concat('evidence_', Index, Id),
	ac_format_dot_evidence_color(Status, Color),
	ac_format_dot_label_br_ify(Claim, ClaimBr),
	format(Output, "~a [shape=ellipse label=<<b>~a</b><br/>~a<br/>~a xref: ~a> color=~a]~n",
	       [Id, Category, ClaimBr, Status, XRef, Color]),
	format(Output, "~a -> ~a~n", [ParentId, Id]),
	maplist(ac_format_dot_context( Output, Id, Depth), Context), !.

ac_format_dot_evidence_color(valid, black) :- true, !.
ac_format_dot_evidence_color(invalid, red) :- true, !.
ac_format_dot_evidence_color(_, blue).

				% ac_format_dot_context(+Output, +ParentId, +Depth, +Clause)

ac_format_dot_context(Output, ParentId, Depth, context(Text)) :-
	ac_format_dot_context_aux(Output, ParentId, Depth, context, Text).

ac_format_dot_context(Output, ParentId, Depth, justification(Text)) :-
	ac_format_dot_context_aux(Output, ParentId, Depth, justification, Text).

ac_format_dot_context(Output, ParentId, Depth, assumption(Text)) :-
	ac_format_dot_context_aux(Output, ParentId, Depth, assumption, Text).

ac_format_dot_context_aux(Output, ParentId, _Depth, Category, Text) :-
	ac_format_dot_counter_next(Index),
	atomic_concat(Category, '_', Category_),
	atomic_concat(Category_, Index, Id),
	ac_format_dot_label_br_ify(Text, TextBr),
	format(Output, "~a [shape=rectangle style=rounded label=<<b>~a</b><br/>~a>]~n", [Id, Category, TextBr]),
	format(Output, "{ rank=same; ~a -> ~a [style=dashed]; }~n", [ParentId, Id]).

				% ac_format_dot_counter_init, ac_format_dot_counter_next(-X)

ac_format_dot_counter_init :-
	retractall(ac_format_dot_counter(_)),
	assertz( ac_format_dot_counter(0) ).

ac_format_dot_counter_next(X) :-
	ac_format_dot_counter(LastX),
	X is LastX + 1,
	retractall(ac_format_dot_counter(_)),
	assertz( ac_format_dot_counter(X) ).

				%
				% ac_format_dot_text_br_ify(+Text, -TextWithBr)
				%

ac_format_dot_label_br_ify(Text, TextWithBr) :-
	split_string(Text, WordList), % split_string(Text, ' ', ' ', WordList),
	ac_format_dot_label_br_ify_aux('', 0, WordList, TextWithBr).

ac_format_dot_label_br_ify_aux(IText, Count, WordList, OText) :-
	Count > 15, atomic_concat(IText, '<br/>', ITextBr),
	ac_format_dot_label_br_ify_aux(ITextBr, 0, WordList, OText).

ac_format_dot_label_br_ify_aux(IText, _Count, [], IText).

ac_format_dot_label_br_ify_aux(IText, Count, [Word | WordList], OText) :-
	atomic_concat(IText, ' ', IText_), atomic_concat(IText_, Word, IText_Word),
	string_length(Word, WordLength), NewCount is Count + WordLength,
	ac_format_dot_label_br_ify_aux(IText_Word, NewCount, WordList, OText).

				%
				%
				% ac_format_html(+Output, +ACInstance)
				%

ac_format_html(Output, ac_instance(PatternId, AArgs, Goal, Log)) :-
	ac_instance_basename( ac_instance(PatternId, AArgs, Goal, Log), Basename),

	format(Output, "<h2> ~a </h2>~n", [Basename]),
	format(Output, "<h3>Pattern '~a'</h2>~n", [PatternId]),
				% actual args
	maplist( ac_format_html_arg(Output), AArgs),
				% svg embedding
	format(Output, "<hr><h3>GSN Representation</h3>~n", []),
	format(Output, '<img src="~a.svg" alt="graphical view">~n', [Basename]),
				% error log
	format(Output, "<hr><h3>Error Log</h3>~n", []),
	log_format(Output, 'html', Log).

ac_format_html_arg(Output, arg(Name, Category, Value)) :-
	format(Output, "<li>~a : ~w = ", [Name, Category]),
	writeq(Output, Value),
	format(Output, '~n', []).

				%
				%
				% log_format(+Output, +Format, +Log)
				%

log_format(_Output, _Format, []).

log_format(Output, Format, [ LogItem | Log ] ) :-
	log_format_item(Output, Format, LogItem), log_format(Output, Format, Log).

log_format_item(Output, 'html', [ FormattedText, Args ]) :-
	format(Output, '<li>', []),
	format(Output, FormattedText, Args),
	format(Output, '~n', []).

				%
				%
				% ac_instance_basename(+ACInstance, -Basename)
				%

ac_instance_basename( ac_instance(PatternId, _AArgs, Goal, _Log), Basename) :-
	goal_id(Goal, GoalId),
	atomic_list_concat([PatternId, '_', GoalId], Basename).

goal_id( goal(Id, _, _, _), Id ).

goal_id( null_goal(Id), Id).


