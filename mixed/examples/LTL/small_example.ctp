:- [ 'ltl_interpreter.pl' ].

proposition( p ).

state( s0 ).
%state( s1 ).

trans_all( s0, [ s0 ] ).
%trans_all( s0, [ s1 ] ).
%trans_all( s1, [ s0 ] ).

holds( s0, p ).
%holds( s1, p ).

q  :- check( s0, g p ).                  % yes      yes       yes

