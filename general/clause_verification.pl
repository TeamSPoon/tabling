%%%  Utilities for verifying well-formedness of clauses.                     %%%
%%%                                                                          %%%
%%%  Written by Feliks Kluzniak at UTD (January 2009).                       %%%
%%%                                                                          %%%
%%%  Last update: 3 March 2009.                                              %%%
%%%                                                                          %%%

:- ensure_loaded( compatibility_utilities ).
:- ensure_loaded( boolean_operations ).
:- ensure_loaded( vardict_utilities ).
:- ensure_loaded( errors_and_warnings ).


%%------------------------------------------------------------------------------
%% verify_program_with_vars( + list of pairs ):
%% Like verify_program/1 below, but instead of a list of terms we have a list
%% of pairs (pair( term, variable dictionary for the term)), i.e., we can use
%% information about original variable names.

:- mode verify_program_with_vars( + ).

verify_program_with_vars( Pairs ) :-
        member( Pair, Pairs ),
        Pair = pair( Term, VarDict ),
        verify_program_item( Term, VarDict ),
        fail.

verify_program_with_vars( _ ).



%%------------------------------------------------------------------------------
%% verify_program( + list of terms ):
%% Given a list of terms that should all be clauses, directives, or queries,
%% raise an error if any of the terms is obviously incorrect.
%% See also verify_program_with_vars/1 above.

:- mode verify_program( + ).

verify_program( Terms ) :-
        member( Term, Terms ),
        mk_variable_dictionary( Term, VarDict ),
        verify_program_item( Term, VarDict ),
        fail.

verify_program( _ ).


%%------------------------------------------------------------------------------
%% verify_program_item( + list of terms, + variable dictionary ):
%% Given a term that should  be a clause, a directive, or a query,
%% raise an error if it is obviously incorrect.

verify_program_item( Var, VarDict ) :-
        var( Var ),
        !,
        bind_variables_to_names( VarDict ),
        error( [ 'A variable clause: \"', Var, '\"' ] ).

verify_program_item( (:- Var), VarDict ) :-
        var( Var ),
        !,
        bind_variables_to_names( VarDict ),
        error( [ 'A variable directive: \"', (:- Var), '\"' ] ).

verify_program_item( (?- Var), VarDict ) :-
        var( Var ),
        !,
        bind_variables_to_names( VarDict ),
        error( [ 'A variable query: \"', (?- Var), '\"' ] ).

verify_program_item( (?- Query), VarDict ) :-       % avoid check for singletons
        !,
        empty_set( Empty ),
        check_for_variable_calls( Query, Empty, ctxt( VarDict, (?- Query) ) ).


verify_program_item( Clause, VarDict ) :-
        \+ is_a_good_clause( Clause, VarDict ),
        !,
        bind_variables_to_names( VarDict ),
        error( [ 'Incorrect clause: \"', Clause, '.\"' ] ).

verify_program_item( _, _ ).



%%------------------------------------------------------------------------------
%% is_a_good_clause( + term ):
%% Is this term a reasonable clause?  Even if it is,  warnings may be produced.

is_a_good_clause( T ) :-
        mk_variable_dictionary( T, VarDict ),
        is_a_good_clause( VarDict ).


%%------------------------------------------------------------------------------
%% is_a_good_clause( + term, + variable dictionary ):
%% Is this term a reasonable clause?  Even if it is,  warnings may be produced.

is_a_good_clause( T, VarDict ) :-
        nonvar( T ),
        get_clause_head( T, H ),
        is_a_good_clause_head( H ),
        has_a_good_clause_body( T, VarDict ).


%%------------------------------------------------------------------------------
%% get_clause_head( + term, - head ):
%% Treat this non-variable term as a clause, get its head.

:-mode get_clause_head( +, - ).

get_clause_head( (H :- _), H ) :-  !.
get_clause_head( H       , H ).


%%------------------------------------------------------------------------------
%% is_a_good_clause_head( + term ):
%% Is this term a good head for a clause?

is_a_good_clause_head( Var ) :-
        var( Var ),
        !,
        fail.

is_a_good_clause_head( Hd ) :-
        atom( Hd ),
        !.

is_a_good_clause_head( Hd ) :-
        Hd \= [ _ | _ ].


%%------------------------------------------------------------------------------
%% has_a_good_clause_body( + term, + variable dictionary ):
%% Treat this non-variable term as a clause, check it for elementary sanity.
%% Assume that the head is not a variable.
%%
%% NOTE: The check is mainly to ensure that there are no variable literals.
%%       Invocations of call/1 are allowed, but an error will be raised if
%%       the argument is a variable that had no earlier occurrences.
%%       As an added bonus, we produce warnings about singleton variables.
%%
%% Throughout most of the code we carry a context argument (Ctxt): this is
%% a structure that holds the entire clause and the variable dictionary, and
%% we use it to produce better diagnostics.

