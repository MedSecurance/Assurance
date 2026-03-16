%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%
% ACO parser / translator regression tests (draft)
%
% Intended to be loaded in the same environment/style as src/etb_test.pl.
% These tests exercise the string-based ACO pipeline directly so they can
% serve as a backward-compatibility net before parser changes.
%
% Canonical usage pattern:
%   - add selected tc_aco_parse_xx predicates to etb_startup_tests/1 or
%     etb_regression_tests/1, or
%   - place this content into a new aco_test.pl and invoke similarly.
%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%

aco_parser_regression_tests([
    tc_aco_parse_01, tc_aco_parse_02, tc_aco_parse_03, tc_aco_parse_04,
    tc_aco_parse_05, tc_aco_parse_06, tc_aco_parse_07, tc_aco_parse_08,
    tc_aco_parse_09, tc_aco_parse_10, tc_aco_parse_11, tc_aco_parse_12,
    tc_aco_parse_13, tc_aco_parse_14, tc_aco_parse_15, % tc_aco_parse_16,
    tc_aco_parse_17, tc_aco_parse_18, tc_aco_parse_19, tc_aco_parse_20,
    tc_aco_parse_21, tc_aco_parse_22, tc_aco_parse_23, tc_aco_parse_24
]).

%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%
% Helpers

% Success case: exact APL-ish terms, no parser/semantic error messages.
tc_aco_string_apl_ok(SourceName, AcoString, ExpectedTerms) :-
    aco_core:translate_aco_string(SourceName, AcoString, GotTerms, Messages),
    \+ tc_aco_has_error(Messages),
    % normalized:  GotTerms == ExpectedTerms
    normalize_terms(ExpectedTerms, normalized_result(NonRelations, RelationsSorted, Diagnostics)),
    normalize_terms(GotTerms, normalized_result(NonRelations, RelationsSorted, Diagnostics)).

% Error-presence case: exact APL-ish terms plus required error functors.
tc_aco_string_apl_error(SourceName, AcoString, ExpectedTerms, RequiredErrorSigs) :-
    aco_core:translate_aco_string(SourceName, AcoString, GotTerms, Messages),
    % normalized:  GotTerms == ExpectedTerms
    normalize_terms(ExpectedTerms, normalized_result(NonRelations, RelationsSorted, Diagnostics)),
    normalize_terms(GotTerms, normalized_result(NonRelations, RelationsSorted, Diagnostics)),
    tc_aco_error_signatures(Messages, ErrorSigs),
    subset(RequiredErrorSigs, ErrorSigs).

% Canonicalization case.
tc_aco_string_canon_ok(SourceName, AcoString, ExpectedCanon) :-
    aco_core:canonicalize_aco_string(SourceName, AcoString, GotCanon, _Messages),
    GotCanon == ExpectedCanon.

% Smoke/file regression: no parser/semantic error messages and required terms exist.
tc_aco_file_contains_terms_ok(FileName, RequiredTerms) :-
    param:test_aco_dir(TestAcoDir),
    atomic_list_concat([TestAcoDir, FileName], '/', FullFile),
    read_file_to_string(FullFile, Raw, [newline(detect)]),
    aco_core:translate_aco_string(FileName, Raw, GotTerms, Messages),
    % normalized:  RequiredTerms is subset of GotTerms
    normalize_terms(RequiredTerms, normalized_result(ReqNonRelations, ReqRelationsSorted, ReqDiagnostics)),
    normalize_terms(GotTerms, normalized_result(GotNonRelations, GotRelationsSorted, GotDiagnostics)),
    \+ tc_aco_has_error(Messages),
    subset(ReqNonRelations, GotNonRelations),
    subset(ReqRelationsSorted, GotRelationsSorted),
    subset(ReqDiagnostics, GotDiagnostics).

