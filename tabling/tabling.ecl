%%%                                                                        %%%
%%%  A meta-interpreter for tabled logic programming: see the description  %%%
%%%  below for more information.                                           %%%
%%%  Written by Feliks Kluzniak at UTD.                                    %%%
%%%                                                                        %%%

%%% NOTE:
%%%
%%%    1. See ../general/top_level.ecl for a description of how to load
%%%       and run programs.
%%%
%%%    2. A tabled predicate should be declared as such in the program
%%%       file, e.g.,
%%%           :- tabled comember/2 .
%%%
%%%       To include files use the usual Prolog syntax:
%%            :- [ file1, file2, ... ].
%%%
%%%    2. The program should contain no other directives. It may, however,
%%%       contain queries, which will be executed immediately upon reading.
%%%
%%%    3. If the program invokes a built-in predicate, that predicate must
%%%       be declared in the table builtin/1 below.  Every addition should
%%%       be considered carefully: some might require special treatment by
%%%       the metainterpreter.

%%% LIMITATIONS: - The interpreted program should not contain cuts or
%%%                occurrences of the if-then-else construct.
%%%              - Error detection is quite rudimentary.


/*******************************************************************************

General description
   -------------------

   A simple (and very inefficient) metainterpreter that attempts to emulate
   "top-down tabled programming", as described in

     [1] Hai-Feng Guo, Gopal Gupta:
         Tabled Logic Programming with Dynamic Ordering of Alternatives
         (17th ICLP, 2001)

     [2] Neng-Fa Zhou, Taisuke Sato, Yi-Dong Shen:
         Linear Tabling Strategies and Optimizations
         (TPLP 2008 (?))

   The interpreter follows -- somewhat loosely -- the description in the latter
   paper, but without "semi-naive optimization".  Moreover, "clusters" are
   detected dynamically, to achieve greater precision (a dependency graph among
   static calls can only be a rough approximation, a dependency graph among
   predicates is rougher still).


   Nomenclature
   ------------

   Some predicates are "tabled", because the user has declared them to be such
   by using a directive.  E.g.,
       :- tabled p/2 .

   All calls to a tabled predicate that are present in the interpreted program
   are called "tabled calls".  Instances of such calls are called "tabled
   goals".  In general, we will use the term "call" to refer to a static entity
   in the program, and "goal" to refer to an instance of a call.  We will also
   avoid the conventional overloading of the term "goal" in yet another way: we
   will call a sequence (i.e., conjunction) of goals just that (unless we can
   refer to it as a "query" or a "resolvent").


   Limitations
   -----------

   The interpreted program must not contain cuts, disjunctions (i.e.,
   semicolons) or "if-then"/"if-then-else" constructs.  It also must not contain
   calls to built-in-predicates, except for the handful of predicates listed in
   builtin/1 below.


   Data structures
   ---------------

   The interpreter uses a number of tables that store information accumulated
   during a computation.  A computation consists in reading a program and
   executing a number of queries.  (A query is a sequence of goals.)

   The tables (implemented as dynamic predicates of Prolog) are:

   -- tabled( generic head )

           Contains an entry for each predicate that has been declared as
           tabled.  For instance, when the interpreter reads
               :- tabled p/2 .
           it stores the fact
               tabled( p( _, _ ) ).

   -- answer( goal, fact )

           Used to store results computed for tabled goals encountered during a
           computation.  Once present, these results are also used during
           further stages of the computation.

           The "fact" 'FAILURE' indicates that a goal fails without producing
           any results.

           In general, a side-effect of each computation will be the generation
           -- for each tabled goal encounted during the computation -- of a set
           of facts that form the goal's "least fixed point interpretation".
           (Of course, if this set is not sufficiently small, the interpreter
           will not terminate successfully.)  The facts (which need not be
           ground!) are all entered into the table "answered", and the members
           of different sets are distinguished by their association with the
           appropriate goal: a fact in "answered" is a result that is valid only
           for a variant of the accompanying goal.

           The need for annotating a fact with information about the
           corresponding goal might not be immediately obvious.  Consider the
           following example (which is simplistic in that the computation itself
           is trivial):

               program:  p( A, A ).
                         p( a, a ).
                         p( a, b ).

               query:    ?-  p( U, V ),  p( W, W ),  p( a, X ),  p( Y, b ).

           During "normal" execution of this Prolog program each goal in the
           query would generate a different set of results; to wit:

               p( U, V )  would generate  p( U, U ), p( a, a ), p( a, b )
               p( W, W )  ..............  p( W, W ), p( a, a )
               p( a, X )  ..............  p( a, a ) (twice!)
               p( Y, b )  ..............  p( b, b ), p( a, b ).

           In other words, the set of results depends not only on the predicate,
           but also on the form of the goal.  If "p/2" is tabled, the proper
           contents of "answer" would be as follows (not necessarily in this
           order):

               answer( p( U, V ), p( U, U ) ).
               answer( p( U, V ), p( a, a ) ).
               answer( p( U, V ), p( a, b ) ).
               answer( p( W, W ), p( W, W ) ).
               answer( p( W, W ), p( a, a ) ).
               answer( p( a, X ), p( a, a ) ).
               answer( p( Y, b ), p( b, b ) ).
               answer( p( Y, b ), p( a, b ) ).

           Please note that the repetition of p( a, a ) for the goal p( a, X )
           will be avoided.  In general, entries in "answer" will not be
           variants of each other.

   -- number_of_answers( natural number )

           This is a single fact that records the size of "answer".  It is used
           for determining whether new answers have been generated during a
           phase of the computation.

   -- pioneer( goal )

           If the current goal is one whose variant has not yet been encountered
           during the computation, the goal is called a "pioneer" and recorded
           in this table.  If a variant goal is encountered subsequently, it
           will be treated as a "follower".  The table is used to detect whether
           a goal (when first encountered) is a pioneer or a follower.

   -- not_topmost( goal )

           If a pioneer is determined not to be the "topmost looping goal" in a
           "cluster" of interdependent goals (see ref. [2]), then this is
           recorded in the table.

   -- cluster( goal, list of goals )

           Whenever a "cluster" of interdependent goals is encountered, it is
           entered into this table.  The first argument is the topmost goal in
           the cluster, the list contains the rest.  Please note that clusters
           may be nested, so the topmost goal in a cluster is not necessarily
           the "topmost looping goal" in the sense of ref. [2] (i.e., it may be
           stored in the table "not_topmost").

   -- completed( goal )

           Indicates that the fixpoint for this goal has been computed, and all
           the possible results for variants of the goal can be found in table
           "answer".

*******************************************************************************/


