% stored "built-in" procedures

:- module(procs, [proc/2, pmproc/2, defined_procs/1]).

:- dynamic([proc/2, pmproc/2]).

:- discontiguous proc/2.
:- discontiguous procs_defined/1.

:- if( exists_file('procs_etb.pl') ).
:- include('procs_etb.pl').
procs_defined(etb).
:- endif.

:- if( exists_file('procs_kb.pl') ).
:- include('procs_kb.pl').
procs_defined(kb).
:- endif.

:- if( exists_file('procs_repo.pl') ).
:- include('procs_repo.pl').
procs_defined(repo).
:- endif.

defined_procs(ProcSets) :- findall(ProcSet, procs_defined(ProcSet), ProcSets).
% e.g.: defined_procs([etb,kb,repo]).
