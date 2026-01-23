:- module(export, [ reset_CAP/0, ac_export/2, ac_format/3, ac_string/1 ]).

:- use_module(assurance).
:- use_module(evidence).

:- use_module(stringutil).
:- use_module(library(pcre)).


reset_CAP :-
	% param:cap(CapRoot), param:cap_dir(CapDir),
	% atomic_list_concat(['find -d ',CapDir,' -not "(" -name README.md -or -name ',CapRoot,' ")" -delete'],Cmd),
	% shell(Cmd).
	% e.g. 'find -d ../CAP -not "(" -name README.md -or -name CAP ")" -delete'
	% Following version is to save examples in CAP
	shell('make clean_cap'). % just use makefile unless it becomes a problem

%
%
% ac_export(Filename, Format)
%

ac_export(FileBasename, 'txt') :- atom(FileBasename), !,
	param:cap_dir(CapDir),
	atomic_list_concat([CapDir,'/',FileBasename,'.txt'],FullFilename),
	open(FullFilename, write, Output),
	forall(ac_instance(PatternId, AArgs, InstId, Goal, Log),
	       ac_format(Output, 'txt', ac_instance(PatternId, AArgs, InstId, Goal, Log))),
	close(Output), !.

ac_export(Dirname, Format) :- member(Format,['html', 'html90', 'htmlH']), !,
	% Wrap HTML export in catch/3 so interactive mode reports the underlying failure.
	catch(ac_export_html(Dirname, Format),
	      E,
	      ( print_message(error, E),
	        fail )).

			% ac_export_html(+Dirname, +Format)

ac_export_html(Dirname, Format) :-
	param:cap_dir(CapDir),
	atomic_list_concat([CapDir,'/',Dirname],FullDirname),
	make_directory_path(FullDirname),
	atom_concat(FullDirname, '/index.html', Index_Html),
	open(Index_Html, write, Index_Output),
	format(Index_Output, '<frameset cols=200,* border=1>~n', []),
	format(Index_Output, '  <frame src="list.html" name=list>~n', []),
	format(Index_Output, '  <frame name=layout>~n', []),
	format(Index_Output, '</frameset>~n', []),
	close(Index_Output),
	atom_concat(FullDirname, '/list.html', List_Html),
	open(List_Html, write, List_Output),
	format(List_Output, '<h2>~a</h2>~n', [Dirname]),
	forall( ac_instance(PatternId, AArgs, InstId, Goal, Log),
		( ac_export_html_instance(Format, ac_instance(PatternId, AArgs, InstId, Goal, Log), FullDirname, Basename),
		format(List_Output, '<p><a href="~a.html" target=layout>~a</a>~n', [Basename, Basename]) ) ),
	close(List_Output).

			% ac_export_html_instance(+Format, +ACInstance, +Dirname, -Basename)

ac_export_html_instance(Format, ac_instance(PatternId, AArgs, InstId, Goal, Log), Dirname, Basename ) :-
	ac_instance_basename(ac_instance(PatternId, AArgs, InstId, Goal, Log), Basename),
				% create dot file
	atomic_list_concat([ Dirname, '/', Basename, '.dot'], Filename_Dot),
	open(Filename_Dot, write, Output_Dot),
	( Format==html90 -> DotFmt = dot90 ; ( Format==htmlH -> DotFmt = dotH ; DotFmt = dot )),
	ac_format(Output_Dot, DotFmt, ac_instance(PatternId, AArgs, InstId, Goal, Log)),
	close(Output_Dot),
				% convert dot into svg
	atomic_list_concat(['-o', Dirname, '/', Basename, '.svg'], OFilename_Svg),
	fork_exec( dot( '-Tsvg', OFilename_Svg, Filename_Dot) ),
				% create html file
	atomic_list_concat([Dirname, '/', Basename, '.html'], Filename_Html),
	open(Filename_Html, write, Output_Html),
	ac_format(Output_Html, 'html', ac_instance(PatternId, AArgs, InstId, Goal, Log)),
	close(Output_Html).

				% ac_string(-String)
				%	used internally to generate text of current AC as a string
				%

ac_string(S) :- \+ assurance:current_assurance_repository(none), !,
	% current_output(Output),
	with_output_to(
		atom(S),
		forall(ac_instance(PatternId, AArgs, InstId, Goal, Log),
	       ac_format(current_output, 'txt', ac_instance(PatternId, AArgs, InstId, Goal, Log)))
		%, [ capture([current_output, user_output, user_error]) ]
		),
	true.
ac_string(_).


				%
				%
				% ac_format(+Output, +Format, +ACInstance)
				%

ac_format(Output, 'txt', ACInstance) :-
	ac_format_txt(Output, ACInstance).

ac_format(Output, 'html', ACInstance) :-
	ac_format_html(Output, ACInstance).

ac_format(Output, Format, ACInstance) :- memberchk(Format, ['dot', 'dot90', 'dotH']), !,
	ac_format_dot(Output, Format, ACInstance).


				%
				%
				% ac_format_txt(+Output, +ACInstance)
				%

ac_format_txt(Output, ac_instance(_PatternId, _AArgs, _InstId, Goal, _Log)) :-
	ac_format_txt_goal(Output, Goal, '').

				% ac_format_txt_goal(+Output, +Goal, +Indent)

ac_format_txt_goal(Output, null_goal(Id), Indent) :-
	format(Output, '~anull goal ~a', [Indent, Id]).

% not used now:
% ac_format_txt_goal(Output,
% 		goal(_Id, missingPattern, missing_pattern_ref(PatternId, Args), _Context, _Subgoals),
% 		Indent) :-
% 	format(Output, "~apattern reference : ~w(~w)  [UNDEFINED]~n",
% 			[Indent, PatternId, Args]),
% 	!.
	
ac_format_txt_goal(Output, goal(Id, Label, Claim, Context, Subgoals), Indent ) :-
	format(Output, "~agoal ~a (~a) : ~a~n", [Indent, Id, Label, Claim]),
	NewIndent = '  ', atom_concat(Indent, NewIndent, Indent2),
	ac_format_txt_context(Output, Context, Indent2),
	ac_format_txt_goals(Output, Subgoals, Indent2).