:- ensure_loaded( [ '../general/top_level.ecl',
                    '../general/utilities.ecl'
                  ]
                ).


%% Initialization of tables:

:- dynamic tabled/1 .
:- dynamic answer/2 .
:- dynamic number_of_answers/1 .
:- dynamic pioneer/1 .
:- dynamic not_topmost/1 .
:- dynamic cluster/2 .
:- dynamic completed/1 .

number_of_answers( 0 ).



%%%%%  Built-in predicates  %%%%
%%
%%  NOTE: Just adding "!" or " _ -> _ ; _" won't do the trick, the main
%%        metainterpreter would have to be modified.
%%        Certain other built-ins may also require special treatment.

builtin( true      ).
builtin( false     ).
builtin( fail      ).
builtin( _ = _     ).
builtin( _ \= _    ).
% builtin( \+( _ )   ).   % there is special treatment for this, see solve/2
% builtin( once( _ ) ).   % there is special treatment for this, see solve/2



%%%%%  Administration  %%%%%

:- op( 1000, fy, tabled ).    % allow  ":- tabled p/k ."



%% The legal directives (check external form only).

legal_directive( tabled _ ).


%% Check and process the legal directives

treat_directive( tabled P / K ) :-                 % declaration of tabled
        (atom( P ), integer( K ), K >= 0),         %  seems OK
        !,
        mk_pattern( P, K, Pattern ),               % Pattern = P( _, _, ... )
        assert( tabled( Pattern ) ).