:- mode has_a_good_clause_body( ?, + ).

has_a_good_clause_body( Clause, VarDict ) :-
        has_a_good_clause_body_( Clause, ctxt( VarDict, Clause ) ).

has_a_good_clause_body_( Clause, Ctxt ) :-
        Clause = (Head :- Body),
        !,
        ordered_term_variables( Head, HeadVars ),
        check_for_variable_calls( Body, HeadVars, Ctxt ),
        check_for_singleton_variables( Clause, Ctxt ).

has_a_good_clause_body_( Fact, Ctxt ) :-
        check_for_singleton_variables( Fact, Ctxt ).



% check_for_variable_calls( + (part of a) clause body,
%                           + the set of variables seen so far,
%                           + the context (just for better diagnostics)
%                         )

check_for_variable_calls( V, _, Ctxt ) :-
        var( V ),
        !,
        clause_error( [ 'A variable literal (\"', V, '\")' ], Ctxt ).

check_for_variable_calls( (A ; B), Vars, Ctxt ) :-
        !,
        check_for_variable_calls( A, Vars, Ctxt ),
        check_for_variable_calls( B, Vars, Ctxt ).

check_for_variable_calls( (A -> B), Vars, Ctxt ) :-
        !,
        check_for_variable_calls( (A , B), Vars, Ctxt ).

check_for_variable_calls( (A , B), Vars, Ctxt ) :-
        !,
        check_for_variable_calls( A, Vars, Ctxt ),
        ordered_term_variables( A, AVars ),
        set_union( AVars, Vars, NVars ),
        check_for_variable_calls( B, NVars, Ctxt ).

check_for_variable_calls( \+ A, Vars, Ctxt ) :-
        !,
        check_for_variable_calls( A, Vars, Ctxt ).

check_for_variable_calls( once( A ), Vars, Ctxt ) :-
        !,
        check_for_variable_calls( A, Vars, Ctxt ).

check_for_variable_calls( call( T ), Vars, Ctxt ) :-
        !,
        (
            nonvar( T )
        ->
            check_for_variable_calls( T, Vars, Ctxt )
        ;
            % var( T ),
            (
                is_in_set( T, Vars )
            ->
                true
            ;
                clause_error( [ 'The variable argument of \"', call( T ),
                                '\" does not have previous occurrences'
                              ],
                              Ctxt
                            )
            )
        ).

check_for_variable_calls( T, _, Ctxt ) :-
        \+ callable( T ),
        !,
        clause_error( [ 'Incorrect literal (\"', T, '\")' ], Ctxt ).

check_for_variable_calls( _, _, _ ).



%% check_for_singleton_variables( + clause, + context ):
%% Produce a warning if there is a path in the clause on which a variable occurs
%% only once, that occurrence of the variable is not a unique occurrence of the
%% variable on other paths, and the name of the variable does not begin with an
%% underscore.
%% Always succeed.
%% Assume the clause has been verified by is_a_good_clause/1.

check_for_singleton_variables( Clause, Ctxt ) :-
        cs( Clause, Ctxt, _, _, _, Singletons ),
        (
            empty_set( Singletons )
        ->
            true
        ;
            clause_warning( [ 'Singleton variables ', Singletons ], Ctxt )
        ).

%
% cs( + (sub)term,
%     + context,
%     - boolean indicating whether the construct must fail,
%     - set of variables seen from front,
%     - set of variables seen from behind,
%     - set of singletons,
%   ):
% Produce the sets of variables occurring in this term (those that can be "seen"
% from the front and those that can be "seen" from behind: cf. negation), as
% well as the set of  variables that are singletons in this term.
% Produce warnings about obviously dead code
% Note that the set of singletons is a subset of the set of seen.
% Note also that a variable whose name begins with an underscore "does not
% count".

cs( V, ctxt( VarDict, _), false, SeenFromFront, SeenFromBehind, Single ) :-
        var( V ),
        member( [ Name | Var ], VarDict ),
        Var == V,
        !,
        name_chars( '_',  [ Underscore ] ),
        (
            name_chars( Name, [ Underscore | _ ] )
        ->
            empty_set( SeenFromFront  ),
            empty_set( SeenFromBehind ),
            empty_set( Single         )
        ;
            empty_set( Empty ),
            add_to_set( V, Empty, SeenFromFront  ),
            add_to_set( V, Empty, SeenFromBehind ),
            add_to_set( V, Empty, Single         )
        ).