% Return only the signatures of error-ish messages that matter for regression.
tc_aco_error_signatures(Messages, Signatures) :-
    findall(F/A,
            ( member(M, Messages),
              tc_aco_message_is_error(M),
              functor(M, F, A)
            ),
            Signatures0),
    sort(Signatures0, Signatures).

tc_aco_has_error(Messages) :-
    member(M, Messages),
    tc_aco_message_is_error(M),
    !.

% Current parser/semantic error families exposed through translate_aco_string/4.
tc_aco_message_is_error(indentation_jump(_)).
tc_aco_message_is_error(relation_parse_error(_, _)).
tc_aco_message_is_error(relation_undefined_ids(_, _, _)).
tc_aco_message_is_error(relation_unexpected_header_in_relation_section(_, _)).
tc_aco_message_is_error(relation_unexpected_nonrelation_in_relation_section(_, _, _)).
tc_aco_message_is_error(relation_unexpected_line_in_relation_section(_)).
tc_aco_message_is_error(indent_directive_error(_, _)).

is_relation_term(supported_by(_, _)).
is_relation_term(in_context_of(_, _)).

normalize_terms(Terms, normalized_result(NonRelations, RelationsSorted, Diagnostics)) :-
    partition(is_relation_term, Terms, Relations, Rest),
    partition(is_diagnostic_term, Rest, Diagnostics, NonRelations),
    sort(Relations, RelationsSorted).

is_diagnostic_term(error(_)).
is_diagnostic_term(warning(_)).
is_diagnostic_term(info(_)).

%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%
% 01-18: small exact parser/translation regression cases

% 01. Positive minimal coverage:
% valid single Goal with explicit ID and ordinary body;
% verifies the simplest successful Goal -> block/4 translation path.
tc_aco_parse_01 :-
    Aco = "Goal G1 top:\n  Body.\n",
    Expected = [
        block('G1', goal, top, 'Body.')
    ],
    tc_aco_string_apl_ok('<tc_aco_parse_01>', Aco, Expected).

% 02. Positive header/body coverage:
% valid single Goal with body text beginning on the header line after the colon;
% verifies inline body-after-colon handling.
tc_aco_parse_02 :-
    Aco = "Goal G1 top: Body on header.\n",
    Expected = [
        block('G1', goal, top, 'Body on header.')
    ],
    tc_aco_string_apl_ok('<tc_aco_parse_02>', Aco, Expected).

% 03. Positive body-text coverage:
% valid single Goal with a multi-line body;
% verifies body-line harvesting and newline joining.
tc_aco_parse_03 :-
    Aco = "Goal G1 top:\n  First line.\n  Second line.\n",
    Expected = [
        block('G1', goal, top, 'First line.\nSecond line.')
    ],
    tc_aco_string_apl_ok('<tc_aco_parse_03>', Aco, Expected).

% 04. Positive structural coverage:
% valid Goal with indented Context child;
% verifies default indentation-derived in_context_of/2 relation.
tc_aco_parse_04 :-
    Aco = "Goal G1 top:\n  Body.\n  Context C1 ctx:\n    C body.\n",
    Expected = [
        block('G1', goal, top, 'Body.'),
        block('C1', context, ctx, 'C body.'),
        in_context_of('G1', 'C1')
    ],
    tc_aco_string_apl_ok('<tc_aco_parse_04>', Aco, Expected).

% 05. Positive structural coverage:
% valid Goal with indented Evidence child;
% verifies default indentation-derived supported_by/2 relation for evidence.
tc_aco_parse_05 :-
    Aco = "Goal G1 top:\n  Body.\n  Evidence E1 ev:\n    E body.\n",
    Expected = [
        block('G1', goal, top, 'Body.'),
        block('E1', evidence, ev, 'E body.'),
        supported_by('G1', 'E1')
    ],
    tc_aco_string_apl_ok('<tc_aco_parse_05>', Aco, Expected).