ac_format_txt_goal(Output, goal(Id, Claim, Context, Subgoals), Indent ) :-
	atomic_concat(Indent, '  ', NewIndent),
	format(Output, '~agoal ~a : ~a~n', [ Indent, Id, Claim ]),
	ac_format_txt_context(Output, Context, NewIndent),
	ac_format_txt_goals(Output, Subgoals, NewIndent).

ac_format_txt_goal(Output, strategy(Id, Label, Claim, Context, Subgoals), Indent) :-
	format(Output, "~astrategy ~a (~a) : ~a~n", [Indent, Id, Label, Claim]),
	NewIndent = '  ', atom_concat(Indent, NewIndent, Indent2),
	ac_format_txt_context(Output, Context, Indent2),
	ac_format_txt_goals(Output, Subgoals, Indent2).

ac_format_txt_goal(Output, strategy(Claim, Context, Subgoals), Indent) :-
	atomic_concat(Indent, '  ', NewIndent),
	format(Output, '~astrategy : ~a~n', [Indent, Claim]),
	ac_format_txt_context(Output, Context, NewIndent),
	ac_format_txt_goals(Output, Subgoals, NewIndent).

ac_format_txt_goal(Output, goal_ref(Id), Indent) :-
	format(Output, '~agoal -> ~a~n', [ Indent, Id ] ).

ac_format_txt_goal(Output, away_goal_ref(AwayId, PatternId, Args), Indent) :-
    format(Output, "~aaway goal ~a: ~w(~w)~n", [Indent, AwayId, PatternId, Args]),
    !.

ac_format_txt_goal(Output, away_goal_ref(Id), Indent) :-
	format(Output, '~aaway goal -> ~a~n', [ Indent, Id ] ).

ac_format_txt_goal(Output, missing_goal, Indent ) :-
	format(Output, '~amissing goal~n', Indent).


% ac_format_txt_goal(Output, ac_pattern_ref(Id, Label, PatternId, Args, AwayGoalId), Indent) :-
%     format(Output, "~amodule ~a -> away goal ~a: ~w(~w)~n", [Indent, Id, AwayGoalId, PatternId, Args]),
%     format(Output, "~a  ~w~n", [Indent, Label]),
%     !.

% ac_format_txt_goal(Output, ac_pattern_ref(Id, Label, PatternId, Args, AwayGoalId), Indent) :-
%     ( ref_is_undefined(PatternId, Args) -> Suffix = '  [UNDEFINED]' ; Suffix = '' ),
%     format(Output, "~amodule ~a -> away goal ~a: ~w(~w)~w~n",
%            [Indent, Id, AwayGoalId, PatternId, Args, Suffix]),
%     format(Output, "~a  ~w~n", [Indent, Label]),
%     !.

ac_format_txt_goal(Output, ac_pattern_ref(Id, Label, PatternId, Args, pref_info(CalleeRootId, _ChildInstId, _ChildOccId, Status)), Indent) :-
    ( Status == undefined    -> Suffix = '  [UNDEFINED]'
    ; Status == arg_mismatch -> Suffix = '  [ARG_MISMATCH]'
    ; Suffix = ''
    ),
    atomic_list_concat([PatternId, '_', CalleeRootId], CalleeBase),
    format(Output, "~amodule ~a : ~w(~w)~w  -> ~a~n",
           [Indent, Id, PatternId, Args, Suffix, CalleeBase]),
	(Label \== '' -> format(Output, "~a  ~w~n", [Indent, Label]) ; true),
    !.

% ac_format_txt_goal(Output, ac_pattern_ref(Id, Label, PatternId, Args), Indent) :-
% 	format(Output, "~amodule ~a (~a) : ~w ~w~n", [Indent, Id, Label, PatternId, Args]).

ac_format_txt_goal(Output, ac_pattern_ref(Id, Label, PatternId, Args), Indent) :-
    ( ref_is_undefined(PatternId, Args) -> Suffix = '  [UNDEFINED]' ; Suffix = '' ),
    format(Output, "~amodule ~a (~a) : ~w(~w)~w~n",
           [Indent, Id, Label, PatternId, Args, Suffix]).

% ac_format_txt_goal(Output, ac_pattern_ref(PatternId, Args), Indent) :-
% 	format(Output, "~amodule : ~w ~w~n", [Indent, PatternId, Args]).

ac_format_txt_goal(Output, ac_pattern_ref(PatternId, Args), Indent) :-
    ( ref_is_undefined(PatternId, Args) -> Suffix = '  [UNDEFINED]' ; Suffix = '' ),
    format(Output, "~amodule : ~w(~w)~w~n", [Indent, PatternId, Args, Suffix]).

% ac_format_txt_goal(Output, evidence(Id, Label, Category, Claim, Context, XRef), Indent ) :-
% 	format(Output, "~aevidence ~a (~a) : ~a~n", [Indent, Id, Label, Claim]),
% 	format(Output, "~a  evidence-category: ~a, xref: ~w~n", [Indent, Category, XRef]),
% 	NewIndent = '  ', atom_concat(Indent, NewIndent, Indent2),
% 	ac_format_txt_context(Output, Context, Indent2).

ac_format_txt_goal(Output, evidence(Id, Label, Category, Claim, Context, XRef), Indent ) :-
	format(Output, "~aevidence ~a (~a) : ", [Indent, Id, Label]),
	ac_format_txt_text(Output, Indent, Claim),
	format(Output, "~n", []),
	format(Output, "~a  evidence-category: ~a, xref: ~w~n", [Indent, Category, XRef]),
	atom_concat(Indent, "  ", Indent2),
	ac_format_txt_context(Output, Context, Indent2).
	
ac_format_txt_goal(Output, evidence(Category, Claim, Context, XRef), Indent ) :-
	ac_format_txt_evidence( Output, evidence(Category, Claim, Context, XRef), Indent).


				% ac_format_txt_evidence(+Output, +Evidence, +Indent)

