%%%  A goal table implemented by an open binary tree with open lists.        %%%
%%%                                                                          %%%
%%%  Written by Feliks Kluzniak at UTD (February 2009).                      %%%
%%%                                                                          %%%
%%%  Last update: 18 February 2009.                                          %%%
%%%                                                                          %%%

:- ensure_loaded( utilities ).
:- ensure_loaded( higher_order ).
:- ensure_loaded( olist ).
:- ensure_loaded( otree ).


%%% In this implementation the goal table is an open binary tree.
%%% Each key is a predicate specification.
%%% The information associated with a key is an open list of goals
%%% that invoke the predicate specified by the key.


%%------------------------------------------------------------------------------
%% empty_goal_table( +- goal table ):
%% Create an empty goal table, or check that the provided table is empty.

empty_goal_table( Table ) :-
        empty_otree( Table ).


%%------------------------------------------------------------------------------
%% goal_table_member( + goal, + goal table ):
%% Check whether any instantiations of the goal are in the table: if there are,
%% unify the goal with the first one (backtracking will unify it with each of
%% them in turn).

goal_table_member( Goal, Table ) :-
        functor( Goal, P, K ),
        is_in_otree( Table, P / K, pred_spec_less, OList ),
        olist_member_reversed( Goal, OList ).


%%------------------------------------------------------------------------------
%% is_a_variant_in_goal_table( + goal, + goal table ):
%% Succeed iff a variant of this goal is present in the table.
%% Do not modify the goal.

is_a_variant_in_goal_table( Goal, Table ) :-
        copy_term( Goal, Copy ),
        goal_table_member( Copy, Table ),
        are_variants( Copy, Goal ),
        !.


%%------------------------------------------------------------------------------
%% goal_table_add( + goal table, + goal ):
%% Add this goal to the table.

goal_table_add( Table, Goal ) :-
        functor( Goal, P, K ),
        otree( Table, P / K, pred_spec_less, olist_add ).


%%------------------------------------------------------------------------------
%% pred_spec_less( + predicate specification, + predicate specification ):
%% Succeed iff the first argument is smaller than the second.

pred_spec_less( P1 / K1, P2 / K2 ) :-
        (
            P1 < P2
        ;
            P1 = P2,
            K1 < K2
        ),
        !.