cs( V, _, false, SeenFromFront, SeenFromBehind, Single ) :-
        var( V ),                                       % '_' is not in VarDict!
        !,
        empty_set( SeenFromFront  ),
        empty_set( SeenFromBehind ),
        empty_set( Single         ).

cs( fail, _, true, SeenFromFront, SeenFromBehind, Single ) :-
        !,
        empty_set( SeenFromFront  ),
        empty_set( SeenFromBehind ),
        empty_set( Single         ).

cs( A, _, false, SeenFromFront, SeenFromBehind, Single ) :-
        atomic( A ),
        !,
        empty_set( SeenFromFront  ),
        empty_set( SeenFromBehind ),
        empty_set( Single         ).

cs( ((A ; B) , C), Ctxt, MustFail, SeenFromFront, SeenFromBehind, Single ) :-
        !,
        cs_join( ((A ; B), C), Ctxt, MustFail,
                 SeenFromFront, SeenFromBehind, Single
               ).

cs( (A ; B), Ctxt, MustFail, SeenFromFront, SeenFromBehind, Single ) :-
        !,
        cs( A, Ctxt, MustFailA, SeenFromFrontA, SeenFromBehindA, SingleA ),
        cs( B, Ctxt, MustFailB, SeenFromFrontB, SeenFromBehindB, SingleB ),
        set_union( SeenFromFrontA , SeenFromFrontB , SeenFromFront  ),
        set_union( SeenFromBehindA, SeenFromBehindB, SeenFromBehind ),
        set_union( SingleA        , SingleB        , Single         ),
        bool_eval( MustFailA and MustFailB, MustFail ).

cs( (A , B), Ctxt, MustFail, SeenFromFront, SeenFromBehind, Single ) :-
        !,
        cs( A, Ctxt, MustFailA, SeenFromFrontA, SeenFromBehindA, SingleA ),
        cs( B, Ctxt, MustFailB, SeenFromFrontB, SeenFromBehindB, SingleB ),
        (
            MustFailA = true
        ->
            MustFail      = true,
            SeenFromFront = SeenFromFrontA,
            Single        = SingleA,
            empty_set( SeenFromBehind ),
            clause_warning( [ 'Obviously dead code: \"', B, '\"' ], Ctxt )
        ;
            set_union( SeenFromFrontA, SeenFromFrontB, SeenFromFront ),
            (
                MustFailB = true
            ->
                MustFail = true,
                empty_set( SeenFromBehind )
            ;
                set_union( SeenFromBehindA, SeenFromBehindB, SeenFromBehind ),
                bool_eval( MustFailA or MustFailB, MustFail )
            ),
            set_intersection( SeenFromBehindA, SeenFromFrontB, SeepingAB ),
            set_difference( SingleA, SeepingAB, SA ),
            set_difference( SingleB, SeepingAB, SB ),
            set_union( SA, SB, Single )
        ).

cs( (A :- B), Ctxt, MustFail, SeenFromFront, SeenFromBehind, Single ) :-
        !,
        cs(  (A , B), Ctxt, MustFail, SeenFromFront, SeenFromBehind, Single ).

cs( (A -> B), Ctxt, MustFail, SeenFromFront, SeenFromBehind, Single ) :-
        !,
        cs( (A , B), Ctxt, MustFail, SeenFromFront, SeenFromBehind, Single ).

cs( [ A | B ], Ctxt, MustFail, SeenFromFront, SeenFromBehind, Single ) :-
        !,
        cs( A, Ctxt, MustFailA, SeenFromFrontA, SeenFromBehindA, SingleA ),
        cs( B, Ctxt, MustFailB, SeenFromFrontB, SeenFromBehindB, SingleB ),
        set_union( SeenFromFrontA, SeenFromFrontB, SeenFromFront ),
        set_union( SeenFromBehindA, SeenFromBehindB, SeenFromBehind ),
        bool_eval( MustFailA or MustFailB, MustFail ),
        set_intersection( SeenFromBehindA, SeenFromFrontB, SeepingAB ),
        set_difference( SingleA, SeepingAB, SA ),
        set_difference( SingleB, SeepingAB, SB ),
        set_union( SA, SB, Single ).

cs( \+ C, Ctxt, false, SeenFromFront, Empty, Single ) :-
        empty_set( Empty ),
        cs( C, Ctxt, _, SeenFromFront, _, Single ).

cs( C, Ctxt, false, SeenFromFront, SeenFromBehind, Single ) :-
        compound( C ),
        !,
        C =.. [ _ | Args ],
        cs( Args, Ctxt, _, SeenFromFront, SeenFromBehind, Single ).