ac_format_txt_evidence(Output, evidence(Category, Claim, Context, XRef), Indent) :-
	ac_evidence(Category, Claim, Context, _AArgs, XRef, Status),
	atomic_concat(Indent, '  ', NewIndent),
	format(Output, '~aevidence ~a : ', [Indent, Category]),
	ac_format_txt_text(Output, Indent, Claim),
	format(Output, '~n', []),
	ac_format_txt_context(Output, Context, NewIndent),
	format(Output, '~a  status: ~a, reference -> ', [Indent, Status] ),
	writeq(Output, XRef),
	format(Output, '~n', []).

				% ac_format_txt_goals(+Output, +Goals, +Indent)

ac_format_txt_goals(_Output, [], _Indent).

ac_format_txt_goals(Output, [G | Goals], Indent) :-
	ac_format_txt_goal(Output, G, Indent),
	ac_format_txt_goals(Output, Goals, Indent).

				% ac_format_txt_context(+Output, +Context, +Indent)

ac_format_txt_context(_Output, [], _Indent).

ac_format_txt_context(Output, [context(Id, Label, X) | C], Indent) :-
	format(Output, "~acontext ~a (~a) : ~a~n", [ Indent, Id, Label, X ] ),
	ac_format_txt_context(Output, C, Indent).

ac_format_txt_context(Output, [justification(Id, Label, X) | C], Indent) :-
	format(Output, "~a- justification ~a (~a) : ~a~n", [ Indent, Id, Label, X ] ),
	ac_format_txt_context(Output, C, Indent).

ac_format_txt_context(Output, [assumption(Id, Label, X) | C], Indent) :-
	format(Output, "~a- assumption ~a (~a) : ~a~n", [ Indent, Id, Label, X ] ),
	ac_format_txt_context(Output, C, Indent).

ac_format_txt_context(Output, [context(X) | C], Indent) :-
	format(Output, "~acontext : ~a~n", [ Indent, X ] ),
	ac_format_txt_context(Output, C, Indent).

ac_format_txt_context(Output, [justification(X) | C], Indent) :-
	format(Output, "~a- justification : ~a~n", [ Indent, X ] ),
	ac_format_txt_context(Output, C, Indent).

ac_format_txt_context(Output, [assumption(X) | C], Indent) :-
	format(Output, "~a- assumption : ~a~n", [ Indent, X ]),
	ac_format_txt_context(Output, C, Indent).


				% ac_format_txt_text(+Output, +Indent, +Text)
				% Indent continuation lines if Text contains embedded newlines.
				% Continuation lines are indented by Indent + two spaces.
ac_format_txt_text(Output, Indent, Text) :-
	(   string(Text)
	->  S = Text
	;   atom(Text)
	->  atom_string(Text, S)
	;   % Non-text: fall back to writeq/2
		writeq(Output, Text),
		!
	),
	split_string(S, "\n", "\r", Lines),
	(   Lines = []
	->  true
	;   Lines = [First|Rest],
		format(Output, "~a", [First]),
		atomic_concat(Indent, "  ", Indent2),
		forall(member(L, Rest),
			format(Output, "~n~a~a", [Indent2, L]))
	).


				%
				%
				% ac_format_dot(+Output, +DotFmt, ACInstance)
				%

:- dynamic ac_format_dot_counter/1.

ac_format_dot(Output, DotFmt, ac_instance( PatternId, _AArgs, _InstId, Goal, _Log) ) :-
	ac_format_dot_counter_init,
	format(Output, "digraph ~a {~n", PatternId),

	% "dot90" rotates a wide horizontal image to a long image on end.
    % "dotH" creates a horizontal *layout* without using the rotate
    % transform.
	% These are useful for large monolithic cases.
    (	DotFmt == dot90
	->	format(Output, "  rotate=90~n", [])
	;	(	DotFmt == dotH
		->	format(Output, "  rankdir=LR~n", [])
		; true
		)
	),

	format(Output, "  node [fontsize=10]~n", []),
	ac_format_dot_goal( Output, null, 1, Goal),
	format(Output, "}~n", []).


				% ac_format_dot_goal(+Output, +ParentId, +Depth, +Goal)

ac_format_dot_goal(_Output, null, _Depth, null_goal(_Id)) :-
	true.

ac_format_dot_goal(Output, ParentId, Depth, goal(Id, Label, Claim, Context, Subgoals)) :-
	ac_format_dot_label_br_ify(Claim, ClaimBr),
	format(Output, "~a [shape=rectangle label=<<b>goal ~a</b><br/><font point-size=\"9\">~a</font><br/>~a>]~n",
	       [Id, Id, Label, ClaimBr]),
	( ParentId \= null -> format(Output, "~a -> ~a~n", [ParentId, Id]) ; true),
	maplist( ac_format_dot_context(Output, Id, Depth), Context),
	NextDepth is Depth + 1,
	maplist( ac_format_dot_goal(Output, Id, NextDepth), Subgoals).

ac_format_dot_goal(Output, ParentId, Depth, goal(Id, Claim, Context, Subgoals)) :-
	ac_format_dot_label_br_ify(Claim, ClaimBr),
	format(Output, "~a [shape=rectangle label=<<b>goal ~a</b><br/>~a>]~n",
	       [Id, Id, ClaimBr]),
	% format(Output, "\"~a\" [shape=rectangle label=<<b>goal</b><br/>~a>]~n", % HERE
	%        [Id, ClaimBr]),
	( ParentId \= null -> format(Output, "~a -> ~a~n", [ParentId, Id]) ; true),
	maplist( ac_format_dot_context(Output, Id, Depth), Context),
	NextDepth is Depth + 1,
	maplist( ac_format_dot_goal(Output, Id, NextDepth), Subgoals).