treat_directive( tabled P / K ) :-                 % declaration of tabled
        (\+ atom( P ) ; \+ integer( K ) ; K < 0),  %  obviously wrong
        !,
        write( error, '+++ Erroneous directive: \"' ),
        write( error, (:- tabled P / K) ),
        writeln( error, '\" ignored! +++' ).





%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%

%%%%%  The meta-interpreter  %%%%%


%% Execute a query.
query( Goal ) :-
        solve( Goal, [] ).



%% solve( + goal, + stack ):
%% Solve the goal, maintaining information about the current chain of ancestors
%% (stack).

% true/0 is not traced, as it is considered a spurious artefact (of encoding
% facts in rule/2).

solve( true, _ ) :-
        !.


% A conjunction of goals: solve the first one first.

solve( (Goal , Goals), Stack ) :-
        solve( Goal, Stack ),
        solve( Goals, Stack ).


% A "normal" (i.e., not tabled) goal.

solve( Goal, Stack ) :-
        \+ tabled( Goal ),
        !,
        solve_by_rules( Goal, Stack ).


% A tabled goal that has been completed: all the results are in "answer".

solve( Goal, _ ) :-
        is_completed( Goal ),
        !,
        get_answer( Goal ).


% A pioneer goal is solved by rules, producing results that are stored in
% "answer": after this is done, "answer" is used to pass on the results.
%
% Moreover, if the goal is also a topmost goal (i.e., not inside a larger
% "loop"), then its answer set is extended to the least fixed point and its
% cluster is marked as complete.
%
% (Note that a pioneer is topmost by default, but may cease to become topmost
% when some descendant goal finds a variant ancestor, dynamically adding
% "inner" goals of the loop to "not_topmost".  See the call to
% variant_of_ancestor/2 in the next clause.)

solve( Goal, Stack ) :-
        is_a_pioneer( Goal ),
        !,
        store_all_solutions_by_rules( Goal, Stack ),
        (
            is_topmost( Goal ),
            !,
            number_of_answers( NAns ),
            compute_fixed_point( Goal, Stack, NAns ),
            complete_cluster( Goal )
        ;
            true
        ),
        get_answer( Goal ).


% A tabled goal that is not a pioneer and that, moreover, has a variant among
% its ancestors.  All the intermediate ancestors are marked as not topmost, and
% a new cluster is identified.
% Then only the existing (most likely incomplete) results from "answer" are
% returned before failure.

solve( Goal, Stack ) :-
        variant_of_ancestor( Goal, Stack ),
        !,
        get_answer( Goal ).


% A tabled goal that is not completed, not a pioneer, and has no variant among
% its ancestors.  Something is wrong!

solve( Goal, Stack ) :-
        fatal_error( "Impossible!", [ Goal | Stack ] ).





%% store_all_solutions_by_rules( + goal, + stack ):
%% Invoke solve_by_rules/2 until there are no solutions left, storing
%% the results in "answer".

store_all_solutions_by_rules( Goal, Stack ) :-
        solve_by_rules( Goal, Stack ),
        memo( Goal ),
        fail.

store_all_solutions_by_rules( _, _ ).



%% solve_by_rules( + goal, + stack ):
%% Solves the goal by using rules (i.e., clauses) only.

solve_by_rules( Goal, Stack ) :-
        copy_term( Goal, OriginalGoal ),
        rule( Goal, Body ),
        solve( Body, [ OriginalGoal | Stack ] ).




%% compute_fixed_point( + goal, + stack, + branch, + size of "answer" ):
%% Solve the goal by rules until no more answers are produced, then succeed
%% _without_ instantiating the goal.

compute_fixed_point( Goal, Stack, _ ) :-
        solve_by_rules( Goal, Stack, _ ),                       % all solutions
        memo( Goal ),
        fail.

compute_fixed_point( _, _, NAns ) :-
        number_of_answers( NAns ),                              % no new answers
        !.

compute_fixed_point( Goal, Stack, NAns ) :-
        number_of_answers( NA ),
        NA =\= NAns,                                            % new answers,
        compute_fixed-point( Goal, Stack, NA ).                 %   so iterate



