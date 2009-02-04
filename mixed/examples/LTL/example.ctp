%% Get the translated interpreter:

:- [ 'interpreter.pl' ].


%--- An example: some states, some queries...

% NOTE: A "final" state must have an edge to itself.


%        S3: p, z ----> S4: p, s
%             ^         /
%              \       /
%               \     /
%                \   /
%                 \ v
%               S2: p, q
%                  ^
%                  |
%                  |
%                  |
%               S0:
%                  |
%                  |
%                  |
%                  v
%               S1: t <---+
%                 |       |
%                 |       |
%                 +-------+


proposition( p ).
proposition( q ).
proposition( z ).
proposition( s ).
proposition( t ).


state( s0 ).
state( s1 ).
state( s2 ).
state( s3 ).
state( s4 ).

% Transitions are specified by a function, not by a relation

trans_all( s0, [ s1, s2 ] ).
trans_all( s1, [ s1     ] ).
trans_all( s2, [ s3     ] ).
trans_all( s3, [ s4     ] ).
trans_all( s4, [ s2     ] ).

holds( s1, t ).

holds( s2, p ).
holds( s2, q ).

holds( s3, p ).
holds( s3, z ).

holds( s4, p ).
holds( s4, s ).


%                                         Expected   Prolog    Tabling

q1  :- check( s0, g p ).                  % no       no        no

q2  :- check( s0, f p ).                  % no       loop      no

q3  :- check( s0, f p v f t ).            % no       loop      no

q4  :- check( s0, f (p v t) ).            % yes      yes       yes

q5  :- check( s1, g p ).                  % no       no        no

q6  :- check( s1, f p ).                  % no       loop      no

q7  :- check( s0, f g p ).                % no       loop      no

q8  :- check( s2, g p ).                  % yes      yes       yes

q9  :- check( s2, f g p ).                % yes      yes       yes

q10  :- check( s2, f( q ^ z ) ).          % no       loop      no

q11 :- check( s2, f q ^ f z ).            % yes      yes       yes

q12 :- check( s2, g f s ).                % yes      yes       yes