ac_format_dot_goal(Output, ParentId, Depth, strategy(Id, Label, Claim, Context, Subgoals) ) :-
	% ac_format_dot_label_br_ify(Claim, ClaimBr),
	% format(Output, "~a [shape=parallelogram margin=\"0.03,0.01\" label=<<b>strategy ~a</b><br/><font point-size=\"9\">~a</font><br/>~a>]~n",
	%        [Id, Id, Label, ClaimBr]),
	ac_format_dot_identifier_words(Label, LabelWords),
	ac_format_dot_label_br_ify(LabelWords, LabelBr),
	ac_format_dot_label_br_ify(Claim, ClaimBr),

	format(Output,
		"~a [shape=parallelogram fixedsize=false margin=\"0.01,0.01\" label=<<TABLE BORDER=\"0\" CELLBORDER=\"0\" CELLSPACING=\"0\" CELLPADDING=\"0\">\c
	  <TR><TD ALIGN=\"CENTER\">\c
	  <B>strategy ~a</B><BR/>\c
	  <FONT POINT-SIZE=\"9\">~a</FONT><BR/>\c
	  ~a\c
	  </TD></TR></TABLE>>]~n",
		[Id, Id, LabelBr, ClaimBr]),
	  
	% format(Output,
	% 		"~a [shape=parallelogram margin=\"0.03,0.01\" label=<<b>strategy ~a</b><br/><font point-size=\"9\">~a</font><br/>~a>]~n",
	% 		[Id, Id, LabelBr, ClaimBr]),

	format(Output, "~a -> ~a~n", [ParentId, Id]),
	maplist(ac_format_dot_context( Output, Id, Depth), Context),
	NextDepth is Depth + 1,
	maplist( ac_format_dot_goal(Output, Id, NextDepth), Subgoals), !.

ac_format_dot_goal(Output, ParentId, Depth, strategy(Claim, Context, Subgoals) ) :-
	ac_format_dot_counter_next(C),
	atomic_concat('strategy_', C, Id),
	ac_format_dot_label_br_ify(Claim, ClaimBr),

	format(Output,
		"~a [shape=parallelogram fixedsize=false margin=\"0.01,0.01\" label=<<TABLE BORDER=\"0\" CELLBORDER=\"0\" CELLSPACING=\"0\" CELLPADDING=\"0\">\c
	  <TR><TD ALIGN=\"CENTER\">\c
	  <B>strategy ~a</B><BR/>\c
	  <FONT POINT-SIZE=\"9\">~a</FONT><BR/>\c
	  </TD></TR></TABLE>>]~n",
		[Id, Id, ClaimBr]),


	% format(Output, "~a [shape=parallelogram margin=\"0.03,0.01\" label=<<b>strategy ~a</b><br/>~a>]~n",
	% 	[Id, Id, ClaimBr]),

	% format(Output, "\"~a\" [shape=parallelogram margin=\"0.03,0.01\" label=<<b>strategy</b><br/>~a>]~n", [Id, ClaimBr]), % HERE

	format(Output, "~a -> ~a~n", [ParentId, Id]),
	maplist( ac_format_dot_context(Output, Id, Depth), Context),
	NextDepth is Depth + 1,
	maplist( ac_format_dot_goal(Output, Id, NextDepth), Subgoals).

ac_format_dot_goal(Output, ParentId, _Depth, goal_ref(Id) ) :-
	format(Output, "~a -> ~a~n", [ParentId, Id]).

% ac_format_dot_goal(Output, ParentId, _Depth, away_goal_ref(AwayId, PatternId, Args) ) :-
%     % Legacy patterns: the instantiated tree carries an "away goal" placeholder.
%     % Display the callee root goal Id plus the callee pattern/args for traceability.
%     format(Output,
%            '~a [shape=box style="rounded" label=<<b>away goal ~a</b><br/>~w(~w)>];~n',
%            [AwayId, AwayId, PatternId, Args]),
%     format(Output, '~a -> ~a;~n', [ParentId, AwayId]),
%     !.

% ac_format_dot_goal(Output, ParentId, _Depth, away_goal_ref(AwayId, PatternId, Args) ) :-
% 	(   ac_instance(PatternId, Args, _InstId, Goal, _Log)
% 	->  goal_id(Goal, CalleeRootId),
% 		atomic_list_concat([PatternId, '_', CalleeRootId], CalleeBase),
% 		atomic_list_concat([CalleeBase, '.html'], CalleeHref),
% 		format(string(LinkHtml),
% 			'<A HREF="~a" TARGET="layout">~a</A>', [CalleeHref, CalleeBase])
% 	;   LinkHtml = '[UNDEFINED]'
% 	),
% 	ac_format_dot_call_br(PatternId, Args, CallBr),
% 	atomic_list_concat([
% 		'~a [shape=box style="rounded" label=<',
% 		'<b>pattern reference</b><br/>',
% 		'~a<br/>',
% 		'<font point-size="9">-&gt; ~w</font>',
% 		'>];~n'], Fmt),
% 	format(Output, Fmt, [AwayId, CallBr, LinkHtml]),
% 	format(Output, '~a -> ~a;~n', [ParentId, AwayId]),
% 	!.

ac_format_dot_goal(Output, ParentId, _Depth, away_goal_ref(AwayId, PatternId, Args) ) :-
(   ac_instance(PatternId, Args, _InstId, Goal, _Log)
->  goal_id(Goal, CalleeRootId),
	atomic_list_concat([PatternId, '_', CalleeRootId], CalleeBase),
	atomic_list_concat([CalleeBase, '.html'], CalleeHref),
	format(atom(UrlAttrs), ' URL="~a" target="layout"', [CalleeHref])
;   CalleeBase = '[UNDEFINED]',
	UrlAttrs = ''
),
ac_format_dot_call_br(PatternId, Args, CallBr),

atomic_list_concat([
	'~a [shape=box style="rounded"',
	'~a',                          % UrlAttrs
	' label=<',
		'<b>pattern reference</b><br/>',
		'~a<br/>',
		'<font point-size="9">-&gt; ~w</font>',
	'>];~n'
], Fmt),

format(Output, Fmt, [AwayId, UrlAttrs, CallBr, CalleeBase]),
format(Output, '~a -> ~a;~n', [ParentId, AwayId]),
!.


