:- module(logging,
    [ log_event/3,          % +Level, +Source, +Event
      log_event/4,          % +Level, +Source, +Event, +Data
      collect_session_log/1,% -LogTerms
      clear_session_log/0,
      with_captured_log/2   % :Goal, -LogTerms
    ]).

:- use_module(com/param).

:- meta_predicate with_captured_log(0, -).

:- dynamic session_log/5.
% session_log(Timestamp, Level, Source, Event, Data).

log_event(Level, Source, Event) :-
    log_event(Level, Source, Event, []).

log_event(Level, Source, Event, Data) :-
    get_time(TStamp),
    assertz(session_log(TStamp, Level, Source, Event, Data)),
    gen_audit(Level, Source, Event, Data).

collect_session_log(Log) :-
    findall(log(T,L,S,E,D),
            session_log(T,L,S,E,D),
            Log).

clear_session_log :-
    retractall(session_log(_,_,_,_,_)).

with_captured_log(Goal, Log) :-
    clear_session_log,
    (   catch(Goal, E,
              ( log_event(error, system, exception, E),
                throw(E)))
    ->  true
    ;   true
    ),
    collect_session_log(Log).

% ----------------------------------------------------------------------
% hook into existing audit framework
% ----------------------------------------------------------------------

gen_audit(_Level, _Source, _Event, _Data) :-
    param:audit_logging(off), !.
gen_audit(Level, Source, Event, Data) :-
    param:audit_stream(Stream),
    param:audit_record(Fmt),
    get_time(Now),
    format_time(string(TS), '%FT%T%z', Now),
    format(Stream, Fmt,
           [ TS,
             Source,
             Event,
             [ level(Level), data(Data) ]
           ]).

  
% ----------------------------------------------------------------------
%% show_log/0
% ----------------------------------------------------------------------
  %
  %  Show the entire top-level ETB log in concise, human-readable form.
  
  show_log :-
      show_log(all).
  
  %% show_log(+What)
  %
  %  What = all            -> all entries in etb_log.pl
  %       = N (integer>0)  -> last N entries in etb_log.pl
  %       = provisional    -> all entries from provisional_evidence.log
  %       = Functor (atom) -> entries whose primary functor is Functor
  
  show_log(all) :-
      !,
      param:log_file_name(LogFile),
      show_log_file(LogFile, all).
  
  show_log(N) :-
      integer(N),
      N > 0,
      !,
      param:log_file_name(LogFile),
      show_log_file(LogFile, last(N)).
  
  show_log(provisional) :-
      !,
      provisional_log_file(File),
      show_log_file(File, all).
  
  show_log(Functor) :-
      atom(Functor),
      !,
      param:log_file_name(LogFile),
      show_log_file(LogFile, functor(Functor)).
  
  show_log(Other) :-
      format('show_log: unsupported argument ~q~n', [Other]).
  
  % ----------------------------------------------------------------------
  % Core file reading / formatting
  % ----------------------------------------------------------------------
  
  provisional_log_file(File) :-
      % Mirror evidence:log_provisional_category/4 path construction
      param:log_directory(LogDir0),
      atom_concat('../', LogDir0, LogDir),
      atomic_list_concat([LogDir, '/provisional_evidence.log'], File).
  
  show_log_file(File, Mode) :-
      (   exists_file(File)
      ->  read_terms(File, Terms),
          apply_log_mode(Mode, Terms, TermsToShow),
          forall(member(T, TermsToShow), pretty_log_term(T))
      ;   format('show_log: no log file ~q~n', [File])
      ).
  
  read_terms(File, Terms) :-
      setup_call_cleanup(
          open(File, read, In),
          read_all_terms(In, Terms),
          close(In)
      ).
  
  read_all_terms(In, Terms) :-
      read_term(In, Term, []),
      (   Term == end_of_file
      ->  Terms = []
      ;   Terms = [Term | Rest],
          read_all_terms(In, Rest)
      ).
  
  apply_log_mode(all, Terms, Terms) :- !.
  apply_log_mode(last(N), Terms, TermsN) :-
      length(Terms, Len),
      (   Len =< N
      ->  TermsN = Terms
      ;   Drop is Len - N,
          length(Prefix, Drop),
          append(Prefix, TermsN, Terms)
      ).
  apply_log_mode(functor(F), Terms, Filtered) :-
      include(term_has_functor(F), Terms, Filtered).
  
  term_has_functor(F, Term) :-
      functor(Term, F0, _),
      F0 == F.
  
  % ----------------------------------------------------------------------
  % Pretty-printing of log terms
  % ----------------------------------------------------------------------
  
  pretty_log_term(Term) :-
      (   Term = etb_log(TS, Level, Source, Msg)
      ->  format('[~w] ~w ~w: ~w~n', [TS, Level, Source, Msg])
      ;   Term = audit_log(TS, Source, Event, Data)
      ->  format('[~w] AUDIT ~w ~w: ~q~n', [TS, Source, Event, Data])
      ;   Term = provisional_evidence(CatName, Claim, Context, AArgs)
      ->  format('PROVISIONAL ~w~n', [CatName]),
          format('  Claim: ~q~n', [Claim]),
          format('  Context: ~q~n', [Context]),
          format('  Args: ~q~n', [AArgs])
      ;   % Fallback: concise generic printer
          format('~q.~n', [Term])
      ).
  