%% Get the translated interpreter:

:- [ 'interpreter.pl' ].


%--- An example: the microwave oven, from:
%      Edmund M. Clarke, Jr., Orna Grumberg, and Doron A. Peled:
%     "Model Checking"
%     The MIT Press (Cambridge, Massachussets and London, England) 1999


%                               S1
%                             / ^ |^
%                            /  | | \
%                           /   | |  \
%                          /    | |   \
%                         /     | |    \
%                        /      | |     \
%                       /       | |      \
%                      /        | |       \
%                     /         | |        \
%                    v          | v         \
%                   S2          S3  <----- S4  <----+
%                   ^ |        ^|           ^ \     |
%                   | |       / |           |  +----+
%                   | |      /  |           |
%                   | |     /   |           |
%                   | |    /    |           |
%                   | |   /     |           |
%                   | |  /      |           |
%                   | v /       v           |
%                    S5        S6 -------->S7


proposition( start ).
proposition( close ).
proposition( heat  ).
proposition( error ).

state( s1 ).
state( s2 ).
state( s3 ).
state( s4 ).
state( s5 ).
state( s6 ).
state( s7 ).

trans_all( s1, [ s2, s3     ] ).    %  start oven    ,  close door
trans_all( s2, [ s5         ] ).    %  close door
trans_all( s3, [ s1, s6     ] ).    %  open door     ,  start oven
trans_all( s4, [ s1, s3, s4 ] ).    %  open door     ,  done         ,  cook
trans_all( s5, [ s2, s3     ] ).    %  open door     ,  reset
trans_all( s6, [ s7         ] ).    %  warm up
trans_all( s7, [ s4         ] ).    %  start cooking

holds( s2, start ).
holds( s2, error ).

holds( s3, close ).

holds( s4, close ).
holds( s4, heat  ).

holds( s5, start ).
holds( s5, close ).
holds( s5, error ).

holds( s6, start ).
holds( s6, close ).

holds( s7, start ).
holds( s7, close ).
holds( s7, heat  ).


%                                           Expected   Prolog    Tabling

q1 :-  check( s1,   g(~ heat u close) ).   % yes       yes       yes

q2 :-  check( s1, ~ g(~ heat u close) ).   % no        no        no

q3 :-  check( s1, f( close ) ).            % yes       yes       yes

q4 :-  check( s1, f( error ) ).            % no        loops     no