ac_format_dot_goal(Output, ParentId, _Depth, away_goal_ref(AwayId) ) :-
				% lookup the referred ac instance
	ac_instance(PatternId, _AArgs, _InstId, goal(AwayId, AwayClaim, _, _), _Log),
	ac_format_dot_counter_next(C),
	atomic_concat('away_goal_', C, Id),
	ac_format_dot_label_br_ify(AwayClaim, AwayClaimBr),
	format(Output, "~a [shape=rectangle label=<<b>away goal</b><br/>~a<br/>[~a_~a]> color=blue]~n", % HERE
	       [Id, AwayClaimBr, PatternId, AwayId]),
	format(Output, "~a -> ~a~n", [ParentId, Id]), !.

ac_format_dot_goal(Output, ParentId, _Depth, away_goal_ref(AwayId) ) :-
	ac_format_dot_counter_next(C),
	atomic_concat('away_goal_', C, Id),
	format(Output, "~a [shape=rectangle label=<<b>away goal</b><br/>~a> color=red]~n", [Id, AwayId]), % HERE
	format(Output, "~a -> ~a~n", [ParentId, Id]).

ac_format_dot_goal(Output, ParentId, _Depth, missing_goal ) :-
	ac_format_dot_counter_next(C),
	atomic_concat('missing_goal_',C,Id),
	format(Output, "~a [shape=rectangle label=<<b>missing goal</b>> color=red]~n", [Id]), % HERE
	format(Output, "~a -> ~a~n", [ParentId, Id]).


% ac_format_dot_goal(Output, _ParentId, _Depth, ac_pattern_ref(Id, Label, PatternId, Args, AwayGoalId) ) :-
%     % format(Output,
%     %        '~a [shape=box style="rounded" label=<<b>module ~a</b><br/>away goal ~a<br/>~w(~w)<br/>~w>];~n',
%     %        [Id, Id, AwayGoalId, PatternId, Args, Label]),
%     % format(Output, '~a -> ~a;~n', [ParentId, Id]),
% 	( ref_is_undefined(PatternId, Args) -> Suffix = '  [UNDEFINED]' ; Suffix = '' ),
% 	format(Output,
%        '~a [shape=box style="rounded" label=<<b>module ~a</b><br/>away goal ~a<br/>~w(~w)~w<br/>~w>];~n',
%        [Id, Id, AwayGoalId, PatternId, Args, Suffix, Label]),

%     !.

% ac_format_dot_goal(Output, ParentId, _Depth, ac_pattern_ref(Id, Label, PatternId, Args, CalleeRootId) ) :-
%     ( ref_is_undefined(PatternId, Args) -> Suffix = '  [UNDEFINED]' ; Suffix = '' ),

%     ac_format_dot_call_br(PatternId, Args, CallBr),
%     ac_format_dot_identifier_words(Label, LabelWords),
%     ac_format_dot_label_br_ify(LabelWords, LabelBr),

%     % Callee panel basename corresponds to list.html link names: PatternId_GoalId
% 	atomic_list_concat([PatternId, '_', CalleeRootId], CalleeBase),
%     atomic_list_concat([CalleeBase, '.html'], CalleeHref),

%     % Build optional URL attributes (only when defined)
%     (   CalleeHref == ''
%     ->  UrlAttrs = ''
%     ;   format(atom(UrlAttrs), ' URL="~a" target="layout"', [CalleeHref])
%     ),

% 	atomic_list_concat([
% 		'~a [shape=box style=rounded margin="0.12,0.18"',
% 		'~a', %UrlAttrs
% 		'label=<',
% 			'<b>module ~a</b><br/>',
% 			'<font point-size="9">~a</font><br/>',
% 			'~a~w<br/>',
% 			'<font point-size="9">-&gt; <A HREF="~a" TARGET="layout">~a</A></font>',     
% 		'>]~n'], Fmt),

%     format(Output, Fmt,
%            [Id, UrlAttrs, Id, LabelBr, CallBr, Suffix, CalleeHref, CalleeBase]),

%     % format(Output,
%     %        '~a [shape=box style=rounded margin="0.12,0.18" label=<<b>module ~a</b><br/><font point-size="9">~a</font><br/>~a~w<br/><font point-size="9">-&gt; ~a</font>>]~n',
%     %        [Id, Id, LabelBr, CallBr, Suffix, CalleeBase]),
%     format(Output, "~a -> ~a~n", [ParentId, Id]),
%     !.

ac_format_dot_goal(Output, ParentId, _Depth,
                   ac_pattern_ref(Id, Label, PatternId, Args, pref_info(CalleeRootId, _ChildInstId, _ChildOccId, Status)) ) :-
    ( Status == undefined    ->
        Suffix = '  [UNDEFINED]',
        CalleeBase = '[UNDEFINED]',
        UrlAttrs = ''
    ; Status == arg_mismatch ->
        Suffix = '  [ARG_MISMATCH]',
        CalleeBase = '[ARG_MISMATCH]',
        UrlAttrs = ''
    ;
        Suffix = '',
        atomic_list_concat([PatternId, '_', CalleeRootId], CalleeBase),
        atomic_list_concat([CalleeBase, '.html'], Href),
        format(atom(UrlAttrs), ' URL="~a" href="~a" target="layout"', [Href, Href])
    ),

    ac_format_dot_call_br(PatternId, Args, CallBr),
    ac_format_dot_identifier_words(Label, LabelWords),
    ac_format_dot_label_br_ify(LabelWords, LabelBr),

    % Graphviz HTML-like labels will error on empty tags such as:
    %   <font point-size="9"></font>
    % Therefore, omit the label line entirely when LabelBr is empty.
    (   LabelBr == ''
    ->  LabelLine = ''
    ;   format(atom(LabelLine), '<font point-size="9">~a</font><br/>', [LabelBr])
    ),

    atomic_list_concat([
        '~a [shape=box style=rounded margin="0.12,0.18"',
        '~a',              % UrlAttrs (includes leading space when non-empty)
        ' label=<',
            '<b>module ~a</b><br/>',
            '~a',
            '~a~w<br/>',
            '<font point-size="9">-&gt; ~a</font>',
        '>]~n'
    ], Fmt),

    format(Output, Fmt,
           [Id, UrlAttrs, Id, LabelLine, CallBr, Suffix, CalleeBase]),

    format(Output, "~a -> ~a~n", [ParentId, Id]),
    !.



