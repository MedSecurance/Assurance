
:-module(stringutil, [split_string/2, atomics_to_string/3]).

				% workaround for split_string
				% split the string into tokens delimited by white spaces

split_string(T, L) :-
	string_codes(T, C), 
	reverse(C, Cr),
	split_list_aux(Cr, [], LCr),
	maplist(string_codes, Lr, LCr),
	reverse(Lr, L).

split_list_aux([], [], []).

split_list_aux([], [X|T], [[X|T]]).

split_list_aux([32|C], [], L) :- split_list_aux(C, [], L).

split_list_aux([32|C], [X|T], [[X|T]|L]) :- split_list_aux(C, [], L).

split_list_aux([X|C], T, L) :- X \= 32, split_list_aux(C, [X|T], L).


				% workaround for atomics_to_string

atomics_to_string(L, S, T) :-
	weave_aux(L, S, LS), atomic_list_concat(LS, T).

weave_aux([], _S, []).

weave_aux([W], _S, [W]).

weave_aux([W|L], S, [W | [S | T]]) :- weave_aux(L, S, T).