% 06. Positive structural coverage:
% valid Goal with indented Module reference child;
% verifies default indentation-derived supported_by/2 relation for module references.
tc_aco_parse_06 :-
    Aco = "Goal G1 top:\n  Body.\n  Module M1 mod:\n    Ref body.\n",
    Expected = [
        block('G1', goal, top, 'Body.'),
        block('M1', module, mod, 'Ref body.'),
        supported_by('G1', 'M1')
    ],
    tc_aco_string_apl_ok('<tc_aco_parse_06>', Aco, Expected).

% 07. Positive structural coverage:
% valid Goal with indented Strategy child and Goal grandchild;
% verifies default supported_by/2 relations across Goal -> Strategy -> Goal.
tc_aco_parse_07 :-
    Aco = "Goal G1 top:\n  Body.\n  Strategy S1 decomp:\n    Strat body.\n    Goal G2 child:\n      Child body.\n",
    Expected = [
        block('G1', goal, top, 'Body.'),
        block('S1', strategy, decomp, 'Strat body.'),
        block('G2', goal, child, 'Child body.'),
        supported_by('G1', 'S1'),
        supported_by('S1', 'G2')
    ],
    tc_aco_string_apl_ok('<tc_aco_parse_07>', Aco, Expected).

% 08. Positive structural coverage:
% valid Goal with Assumption and Justification children and no body text of its own;
% verifies that Assumption and Justification behave as supported_by children and
% that an empty Goal body is represented consistently.
tc_aco_parse_08 :-
    Aco = "Goal G1 top:\n  Assumption A1 asm:\n    A body.\n  Justification J1 just:\n    J body.\n",
    Expected = [
        block('G1', goal, top, ''),
        block('A1', assumption, asm, 'A body.'),
        block('J1', justification, just, 'J body.'),
        supported_by('G1', 'A1'),
        supported_by('G1', 'J1')
    ],
    tc_aco_string_apl_ok('<tc_aco_parse_08>', Aco, Expected).

% 09. Positive label-syntax coverage:
% valid Goal with quoted multi-word short label;
% verifies quoted-label parsing and preservation.
tc_aco_parse_09 :-
    Aco = "Goal G1 \"Top Claim\":\n  Body.\n",
    Expected = [
        block('G1', goal, 'Top Claim', 'Body.')
    ],
    tc_aco_string_apl_ok('<tc_aco_parse_09>', Aco, Expected).

% 10. Positive robustness coverage:
% valid Goal using an unquoted multi-word short label accepted by the current parser;
% verifies the current tolerant behavior for this label form.
tc_aco_parse_10 :-
    Aco = "Goal G1 Top Claim:\n  Body.\n",
    Expected = [
        block('G1', goal, 'Top Claim', 'Body.')
    ],
    tc_aco_string_apl_ok('<tc_aco_parse_10>', Aco, Expected).

% 11. Positive ID-generation coverage:
% valid mixed-node outline with omitted IDs;
% verifies auto-generated IDs across node types and ordinary derived relations.
tc_aco_parse_11 :-
    Aco = "Goal top:\n  Context ctx:\n    C body.\n  Goal child:\n    Child body.\n",
    Expected = [
        block(goal_0, goal, top, ''),
        block(context_1, context, ctx, 'C body.'),
        block(goal_2, goal, child, 'Child body.'),
        in_context_of(goal_0, context_1),
        supported_by(goal_0, goal_2)
    ],
    tc_aco_string_apl_ok('<tc_aco_parse_11>', Aco, Expected).

% 12. Positive unit-header coverage:
% valid Case header plus one Goal;
% verifies Case metadata preservation via case_header/2.
tc_aco_parse_12 :-
    Aco = "Case: Demo - tiny scope\nGoal G1 top:\n  Body.\n",
    Expected = [
        case_header('Demo', 'tiny scope'),
        block('G1', goal, top, 'Body.')
    ],
    tc_aco_string_apl_ok('<tc_aco_parse_12>', Aco, Expected).