ac_format_dot_goal(Output, ParentId, _Depth, ac_pattern_ref(Id, Label, PatternId, Args) ) :-
    ( ref_is_undefined(PatternId, Args) -> Suffix = '  [UNDEFINED]' ; Suffix = '' ),
    % format(Output,
    %        "~a [shape=box style=rounded margin=\"0.12,0.18\" label=<<b>module ~a</b><br/><font point-size=\"9\">~a</font><br/>~w(~w)~w>]~n",
    %        [Id, Id, Label, PatternId, Args, Suffix]),
	ac_format_dot_call_br(PatternId, Args, CallBr),
	ac_format_dot_identifier_words(Label, LabelWords),
	ac_format_dot_label_br_ify(LabelWords, LabelBr),

	% Avoid empty HTML-like tags in DOT labels.
	(   LabelBr == ''
	->  LabelLine = ''
	;   format(atom(LabelLine), '<font point-size="9">~a</font><br/>', [LabelBr])
	),
	format(Output,
	   "~a [shape=box style=rounded margin=\"0.12,0.18\" label=<<b>module ~a</b><br/>~a~a~w>>]~n",
	   [Id, Id, LabelLine, CallBr, Suffix]),

    format(Output, "~a -> ~a~n", [ParentId, Id]),
    !.

% ac_format_dot_goal(Output, ParentId, _Depth, ac_pattern_ref(PatternId, Args) ) :-
% 	ac_format_dot_counter_next(C),
% 	atomic_concat('module_', C, Id),
% 	format(Output, "~a [shape=box style=rounded margin=\"0.12,0.18\" label=<<b>module ~a</b><br/><font point-size=\"9\">~w(~w)</font>>]~n",
% 	       [Id, Id, PatternId, Args]),
% 	format(Output, "~a -> ~a~n", [ParentId, Id]),
% 	!.

ac_format_dot_goal(Output, ParentId, _Depth, ac_pattern_ref(PatternId, Args) ) :-
    ( ref_is_undefined(PatternId, Args) -> Suffix = '  [UNDEFINED]' ; Suffix = '' ),
    ac_format_dot_counter_next(C),
    atomic_concat('module_', C, Id),
    format(Output,
           "~a [shape=box style=rounded margin=\"0.12,0.18\" label=<<b>module ~a</b><br/><font point-size=\"9\">~w(~w)~w</font>>]~n",
           [Id, Id, PatternId, Args, Suffix]),
    format(Output, "~a -> ~a~n", [ParentId, Id]),
    !.

ac_format_dot_goal(Output, ParentId, Depth, evidence(Id, Label, Category, Claim, Context, XRef) ) :-
	ac_evidence(Category, Claim, Context, _AArgs, XRef, Status),
	ac_format_dot_evidence_color(Status, Color),
	ac_format_dot_label_br_ify(Claim, ClaimBr),
	format(Output, "~a [shape=ellipse label=<<b>evidence ~a</b><br/><font point-size=\"9\">~a</font><br/><font point-size=\"9\">~a</font><br/>~a<br/>~a xref: ~a> color=~a]~n",
	       [Id, Id, Category, Label, ClaimBr, Status, XRef, Color]),
	format(Output, "~a -> ~a~n", [ParentId, Id]),
	maplist(ac_format_dot_context( Output, Id, Depth), Context), !.

ac_format_dot_goal(Output, ParentId, Depth, evidence(Category, Claim, Context, XRef) ) :-
	ac_format_dot_evidence(Output, ParentId, Depth, evidence(Category, Claim, Context, XRef)).


				% ac_format_dot_evidence(+Output, +ParentId, +Depth, +Evidence)

ac_format_dot_evidence(Output, ParentId, Depth, evidence(Category, Claim, Context, XRef)) :-
	ac_evidence(Category, Claim, Context, _AArgs, XRef, Status),
	ac_format_dot_counter_next(Index),
	atomic_concat('evidence_', Index, Id),
	ac_format_dot_evidence_color(Status, Color),
	ac_format_dot_label_br_ify(Claim, ClaimBr),
	format(Output, "~a [shape=ellipse label=<<b>evidence ~a</b><br/><font point-size=\"9\">~a</font><br/>~a<br/>~a xref: ~a> color=~a]~n",
	       [Id, Id, Category, ClaimBr, Status, XRef, Color]),
	% format(Output, "~a [shape=ellipse label=<<b>~a</b><br/>~a<br/>~a xref: ~a> color=~a]~n",
	%        [Id, Category, ClaimBr, Status, XRef, Color]),

	format(Output, "~a -> ~a~n", [ParentId, Id]),
	maplist(ac_format_dot_context( Output, Id, Depth), Context), !.

ac_format_dot_evidence_color(valid, black) :- true, !.
ac_format_dot_evidence_color(invalid, red) :- true, !.
ac_format_dot_evidence_color(_, blue).

				% ac_format_dot_context(+Output, +ParentId, +Depth, +Clause)

ac_format_dot_context(Output, ParentId, Depth, context(Id, Label, Text)) :-
	ac_format_dot_context_aux2(Output, ParentId, Depth, context, Id, Label, Text).

ac_format_dot_context(Output, ParentId, Depth, justification(Id, Label, Text)) :-
	ac_format_dot_context_aux2(Output, ParentId, Depth, justification, Id, Label, Text).

ac_format_dot_context(Output, ParentId, Depth, assumption(Id, Label, Text)) :-
	ac_format_dot_context_aux2(Output, ParentId, Depth, assumption, Id, Label, Text).

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
	format(Output, "~a [shape=rectangle style=rounded label=<<b>~a ~a</b><br/>~a>]~n",
	       [Id, Category, Id, TextBr]),
	% format(Output, "~a [shape=rectangle style=rounded label=<<b>~a</b><br/>~a>]~n", [Id, Category, TextBr]),

	format(Output, "{ rank=same; ~a -> ~a [style=dashed]; }~n", [ParentId, Id]).

				% ac_format_dot_counter_init, ac_format_dot_counter_next(-X)

