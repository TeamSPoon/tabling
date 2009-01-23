%%%                                                                      %%%
%%%  A meta-interpreter for co-logic programming.                        %%%
%%%  Based on "colp.pro" by Luke Evans Simon.                            %%%
%%%                                                                      %%%
%%%  Written by Feliks Kluzniak at UTD (January 2009).                   %%%
%%%                                                                      %%%
%%%  Last update: 22 January 2009.                                       %%%
%%%                                                                      %%%
%%%  NOTE: Some of the code may be Eclipse-specific and may require      %%%
%%%        minor tweaking for other Prolog systems.                      %%%
%%%                                                                      %%%

%%% NOTE:
%%%
%%%    1. To load a program use the query:
%%%           ?- prog( filename ).
%%%       If the filename has no extension, ".clp" is added.
%%%
%%%       A coinductive predicate should be declared as such in the program
%%%       file, e.g.,
%%%           :- coinductive comember/2 .
%%%
%%%       To include files use the usual Prolog syntax:
%%%           :- [ file1, file2, ... ].
%%%
%%%    2. The program should contain no other directives. It may, however,
%%%       contain queries, which will be executed immediately upon reading.
%%%
%%%    3. If the program invokes a built-in predicate, that predicate must
%%%       be declared in the table builtin/1 below.

%%% LIMITATIONS: - The interpreted program should not contain cuts.
%%%              - Error detection is quite rudimentary.


:- ensure_loaded( [ '../general/top_level.ecl',
                    '../general/utilities.ecl'
                  ]
                ).



%%%%%  Built-in predicates  %%%%
%%
%%  NOTE: Just adding "!" won't do the trick, the main metainterpreter
%%        would have to be modified.

builtin( true         ).
builtin( false        ).
builtin( fail         ).
builtin( _ = _        ).
builtin( _ \= _       ).
builtin( \+( _ )      ).
builtin( once _       ).   % special treatment in solve/2
builtin( (_ ->_ ; _)  ).   % special treatment in solve/2
builtin( (_ ; _)      ).   % special treatment in solve/2
builtin( (_ , _)      ).   % special treatment in solve/2
builtin( writeln( _ ) ).
builtin( write( _ )   ).
builtin( nl           ).



%%%%%  Administration  %%%%%

:- dynamic coinductive/1 .         % e.g., coinductive( comember( _, _ ) ).

:- op( 1000, fy, coinductive ).    % allow  ":- coinductive p/k ."
:- op( 1000, fy, bottom ).         % allow  ":- bottom p/k ."        (see below)
:- op( 1000, fy, top ).            % allow  ":- top p/k ."           (see below)


default_extension( ".clp" ).       % default extension for file names


%% initialise:
%% Get rid of previous state.

initialise :-
        retractall( coinductive( _ ) ).


%% The legal directives (check external form only).
%% Note: ":- top ..." and ":- bottom ..." are ignored by this metainterpreter,
%%       and are allowed only to allow the same examples to be translated
%%       by "translate_colp".

legal_directive( coinductive _ ).
legal_directive( bottom      _ ).
legal_directive( top         _ ).


%% execute_directive( + directive ):
%% Check and process the legal directives.

execute_directive( coinductive PredSpecs ) :-      % declaration of coinductive
        predspecs_to_patterns( PredSpecs, Patterns ),
        declare_coinductive( Patterns ).

execute_directive( bottom _ ).

execute_directive( top    _ ).



%% declare_coinductive( + list of general instances ):
%% Store the general instances in "coinductive", warning about duplications.

declare_coinductive( Patterns ) :-
        member( Pattern, Patterns ),              % i.e., sequence through these
        (
            coinductive( Pattern )
        ->
            duplicate_warning( Pattern, "coinductive" )
        ;
            assert( coinductive( Pattern ) )
        ),
        fail.

declare_coinductive( _ ).





%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%

%%%%%  The meta-interpreter  %%%%%


%% query( + goal ):
%% Execute a query.

query( Goal ) :-
        solve( Goal, [] ).



%% solve( + goal, + list of coinductive hypotheses ):
%% Solve a goal, given this table of co-inductive hypotheses.
%% NOTE: the cut is not supported.


solve( (Cond -> Then ; _Else), Hypotheses ) :-    % conditional, 1st alternative
        solve( Cond, Hypotheses ),
        !,
        solve( Then, Hypotheses ).

solve( (_Cond -> _Then ; Else), Hypotheses ) :-   % conditional, 2nd alternative
        !,
        solve( Else, Hypotheses ).

solve( ( Goal ; _ ), Hypotheses ) :-              % disjunction, 1st alternative
        solve( Goal, Hypotheses ).

solve( ( _ ; Goal ), Hypotheses ) :-              % disjunction, 2nd alternative
        !,
        solve( Goal, Hypotheses ).

solve( ( Goal1 , Goal2 ), Hypotheses ) :-         % conjunction
        !,
        solve( Goal1, Hypotheses ),
        solve( Goal2, Hypotheses ).

solve( once Goal, Hypotheses ) :-                 % yield only one solution
        !,
        once solve( Goal, Hypotheses ).

solve( Goal, _Hypotheses ) :-                     % other supported built-in
        builtin( Goal ),
        !,
        call( Goal ).

solve( Goal, Hypotheses ) :-                      % call a coinductive predicate
        coinductive( Goal ),
        !,
        solve_coinductive_call( Goal, Hypotheses ).

solve( Goal, Hypotheses ) :-                      % call a "normal" predicate
        clause( Goal, Body )@interpreted,
        solve( Body, Hypotheses ).



%% solve_coinductive_call( + list of coinductive hypotheses, + goal ):
% Solve a call to a coinductive predicate.

solve_coinductive_call( Goal, Hypotheses ) :-
            member( Goal, Hypotheses ).                   % the hypotheses first

solve_coinductive_call( Goal, Hypotheses ) :-
            clause( Goal, Body )@interpreted,
            solve( Body, [ Goal | Hypotheses ] ).         % then the clauses


%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%
