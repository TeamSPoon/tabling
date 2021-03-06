/*-------------------------------------------------------------------------*/
/* Benchmark (Finite Domain)                                               */
/*                                                                         */
/* Name           : donald.pl                                              */
/* Title          : crypt-arithmetic                                       */
/* Original Source: Daniel Diaz - INRIA France                             */
/* Adapted by     : Daniel Diaz for GNU Prolog                             */
/* Date           : September 1992                                         */
/*                                                                         */
/* Solve the operation:                                                    */
/*                                                                         */
/*    D O N A L D                                                          */
/*  + G E R A L D                                                          */
/*  --------------                                                         */
/*  = R O B E R T                                                          */
/*                                                                         */
/* (resolution by line)                                                    */
/*                                                                         */
/* Solution:                                                               */
/*  [D,O,N,A,L,G,E,R,B,T]                                                  */
/*  [5,2,6,4,8,1,9,7,3,0]                                                  */
/*-------------------------------------------------------------------------*/

go:-	
    statistics(runtime,_),
    donald(LD,Lab), statistics(runtime,[_,Y]),
    write(LD), nl,
    write('time : '), write(Y), nl.

donald(LD,Lab):-
    LD=[D,O,N,A,L,G,E,R,B,T],
    all_different(LD),
    domain(LD,0,9),
    domain([D,G],1,9),

    100000*D+10000*O+1000*N+100*A+10*L+D +
    100000*G+10000*E+1000*R+100*A+10*L+D
    #= 100000*R+10000*O+1000*B+100*E+10*R+T,

    labeling(LD).