ac_format_dot_context_aux2(Output, ParentId, _Depth, Category, Id, Label, Text) :-
	ac_format_dot_label_br_ify(Text, TextBr),
	format(Output, "~a [shape=rectangle style=rounded label=<<b>~a ~a</b><br/><font point-size=\"9\">~a</font><br/>~a>]~n",
			[Id, Category, Id, Label, TextBr]),
	format(Output, "{ rank=same; ~a -> ~a [style=dashed]; }~n", [ParentId, Id]).
								
ac_format_dot_counter_init :-
	retractall(ac_format_dot_counter(_)),
	assertz( ac_format_dot_counter(0) ).

ac_format_dot_counter_next(X) :-
	ac_format_dot_counter(LastX),
	X is LastX + 1,
	retractall(ac_format_dot_counter(_)),
	assertz( ac_format_dot_counter(X) ).


				% label_text(+Term, -Text) 
				% Render structured label terms for DOT/HTML
				%   currently  just missing_pattern_ref
label_text(missing_pattern_ref(PatternId, Args), Text) :- !,
    format(string(Text),
           "pattern reference : ~w(~w)  [UNDEFINED]",
           [PatternId, Args]).

label_text(Text, Text).


				% Render PatternId(Args) as a wrap-friendly string
				% and then apply the existing <br/> wrapper.
ac_format_dot_call_br(PatternId, Args, CallBr) :-
    format(string(S0), "~w(~w)", [PatternId, Args]),
    dot_call_breakpoints(S0, S1),
    ac_format_dot_label_br_ify(S1, CallBr).

				% Introduce spaces after punctuation so split_string/2 creates break opportunities.
dot_call_breakpoints(S0, S) :-
    re_replace(','/g, ', ', S0, S1),
    re_replace('\\('/g, '( ', S1, S2),
    re_replace('\\)'/g, ' )', S2, S3),
    re_replace('\\['/g, '[ ', S3, S4),
    re_replace('\\]'/g, ' ]', S4, S5),
    re_replace('\\{'/g, '{ ', S5, S6),
    re_replace('\\}'/g, ' }', S6, S).


				% Convert an identifier-like label into a space-separated string
				% with word breaks at underscores and CamelCase boundaries
				% so it can be wrapped by ac_format_dot_label_br_ify/2.
ac_format_dot_identifier_words(Label0, WordsString) :-
    (   string(Label0) -> S0 = Label0
    ;   atom(Label0)   -> atom_string(Label0, S0)
    ;   % fall back to a single token
        term_string(Label0, S0)
    ),
    split_identifier_words(S0, Words),
    atomic_list_concat(Words, ' ', WordsString).

split_identifier_words(S, Words) :-
    string_codes(S, Cs),
    split_identifier_words_codes(Cs, [], [], RevWords),
    reverse(RevWords, Words).

split_identifier_words_codes([], CurrRev, Acc, Out) :-
    ( CurrRev = [] -> Out = Acc
    ; reverse(CurrRev, WCs),
      string_codes(W, WCs),
      Out = [W|Acc]
    ).
split_identifier_words_codes([C|Cs], CurrRev, Acc, Out) :-
    (   C =:= 0'_
    ;   C =:= 0'-
    ),
    !,
    split_identifier_words_codes(Cs, [], Acc, Out0),
    % flush current token (if any) before continuing
    ( CurrRev = [] -> Out = Out0
    ; reverse(CurrRev, WCs),
      string_codes(W, WCs),
      Out = [W|Out0]
    ).
split_identifier_words_codes([C|Cs], CurrRev, Acc, Out) :-
    % CamelCase boundary: lower/digit followed by upper starts a new word
    Cs = [Next|_],
    is_lower_or_digit(C),
    is_upper(Next),
    CurrRev \= [],
    !,
    reverse(CurrRev, WCs),
    string_codes(W, WCs),
    split_identifier_words_codes(Cs, [], [W|Acc], Out).
split_identifier_words_codes([C|Cs], CurrRev, Acc, Out) :-
    split_identifier_words_codes(Cs, [C|CurrRev], Acc, Out).

is_upper(C) :- C >= 0'A, C =< 0'Z.
is_lower_or_digit(C) :-
    (C >= 0'a, C =< 0'z) ; (C >= 0'0, C =< 0'9).


				%
				% ac_format_dot_text_br_ify(+Text, -TextWithBr)
				%

ac_format_dot_label_br_ify(Text0, TextWithBr) :-
	label_text(Text0, Text),
	split_string(Text, WordList), % split_string(Text, ' ', ' ', WordList),
	ac_format_dot_label_br_ify_aux('', 0, WordList, TextWithBr).

ac_format_dot_label_br_ify_aux(IText, _Count, [], IText) :- !.

ac_format_dot_label_br_ify_aux(IText, Count, WordList, OText) :-
	Count > 18, !, atomic_concat(IText, '<br/>', ITextBr),
	ac_format_dot_label_br_ify_aux(ITextBr, 0, WordList, OText).

ac_format_dot_label_br_ify_aux(IText, Count, [Word | WordList], OText) :-
	( Count == 0 -> IText_ = IText, SpaceLen = 0 ; atomic_concat(IText, ' ', IText_), SpaceLen = 1),
        atomic_concat(IText_, Word, IText_Word),
	string_length(Word, WordLength), NewCount is Count + WordLength + SpaceLen,
	ac_format_dot_label_br_ify_aux(IText_Word, NewCount, WordList, OText).

				%
				%
				% ac_format_html(+Output, +ACInstance)
				%

