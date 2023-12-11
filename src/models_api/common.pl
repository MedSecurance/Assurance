
:- module(common, [ pp_attribute/1, pp_attributes/3,
		    
		    pp_constraint/1, pp_constraints/3,

		    attributes_lookup/4, constraint_attributes_lookup/4]).

				% attributes of the form 'name(value)'

pp_attribute(A) :-
	A =.. [Name, Value], format('# ~a=', Name), write(Value).

pp_attributes([], _, _).
pp_attributes([A | As], Pre, Post) :-
	format(Pre), pp_attribute(A), format(Post),
	pp_attributes(As, Pre, Post).


				% constraints of two forms i.e., 
				% - simple attributes 'name(value)'
				% - hardware element constraints
				%   'hw-category(id, [attr1, ..., attrn])'

pp_constraint(AtConstraint) :-
	AtConstraint =.. [Name, Value],
	format('Constraint ~a=', Name),
	write(Value).

pp_constraint(HwConstraint) :-
	HwConstraint =.. [HwCat, ConId, Attrs],
	format('Constraint ~a ~a = [', [HwCat, ConId]),
	pp_attributes(Attrs, ' ', ' '),
	format(']').

pp_constraints([], _, _).
pp_constraints([C | Cs], Pre, Post) :-
	format(Pre), pp_constraint(C), format(Post),
	pp_constraints(Cs, Pre, Post).


				%! attributes_lookup(+Name, +Default, +Attrs, -Value)

				% n.a. - normally, every attribute (name)
				% shall occur at most once in the list of
				% attributes; if not occuring at all, the Default
				% value is returned

attributes_lookup(Name, _Default, Attrs, Value) :-
	member(At, Attrs),
	At =.. [Name, Value], !.

attributes_lookup(_, Default, _, Default).

constraint_attributes_lookup(Name, Default, HwConstraint, Value) :-
	HwConstraint =.. [_, _, Attrs],
	attributes_lookup(Name, Default, Attrs, Value).