% 13. Positive explicit-relation coverage:
% valid Case unit; ordinary indentation already makes G2 a child/supporter of G1;
% relation trailer uses canonical "is supported by" form;
% test intent is to verify that the explicit relation form is accepted and yields
% the expected supported_by/2 relation without disturbing the ordinary result.
tc_aco_parse_13 :-
    Aco = "Case: rel13 - explicit support\nGoal G1 top:\n  Body.\n  Goal G2 child:\n    Child body.\nG1 is supported by G2.\n",
    Expected = [
        case_header('rel13', 'explicit support'),
        block('G1', goal, top, 'Body.'),
        block('G2', goal, child, 'Child body.'),
        supported_by('G1', 'G2')
    ],
    tc_aco_string_apl_ok('<tc_aco_parse_13>', Aco, Expected).

% 14. Positive explicit-relation coverage:
% valid Case unit; ordinary indentation already makes G2 a child/supporter of G1;
% relation trailer uses reversed "supports" form;
% test intent is to verify acceptance of the reversed wording and production of
% the same supported_by/2 relation as tc_aco_parse_13.
tc_aco_parse_14 :-
    Aco = "Case: rel14 - reversed support\nGoal G1 top:\n  Body.\n  Goal G2 child:\n    Child body.\nG2 supports G1.\n",
    Expected = [
        case_header('rel14', 'reversed support'),
        block('G1', goal, top, 'Body.'),
        block('G2', goal, child, 'Child body.'),
        supported_by('G1', 'G2')
    ],
    tc_aco_string_apl_ok('<tc_aco_parse_14>', Aco, Expected).

% 15. Positive explicit-relation coverage:
% valid Case unit; ordinary indentation already makes C1 a context child of G1;
% relation trailer uses canonical "is in context of" form;
% test intent is to verify acceptance of the explicit wording and production of
% the expected in_context_of/2 relation without changing the ordinary result.
tc_aco_parse_15 :-
    Aco = "Case: rel15 - explicit context\nGoal G1 top:\n  Body.\n  Context C1 ctx:\n    C body.\nG1 is in context of C1.\n",
    Expected = [
        case_header('rel15', 'explicit context'),
        block('G1', goal, top, 'Body.'),
        block('C1', context, ctx, 'C body.'),
        in_context_of('G1', 'C1')
    ],
    tc_aco_string_apl_ok('<tc_aco_parse_15>', Aco, Expected).

% 16. Parked / future explicit-relation coverage:
% subject-first plural "provides context for" form.
% This case is intentionally parked for now rather than included in the current
% must-pass regression tranche, because a clean valid ACO shape for the intended
% semantics was not yet settled under current ACO/GSN alignment decisions.
%
% tc_aco_parse_16 :-
%     Aco = "Case: rel16 - provides context\n...",
%     Expected = [
%         ...
%     ],
%     tc_aco_string_apl_ok('<tc_aco_parse_16>', Aco, Expected).

% 17. Positive lexical robustness coverage:
% valid outline with trailing and whole-line percent comments;
% verifies comment stripping without disturbing parse/translation.
tc_aco_parse_17 :-
    Aco = "Goal G1 top: Body. % trailing comment\n% full line comment\nContext C1 ctx:\n  C body.\nG1 is in context of C1.\n",
    Expected = [
        block('G1', goal, top, 'Body.'),
        block('C1', context, ctx, 'C body.'),
        in_context_of('G1', 'C1')
    ],
    tc_aco_string_apl_ok('<tc_aco_parse_17>', Aco, Expected).

% 18. Positive lexical robustness coverage:
% valid outline preceded by a block comment;
% verifies block-comment stripping without disturbing parse/translation.
tc_aco_parse_18 :-
    Aco = "/* block\n   comment */\nGoal G1 top:\n  Body.\n",
    Expected = [
        block('G1', goal, top, 'Body.')
    ],
    tc_aco_string_apl_ok('<tc_aco_parse_18>', Aco, Expected).