ac_format_html(Output, ac_instance(PatternId, AArgs, InstId, Goal, Log)) :-
	ac_instance_basename( ac_instance(PatternId, AArgs, InstId, Goal, Log), Basename),

	format(Output, "<h2> ~a </h2>~n", [Basename]),
	format(Output, "<h3>Pattern '~a'</h2>~n", [PatternId]),
				% actual args
	maplist( ac_format_html_arg(Output), AArgs),
				% svg embedding
	format(Output, "<hr><h3>GSN Representation</h3>~n", []),

	% format(Output, '<img src="~a.svg" alt="graphical view">~n', [Basename]),
        % format(Output, '<object data="~a.svg" type="image/svg+xml" width="100%" height="900">~n', [Basename]),
        % format(Output, '  <p>Your browser does not support inline SVG. Open <a href="~a.svg">the SVG</a>.</p>~n', [Basename]),
        % format(Output, '</object>~n', []),

	% svg embedding (scrollable, preserves size, no compression to fit)
	format(Output,'<p><a href="~a.svg" target="_blank">Scroll down or click to open GSN in a new tab (for zoom)</a></p>~n',
		[Basename]),
	format(Output,'<iframe src="~a.svg" style="width:100%; height:900px; border:0;" loading="lazy"></iframe>~n',
		[Basename]),

				% error log
	format(Output, "<hr><h3>Error Log</h3>~n", []),
	emit_missing_pattern_report_html(Output),
	log_format(Output, 'html', Log).

ac_format_html_arg(Output, arg(Name, Category, Value)) :- !,
	format(Output, "<li>~a : ~w = ", [Name, Category]),
	writeq(Output, Value),
	format(Output, '~n', []).

ac_format_html_arg(Output, ArgVal) :-
	writeq(Output, ArgVal),
	format(Output, '~n', []).

emit_missing_pattern_report_html(Output) :-
	collect_undefined_pattern_refs(Refs),
	Refs \= [],
	!,
	% format(Output, "<h3>Undefined Pattern References</h3>~n", []),
	format(Output, "<ul>~n", []),
	forall(member(ref(PatternId, Args), Refs),
			format(Output,
					"<li>pattern reference : ~w(~w) <span class='undef'>[UNDEFINED]</span></li>~n",
					[PatternId, Args])),
	format(Output, "</ul>~n", []).
emit_missing_pattern_report_html(_Output).
	

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

% LogItem is a list of terms (persisted Log is list(list(acyclic))).
% Render each term in a simple, readable way.
log_format_item(Output, 'html', Terms) :-
    is_list(Terms),
    format(Output, '<li>', []),
    forall(member(T, Terms),
           ( writeq(Output, T),
             format(Output, ' ', [])
           )),
    format(Output, '~n', []),
    !.

% Ultimate fallback: LogItem is not in an expected shape; still render it.
log_format_item(Output, 'html', LogItem) :-
    format(Output, '<li>', []),
    writeq(Output, LogItem),
    format(Output, '~n', []),
    !.


				%
				%
				% ac_instance_basename(+ACInstance, -Basename)
				%

ac_instance_basename( ac_instance(PatternId, _AArgs, _InstId, Goal, _Log), Basename) :-
	goal_id(Goal, GoalId),
	atomic_list_concat([PatternId, '_', GoalId], Basename).

goal_id( goal(Id, _, _, _, _), Id ).

goal_id( goal(Id, _, _, _), Id ).

goal_id( null_goal(Id), Id).

%% dot_html_escape(+In, -Out) is det.
%  Escape &, <, > for Graphviz HTML-like labels.
dot_html_escape(In, Out) :-
    % Normalize to string for processing.
    (   string(In) -> S0 = In
    ;   atom(In)   -> atom_string(In, S0)
    ;   % Fallback: render any term.
        term_string(In, S0)
    ),
    % Escape order matters: & first.
    re_replace('&'/g, '&amp;', S0, S1),
    re_replace('<'/g, '&lt;',  S1, S2),
    re_replace('>'/g, '&gt;',  S2, S3),
    atom_string(Out, S3).


% Collect all undefined pattern references that appear in the instantiated case.
collect_undefined_pattern_refs(Refs) :-
    findall(ref(PatternId, Args),
            (   ac_pattern_ref_node(PatternId, Args),
                ref_is_undefined(PatternId, Args)
            ),
            RawRefs),
    sort(RawRefs, Refs).

% True for every pattern reference node in the instantiated case.
ac_pattern_ref_node(PatternId, Args) :-
    ac_instance(_RootPid, _RootArgs, _InstId, Goal, _Log),
    goal_pattern_refs(Goal, PatternId, Args).

% Walk the instantiated goal tree and extract pattern references.
goal_pattern_refs(ac_pattern_ref(PatternId, Args), PatternId, Args).
goal_pattern_refs(ac_pattern_ref(_Id, _Label, PatternId, Args), PatternId, Args).
goal_pattern_refs(ac_pattern_ref(_Id, _Label, PatternId, Args, _RefInfo), PatternId, Args).

goal_pattern_refs(goal(_Id, _Label, _Claim, _Ctx, Subgoals), PatternId, Args) :-
    member(G, Subgoals),
    goal_pattern_refs(G, PatternId, Args).

goal_pattern_refs(strategy(_Id, _Ctx, Subgoals), PatternId, Args) :-
    member(G, Subgoals),
    goal_pattern_refs(G, PatternId, Args).


% True iff the referenced pattern instance does not exist in the attached case.
ref_is_undefined(PatternId, Args) :-
    \+ ac_instance(PatternId, Args, _InstId, _Goal, _Log).

/*
with_output_to(Output, Goal, []) =>
   with_output_to(Output, Goal).
with_output_to(Output, Goal, Options) =>
    option(capture(Streams), Options, []),
    must_be(list(oneof([user_output,user_error])), Streams),
    with_output_to(
	Output,
	setup_call_cleanup(
	    output_state(State, Streams),
	    capture(Goal, Streams, Options),
	    restore_output(State, Streams))).

capture(Goal, Streams, Options) :-
    current_output(S),
    (   option(color(true), Options)
    ->  set_stream(S, tty(true))
    ;   true
      ),
      maplist(capture_output(S), Streams),
      once(Goal),
      maplist(flush_output, [current_output|Streams]).
  
  output_state(State, Streams) :-
      maplist(stream_id, Streams, State).
  
  stream_id(Alias, Stream) :-
      stream_property(Stream, alias(Alias)).
  
  restore_output(State, Streams) :-
      maplist(restore_stream, Streams, State).
  
  restore_stream(Alias, Stream) :-
      set_stream(Stream, alias(Alias)).
  
  capture_output(S, Alias) :-
      set_stream(S, alias(Alias))

*/