%% variant_of_ancestor( + goal, + list of goals ):
%% Succeeds if the goal is a variant of some member of the list.
%%
%% SIDE EFFECT: If successful, then then intermediary goals will be marked as
%%              not topmost, and the entire prefix of the list upto (and
%%              including) the variant ancestor will be identified as a cluster.

variant_of_ancestor( Goal, List ) :-
        append( Prefix, [ G | _ ], List ),               % i.e., split the list
        are_variants( Goal, G ),
        assert( cluster( G, Prefix ) ),
        (
            member( M, Prefix ),
            mk_not_topmost( M ),
            fail
        ;
            true
        ).





%%-----  The tables: access and modification  -----


%% memo( + goal, + fact ):
%% If the table "answer" does not contain a variant of this fact paired with
%% a variant of this goal, then add the pair to the table, increasing
%% "number_of_answers".

memo( Goal, Fact ) :-
        answer( G, F ),
        are_variants( F, Fact ),
        are_variants( G, Goal ),
        !.

memo( Goal, Fact ) :-
        % No variant pair in "answer",
        assert( answer( Goal, Fact ) ),
        retract( number_of_answers( N ) ),
        N1 is N + 1,
        assert( number_of_answers( N1 ) ).



%% get_answer( +- goal ):
%% Get an instantiation (if any) tabled in "answer" for variants of this goal.
%% Sequence through all such instantiations on backtracking.

get_answer( Goal ) :-
        answer( G, Ans ),
        are_variants( Goal, G ),
        Goal = Ans .



%% complete_goal( + goal ):
%% Make sure the goal is marked as completed.

complete_goal( Goal ) :-
        is_completed( Goal ),
        !.

complete_goal( Goal ) :-
        % \+ is_completed( Goal ),
        assert( completed( Goal ) ).



%% is_completed( + goal ):
%% Succeeds iff the goal is a variant of a goal that has been stored in
%% the table completed.

is_completed( Goal ) :-
        completed( CG ),
        are_variants( Goal, CG ).



%% complete_cluster( + goal ):
%% If the goal has an associated cluster, make sure all the goals in the cluster
%% are marked as complete.  If there is no associated cluster, just mark the
%% goal as complete.

complete_cluster( Goal ) :-
        complete_goal( Goal ),
        complete_cluster_if_any( Goal ).

%
complete_cluster_if_any( Goal ) :-
        cluster( G, Gs ),
        are_variants( G, Goal ),
        !,
        complete_goals( Gs ).

complete_cluster_if_any( _ ).

%
complete_goals( Gs ) :-
        member( G, Gs ),
        complete_goal( G ),
        fail.

complete_goals( _ ).




%% is_a_pioneer( + goal ):
%% Succeeds if the goal is not a variant of another goal that has already been
%% encountered during this computation.
%%
%% SIDE EFFECT: Adds the goal to table "pioneer".

is_a_pioneer( Goal ) :-
        \+ ( pioneer( PG ),  are_variants( Goal, PG ) ),
        assert( pioneer( Goal ) ).



%% mk_not_topmost( + goal ):
%% Make sure that the goal is stored in "not_topmost".

mk_not_topmost( Goal ) :-
        \+ is_topmost( Goal ),
        !.

mk_not_topmost( Goal ) :-
        % is_topmost( Goal ),
        assert( not_topmost( Goal ) ).



%% is_topmost( + goal ):
%% Succeeds iff the goal is not a variant of a goal that has been saved in
%% table "not_topmost".

is_topmost( Goal ) :-
        \+ ( not_topmost( G ),  are_variants( Goal, G ) ).





%%-----  Custom-tailored utilities  -----


%% fatal_error( + message, + stack ):
%% Display the message and stack, then abort.

fatal_error( Message, Stack ) :-
        write( "---- FATAL ERROR: " ),
        nl,
        write( "---- " ),
        write( Message ),
        nl,
        nl,
        write( "---- The current stack:" ),
        nl,
        show_stack( Stack ),
        write( "----" ),
        nl,
        abort.

%
show_stack( [] ).
show_stack( [ H | T ] ) :-
        write( H ),
        nl,
        show_stack( T ).
