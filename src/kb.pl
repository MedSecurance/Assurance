% ETB Knowledge Base

:- module(kb, [load_specification_from_file/3,kb_reset/0]).

:- use_module([
	patterns, categories,
	models_api/model
  ]).

load_specification_from_file(_Type,_File,_Sid) :-
	true.

kb_reset :-
	true.