cs( T, Ctxt, MustFail, SeenFromFront, SeenFromBehind, Single ) :-
        error( [ 'INTERNAL ERROR: (clause_verification)',
                 cs( T, Ctxt, MustFail, SeenFromFront, SeenFromBehind, Single )
               ]
             ).


% Several paths seem to converge: special treatment is needed if any of them
% is known to fail.

cs_join( ((A ; B) , C), Ctxt, MustFail, SeenFromFront, SeenFromBehind, Single
       ) :-
        cs( C, Ctxt, MustFailC, SeenFromFrontC, SeenFromBehindC, SingleC ),
        unfold_disjunction( (A ; B), Disjunctions ),
        map( [ cs2, Ctxt ], Disjunctions, Results ),
        map( [ cs_adjust, SeenFromFrontC ], Results, Adjusted ),
        map( result1, Adjusted, ListMustFail   ),
        map( result2, Adjusted, ListFromFront  ),
        map( result3, Adjusted, ListFromBehind ),
        map( result4, Adjusted, ListSingle     ),
        fold( bool_and, true, ListMustFail, AllMustFailExp ),
        bool_eval( AllMustFailExp, MustFailAlt ),
        empty_set( Empty ),
        fold( set_union, Empty, ListFromFront , SeenFromFrontAlt  ),
        fold( set_union, Empty, ListFromBehind, SeenFromBehindAlt ),
        fold( set_union, Empty, ListSingle    , SingleAlt         ),
        (
            MustFailAlt = true
        ->
            MustFail      = true,
            SeenFromFront = SeenFromFrontAlt,
            Single        = SingleAlt,
            empty_set( SeenFromBehind ),
            clause_warning( [ 'Obviously dead code: \"', C, '\"' ], Ctxt )
        ;
            set_union( SeenFromFrontAlt, SeenFromFrontC, SeenFromFront ),
            (
                MustFailC = true
            ->
                MustFail = true,
                empty_set( SeenFromBehind )
            ;
                set_union( SeenFromBehindAlt, SeenFromBehindC, SeenFromBehind ),
                bool_eval( MustFailAlt or MustFailC, MustFail )
            ),
            set_intersection( SeenFromBehindAlt, SeenFromFrontC, SeepingBC ),
            set_difference( SingleC, SeepingBC, SC ),
            set_union( SingleAlt, SC, Single )
        ).

%
unfold_disjunction( (A ; B), [ A | Disjuncts ] ) :-
        !,
        unfold_disjunction( B, Disjuncts ).

unfold_disjunction( A, [ A ] ).

%
cs2( Ctxt, Construct, result( MustFail, SeenFromFront, SeenFromBehind, Single )
   ) :-
        cs( Construct, Ctxt, MustFail, SeenFromFront, SeenFromBehind, Single ).

%
cs_adjust( SeenFromFollower, Result, NewResult ) :-
        Result = result( MustFail, SeenFromFront, SeenFromBehind, Single ),
        (
            MustFail = true
        ->
            NewResult = Result
        ;
            set_intersection( SeenFromBehind, SeenFromFollower, Seeping ),
            set_difference( Single, Seeping, NewSingle ),
            NewResult =
                      result( false, SeenFromFront, SeenFromBehind, NewSingle )
        ).

%
result1( result( A, _, _ , _ ), A ).
result2( result( _, B, _ , _ ), B ).
result3( result( _, _, C , _ ), C ).
result4( result( _, _, _ , D ), D ).



%%------------------------------------------------------------------------------
% clause_error( + list to be displayed (the error message), + the context ):
% Show the error and the entire clause, with proper variable names.
% For the time being V and 'V' will both appear as V on output.

clause_error( MsgList, ctxt( VarDict, Clause ) ) :-
        bind_all_variables_to_names( Clause, VarDict ),     % may affect MSgList
        append( MsgList, [ ':' ], FullMsgList ),
        error( lines( [ FullMsgList, [ Clause, '.' ] ] ) ).


%%------------------------------------------------------------------------------
% clause_warning( + list to be displayed (the warning message), + the context ):
% Show the warning and the entire clause, with proper variable names.
% For the time being V and 'V' will both appear as V on output.

clause_warning( MsgList, ctxt( VarDict, Clause ) ) :-
        bind_all_variables_to_names( Clause, VarDict ),     % may affect MSgList
        append( MsgList, [ ' in' ], FullMsgList ),
        warning( lines( [ FullMsgList, [ Clause, '.' ] ] ) ),
        fail.

clause_warning( _, _ ).


%%------------------------------------------------------------------------------