%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%
% 19-22: canonicalization and error regression cases

% 19. Positive canonicalization coverage:
% valid no-ID outline canonicalized into stable hierarchical IDs;
% verifies the simplest canon path.
tc_aco_parse_19 :-
    Aco = "Goal top:\n  Body.\n",
    ExpectedCanon = 'Goal G1. top:\n  Body.\n',
    tc_aco_string_canon_ok('<tc_aco_parse_19>', Aco, ExpectedCanon).

% 20. Positive canonicalization coverage:
% valid outline with pre-existing ad hoc IDs and an explicit support relation;
% verifies canonical ID rewriting in both node headers and relation sentences.
tc_aco_parse_20 :-
    Aco = "Goal Gx top:\n  Goal Gy child:\nGx is supported by Gy.\n",
    ExpectedCanon = 'Goal G1. top:\n  Goal G1.1 child:\n\nG1. is supported by G1.1.',
    tc_aco_string_canon_ok('<tc_aco_parse_20>', Aco, ExpectedCanon).

% 21. Positive permissive-indentation coverage:
% current parser accepts this deeper indentation and still attaches G2 under G1;
% verifies existing behavior rather than a stricter future indentation policy.
tc_aco_parse_21 :-
    Aco = "Goal G1 top:\n    Goal G2 tooDeep:\n      Body.\n",
    Expected = [
        block('G1', goal, top, ''),
        block('G2', goal, tooDeep, 'Body.'),
        supported_by('G1', 'G2')
    ],
    tc_aco_string_apl_ok('<tc_aco_parse_21>', Aco, Expected).

% 21a. Negative structural coverage:
% invalid indentation jump;
% verifies that indentation_jump/1 is reported while partial block harvesting is retained.
tc_aco_parse_21a :-
    Aco = "Goal G1 top:\n    Goal G2 tooDeep:\n      Body.\n",
    Expected = [
        block('G1', goal, top, ''),
        block('G2', goal, tooDeep, 'Body.')
    ],
    tc_aco_string_apl_error('<tc_aco_parse_21>', Aco, Expected, [indentation_jump/1]).

% 22. Negative relation coverage:
% explicit support relation references an undefined ID;
% verifies relation_undefined_ids/3 while retaining successfully parsed blocks.
tc_aco_parse_22 :-
    Aco = "Goal G1 top:\n  Body.\nG1 is supported by G999.\n",
    Expected = [
        block('G1', goal, top, 'Body.')
    ],
    tc_aco_string_apl_error('<tc_aco_parse_22>', Aco, Expected, [relation_undefined_ids/3]).

%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%
% 23-24: larger smoke/regression cases from repository fixtures

% 23. Positive real-fixture smoke coverage:
% repository fixture op_plane.aco;
% verifies continued parsing of a representative larger case and presence of core anchor terms.
tc_aco_parse_23 :-
    tc_aco_file_contains_terms_ok('op_plane.aco', [
        case_header('Op Plane', 'component architecture assurance'),
        block('G0', goal, operationalPlane, 'The operational plane guarantees the {local policy} is met.'),
        block('C0', context, planeDefinition, 'The system model describes the plane and its {properties}.'),
        block('M0', module, interface, 'Interaction between components and compositions is as defined by the security architecture interface.'),
        supported_by('G0', 'G1'),
        supported_by('G0', 'G2'),
        supported_by('G0', 'M0'),
        in_context_of('G0', 'C0')
    ]).

% 24. Positive real-fixture smoke coverage:
% repository fixture min_test.aco;
% verifies continued parsing of mixed indentation/body syntax in a real example.
tc_aco_parse_24 :-
    tc_aco_file_contains_terms_ok('min_test.aco', [
        block('G1', goal, bioassistAssuredUse, 'Some descriptive body line\nAnother line'),
        block('Aflat', assumption, something, 'Assumption body'),
        supported_by('G1', 'Aflat')
    ]).

