%%%  Some generally-useful utilities.                                        %%%
%%%                                                                          %%%
%%%  Written by Feliks Kluzniak at UTD (January 2009).                       %%%
%%%                                                                          %%%
%%%  Last update: 20 February 2009.                                          %%%
%%%                                                                          %%%


:- ensure_loaded( set_in_list ).
:- ensure_loaded( higher_order ).
:- ensure_loaded( compatibility_utilities ).



%%------------------------------------------------------------------------------
%% check( + goal ) :
%%    Succeeds iff goal succeeds, but without instantiating any variables
%%    (side-effects may appear, though).

:- mode check( + ).

check( Goal ) :-  \+ \+ Goal .



%%------------------------------------------------------------------------------
%% mk_ground( +- term ) :
%%    Instantiates all the unbound variables in the term as constants of
%%    the form ' V0', ' V1'. ' V2' etc.
%%    (Note: This is mainly for "safety". If the strange names of the constants
%%           are not needed, consider using:
%%              mk_ground( T ) :- numbervars( T, 0, _ ).
%%           on Prolog systems that support numbervars/3.
%%    )

:- mode mk_ground( ? ).

mk_ground( T ) :-  mk_ground_aux( T, 0, _ ).

%
:- mode mk_ground_aux( ?, +, - ).

mk_ground_aux( V, N, N1 ) :-
        var( V ),
        !,
        name_chars( N, CharsOfN ),
        N1 is N + 1,
        name_chars( ' V', CharsOfV ),
        append( CharsOfV, CharsOfN, CharsOfVN ),
        name_chars( V, CharsOfVN ).

mk_ground_aux( T, N, N ) :-
        atomic( T ),
        !.

mk_ground_aux( T, N, N1 ) :-
        % \+ var( T ), \+ atomic( T ),
        T =.. [ _Functor | Args ],
        mk_ground_auxs( Args, N, N1 ).

%
:- mode mk_ground_auxs( +, +, - ).

mk_ground_auxs( []        , N, N  ).
mk_ground_auxs( [ T | Ts ], N, N2 ) :-
        mk_ground_aux( T, N, N1 ),
        mk_ground_auxs( Ts, N1, N2 ).


%%------------------------------------------------------------------------------
%% is_ground_var( + term ):
%% Is this term a variable that was ground by mk_ground/1?

is_ground_var( T ) :-
        atom( T ),
        atom_string( T, S ),
        substring( S, " V", 1 ).


%%------------------------------------------------------------------------------
%% ground_term_variables( + term, - set of variables ):
%% Given a term grounded by mk_ground/1, produce the set of the grounded form of
%% variables occurring in the term.
%% (Note that the term may be a subset of a larger term grounded by mk_ground/1,
%%  so the variable numbers need not be contiguous.)

:- mode ground_term_variables( +, - ).

ground_term_variables( T, S ) :-
        empty_set( S0 ),
        gtv_( T, S0, S ),
        !.

ground_term_variables( T, _ ) :-
        error( [ 'Bad call to ground_term_variables (term not ground): ', T ] ).

%
:- mode gtv_( +, +, - ).

gtv_( V, _, _ ) :-
        var( V ),
        !,
        fail.

gtv_( T, S, NS ) :-
        is_ground_var( T ),
        !,
        add_to_set( T, S, NS ).

gtv_( T, S, S ) :-
        atom( T ),
        !.

gtv_( [ H | T ], S, NS ) :-
        !,
        gtv_( H,  S, S2 ),
        gtv_( T, S2, NS ).

gtv_( T, S, NS ) :-
        T =.. [ _ | Args ],
        gtv_( Args, S, NS ).



%%------------------------------------------------------------------------------
%% is_an_instance( + term, + term ) :
%%    Succeeds iff arg1 is an instance of arg2, but does not instantiate any
%%    variables.

% is_an_instance( T1, T2 ) :-
%         check( (mk_ground( T1 ) , T1 = T2) ).

is_an_instance( T1, T2 ) :-  instance( T1, T2 ).              % use the built-in


%%------------------------------------------------------------------------------
%% are_variants( + term, + term ) :
%%    Succeeds only if both arguments are variants of each other.
%%    Does not instantiate any variables.

% are_variants( T1, T2 ) :-
%         check( T1 = T2 ),              % to weed out obvious "misfits" cheaply
%         is_an_instance( T1, T2 ),
%         is_an_instance( T2, T1 ).

are_variants( T1, T2 ) :-  variant( T1, T2 ).                 % use the built-in



%%------------------------------------------------------------------------------
%% mk_pattern( + an atom representing the name of a predicate,
%%             + an integer representing the arity of the predicate,
%%             - the most general pattern that matches all invocations of the
%%               predicate
%%           )
%% Given p/k, produce p( _, _, ... _ )  (of arity k)

:- mode mk_pattern( +, +, - ).

mk_pattern( P, K, Pattern ) :-
        length( Args, K ),                            % Args = K fresh variables
        Pattern =.. [ P | Args ].


%%------------------------------------------------------------------------------
%% most_general_instance( + a term,
%%                        - a most general instance with the same main functor
%%                      ):
%% E.g., p( a, q( X, Y ) )  is transformed to  p( _, _ ).

:- mode most_general_instance( +, - ).

most_general_instance( Term, Pattern ) :-
        functor( Term, P, K ),
        mk_pattern( P, K, Pattern ).



%%------------------------------------------------------------------------------
%% predspecs_to_patterns( + a conjunction of predicate specifications,
%%                        - list of most general instances of these predicates
%%                      ):
%% Given one or several predicate specifications (in the form "p/k" or
%% "p/k, q/l, ...") check whether they are well-formed: if not, raise a fatal
%% error; otherwise return a list of the most general instances that correspond
%% to the predicate specifications.

predspecs_to_patterns( Var, _ ) :-
        var( Var ),
        !,
        error( [ 'A variable instead of predicate specifications: \"',
                 Var,
                 '\"'
               ]
             ).

predspecs_to_patterns( (PredSpec , PredSpecs), [ Pattern | Patterns ] ) :-
        !,
        predspec_to_pattern( PredSpec, Pattern ),
        predspecs_to_patterns( PredSpecs, Patterns ).

predspecs_to_patterns( PredSpec, [ Pattern ] ) :-
        predspec_to_pattern( PredSpec, Pattern ).


%%------------------------------------------------------------------------------
%% predspec_to_pattern( + a predicate specification,
%%                      - a most general instance of this predicate
%%                    ):
%% Given a predicate specification (in the form "p/k") check whether it is
%% well-formed: if not, raise a fatal error; otherwise return a most general
%% instance that correspond to the predicate specification.

predspec_to_pattern( PredSpec, Pattern ) :-
        check_predspec( PredSpec ),
        PredSpec = P / K,
        mk_pattern( P, K, Pattern ).


%%------------------------------------------------------------------------------
%% check_predspec:
%% Raise an error if this is not a good predicate specification.
check_predspec( Var ) :-
        var( Var ),
        !,
        error( [ 'A variable instead of a predicate specification: \"',
                 Var,
                 '\"'
               ]
             ).

check_predspec( P / K ) :-
        atom( P ),
        integer( K ),
        K >= 0,
        !.

check_predspec( PredSpec ) :-
        error( [ 'An incorrect predicate specification: \"', PredSpec, '\"' ] ).



%%------------------------------------------------------------------------------
%% bind_variables_to_names( +- variable dictionary  ):
%% The variable dictionary is of the format returned by readvar/3, i.e., a list
%% of pairs of the form "[ name | variable ]".  Go through the dictionary,
%% binding each variable to the associated name.

bind_variables_to_names( VarDict ) :-
        map( bind_var_to_name, VarDict, _ ).

%
bind_var_to_name( [ Name | Name ], _ ).



%%------------------------------------------------------------------------------
%% is_a_good_clause( + term ):
%% Is this term a reasonable clause?  Even if it is,  warnings may be produced.

is_a_good_clause( T ) :-
        mk_variable_dictionary( T, VarDict ),
        is_a_good_clause( VarDict ).


%%------------------------------------------------------------------------------
%% mk_variable_dictionary( + term, - a variable dictionary ):
%% Produce a variable dictionary for this term, as if it had been read by
%% readvar/3.
%% Since the original variable names are not available, we will use the names
%% A, B, C, ... Z, V0, V1 etc.
%% (This is done "by hand", since numbervars/3 are not very useful in Eclipse:
%%  the writing predicates are not "aware" of '$VAR'(n).)

mk_variable_dictionary( T, VarDict ) :-
        term_variables( T, Vars ),
        mk_variable_dictionary_( Vars, 'A', VarDict ).

mk_variable_dictionary_( [], _, [] ).

mk_variable_dictionary_( [ V | Vs ], Name, [ [ Name | V ] | VarDict ] ) :-
        mk_next_name( Name, NextName ),
        mk_variable_dictionary_( Vs, NextName, VarDict ).

%
% Once we run out of letters, we will use V0, V1 etc.
%
mk_next_name( 'Z', 'V0' ) :-
        !.

mk_next_name( Name, Next ) :-
        name_chars( Name, [ C ] ),      % still in single letters?
        !,
        NC is C + 1,         % good for ASCII, might not work for some encodings
        name_chars( Next, [ NC ] ).

mk_next_name( Name, Next ) :-
        name_chars( Name, [ CodeOfV | DigitChars ] ),
        name_chars( Number, DigitChars ),
        NextNumber is Number + 1,                               % good for ASCII
        name_chars( NextNumber, NewDigitChars ),
        name_chars( Next, [ CodeOfV | NewDigitChars ] ).


%%------------------------------------------------------------------------------
%% is_a_variable_name( + term ):
%% Is this the name of a variable?

is_a_variable_name( Term ) :-
        atom( Term ),
        name_chars( Term, [ FirstChar | _ ] ),
        name_chars( FirstCharAtom, [ FirstChar ] ),
        (
            FirstCharAtom = '_',
            !
        ;
            upper_case_letter( FirstCharAtom )
        ).

%
upper_case_letter( Atom ) :-  uc( Atom ),  !.

uc( 'A' ).  uc( 'B' ). uc( 'C' ).  uc( 'D' ).  uc( 'E' ).  uc( 'F' ).
uc( 'G' ).  uc( 'H' ). uc( 'I' ).  uc( 'J' ).  uc( 'K' ).  uc( 'L' ).
uc( 'M' ).  uc( 'N' ). uc( 'O' ).  uc( 'P' ).  uc( 'Q' ).  uc( 'R' ).
uc( 'S' ).  uc( 'T' ). uc( 'U' ).  uc( 'V' ).  uc( 'W' ).  uc( 'X' ).
uc( 'Y' ).  uc( 'Z' ).


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

:- mode has_a_good_clause_body( ?, + ).

has_a_good_clause_body( Clause, VarDict ) :-
        check( has_a_good_clause_body_( Clause, VarDict ) ).

has_a_good_clause_body_( Clause, VarDict ) :-
        bind_variables_to_names( VarDict ),    % this is why we call via check/1
        Clause = (Head :- Body),
        !,
        term_variables( Head, HeadVars ),
        check_for_variable_calls( Body, HeadVars, Clause ),
        check_for_singleton_variables( Clause ).

has_a_good_clause_body_( _Fact, _ ).


%% extract_variables( + term, - set of variable names ):
%% Since we don't have real variables here, we can't use term_variables.

extract_variables( T, VarSet ) :-
        empty_set( Empty ),
        extract_variables_( T, Empty, VarSet ).

%
extract_variables_( V, Vars, NVars ) :-
        is_a_variable_name( V ),
        !,
        add_to_set( V, Vars, NVars ).

extract_variables_( A, Vars, Vars ) :-
        atomic( A ),
        !.

extract_variables_( T, Vars, NVars ) :-
        compound( T ),
        T =.. [ _ | Args ],
        map( extract_variables, Args, Sets ),
        fold( set_union, Vars, Sets, NVars ).


% check_for_variable_calls( + (part of a) clause body,
%                           + the set of variables seen so far,
%                           + the clause (just for better diagnostics)
%                         )

check_for_variable_calls( V, _, Clause ) :-
        is_a_variable_name( V ),
        !,
        error( [ 'A variable literal (\"', V, '\") in \"', Clause, '\"' ] ).

check_for_variable_calls( (A ; B), Vars, Clause ) :-
        !,
        check_for_variable_calls( A, Vars, Clause ),
        check_for_variable_calls( B, Vars, Clause ).

check_for_variable_calls( (A -> B), Vars, Clause ) :-
        !,
        check_for_variable_calls( (A , B), Vars, Clause ).

check_for_variable_calls( (A , B), Vars, Clause ) :-
        !,
        check_for_variable_calls( A, Vars, Clause ),
        extract_variables( A, AVars ),
        set_union( AVars, Vars, NVars ),
        check_for_variable_calls( B, NVars, Clause ).

check_for_variable_calls( \+ A, Vars, Clause ) :-
        !,
        check_for_variable_calls( A, Vars, Clause ).

check_for_variable_calls( once( A ), Vars, Clause ) :-
        !,
        check_for_variable_calls( A, Vars, Clause ).

check_for_variable_calls( call( A ), Vars, Clause ) :-
        !,
        (
            \+ is_a_variable_name( A )
        ->
            check_for_variable_calls( A, Vars, Clause )
        ;
            % is_a_variable_name( A ),
            (
                is_in_set( A, Vars )
            ->
                true
            ;
                error( [ 'The variable argument of \"', call( A ),
                         '\" does not have previous occurrences in \"',
                         Clause, '.\"'
                       ]
                     )
            )
        ).

check_for_variable_calls( T, _, Clause ) :-
        \+ callable( T ),
        !,
        error( [ 'Incorrect literal (\"', T, '\") in \"', Clause, '.\"' ] ).

check_for_variable_calls( _, _, _ ).


%% check_for_singleton_variables( + a clause with variables bound to names ):
%% Produce a warning if there is a path in the clause on which a variable occurs
%% only once, and the name of that variable does not begin with an underscore.
%% Always succeed.
%% Assume the clause has been verified by is_a_good_clause/1.

check_for_singleton_variables( Clause ) :-
        cs( Clause, _, Singletons ),
        (
            empty_set( Singletons )
        ->
            true
        ;
            warning( [ 'Singleton variables ', Singletons,
                       ' in clause \"', Clause, '.\"'
                     ]
                   )
        ).

%
% cs( + (sub)term, - variables seen, - set of singletons ):
% Produce the set of variables occurring in this term, as well as the set of
% variables that are singletons in this term.
% Note that singletons is a subset of seen.

cs( V, [ V ], [ V ] ) :-
        is_a_variable_name( V ),
        !.

cs( A, [], [] ) :-
        atomic( A ),
        !.

cs( (A ; B), Seen, Single ) :-
        !,
        cs( A, SeenA, SingleA ),
        cs( B, SeenB, SingleB ),
        set_union( SeenA,   SeenB,   Seen   ),
        set_union( SingleA, SingleB, Single ).

cs( (A , B), Seen, Single ) :-
        !,
        cs( [ A | B ], Seen, Single ).

cs( (A :- B), Seen, Single ) :-
        !,
        cs( [ A | B ], Seen, Single ).

cs( (A -> B), Seen, Single ) :-
        !,
        cs( [ A | B ], Seen, Single ).

cs( [ A | B ], Seen, Single ) :-
        !,
        cs( A, SeenA, SingleA ),
        cs( B, SeenB, SingleB ),
        set_union( SeenA, SeenB, Seen ),
        set_difference( SingleA, SeenB, SA ),
        set_difference( SingleB, SeenA, SB ),
        set_union( SA, SB, Single ).

cs( C, Seen, Single ) :-
        compound( C ),
        !,
        C =.. [ _ | Args ],
        cs( Args, Seen, Single ).

cs( T, Seen, Single ) :-
        error( [ 'INTERNAL ERROR: (utilities)', cs( T, Seen, Single ) ] ).


%%------------------------------------------------------------------------------
%% verify_program( + list of terms ):
%% Given a list of terms that should all be clauses, directives, or queries,
%% raise an error if any of the terms is obviously incorrect.

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

verify_program_item( end_of_file, _ ) :-
        !.       % An ugly fix for an error in Eclipse (does not bind VarDict!)

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

verify_program_item( Clause, VarDict ) :-
        \+ is_a_good_clause( Clause, VarDict ),
        !,
        bind_variables_to_names( VarDict ),
        error( [ 'Incorrect clause: \"', Clause, '.\"' ] ).

verify_program_item( _, _ ).



%%------------------------------------------------------------------------------
%% ensure_filename_is_an_atom( + filename ):
%% Verify that the filename is an atom.  If not, produce a fatal error.

ensure_filename_is_an_atom( FileName ) :-
        atom( FileName ),
        !.

ensure_filename_is_an_atom( FileName ) :-
        % \+ atom( FileName ),
        error( [ 'Illegal file name \"', FileName, '\" (not an atom).' ]
             ).



%%------------------------------------------------------------------------------
%% ensure_extension( + file name chars,
%%                   + extension chars,
%%                   - the root file name,
%%                   - file name, possibly extended
%%                 ):
%% If the file name has no extension, add the provided extension (which must
%% include the period; it can also be empty) and return the file name as the
%% root name; if the file name has an extension, don't change it, but extract
%% the root name.

:- mode ensure_extension( +, +, -, - ).

ensure_extension( FileNameChars, _, RootFileNameChars, FileNameChars ) :-
        name_chars( '.', Dot ),
        append( RootFileNameChars, [ Dot | _ ], FileNameChars ), % has extension
        !.

ensure_extension( FileNameChars, ExtChars,
                  FileNameChars, FullFileNameChars
                ) :-
        append( FileNameChars, ExtChars, FullFileNameChars ).



%%------------------------------------------------------------------------------
%% read_terms( + input stream, - list of terms ):
%% Given an open input stream, produce all the terms that can be read from it.
%%
%% NOTE: Operator declarations are interpreted on the fly, but not deleted from
%%       output.

:- mode read_terms( +, - ).

read_terms( InputStream, Terms ) :-
        read( InputStream, Term ),
        read_terms_( InputStream, Term, Terms ).

%
read_terms_( _, end_of_file, [] ) :-
        !.

read_terms_( InputStream, Term, [ Term | Terms ] ) :-
        % term \= end_of_file,
        process_if_op_directive( Term ),
        read( InputStream, NextTerm ),
        read_terms_( InputStream, NextTerm, Terms ).

%
process_if_op_directive( (:- op( P, F, Ops)) ) :-
        !,
        op( P, F, Ops ).

process_if_op_directive( _ ).



%%------------------------------------------------------------------------------
%% write_terms( + list of terms, + output stream ):
%% Given an open output stream, write onto it all the terms from the list,
%% one per line but without any other pretty-printing.

:- mode write_terms( +, + ).

write_terms( Terms, OutputStream ) :-
        member( Term, Terms ),
        write( OutputStream, Term ),
        writeln( OutputStream, '.' ),
        fail.

write_terms( _, _ ).


%%------------------------------------------------------------------------------
%% write_clauses( + list of clauses, + output stream ):
%% Given an open output stream, write onto it all the clauses from the list.

:- mode write_clauses( +, + ).

write_clauses( Clauses, OutputStream ) :-
        member( Clause, Clauses ),
        writeclause( OutputStream, Clause ),
        fail.

write_clauses( _, _ ).



%%------------------------------------------------------------------------------
%% write_list( +stream, +list ):
%% Output the items on this list to this stream.
%% There are no spaces between items on the list.
%% Strings are printed without quotes.

write_list( S, V ) :-
        var( V ),
        !,
        warning( [ 'Incorrect invocation of write_list/1: \"',
                   write_list( S, V ),
                   '\"'
                 ]
               ).

write_list( _S, [] ) :-
        !.

write_list( S, [ H | T ] ) :-
        !,
        write( S, H ),
        write_list( S, T ).

write_list( S, NotAList ) :-
        !,
        warning( [ 'Incorrect invocation of write_list/1: \"',
                   write_list( S, NotAList ),
                   '\"'
                 ]
               ).



%%------------------------------------------------------------------------------
%% getline( + input stream, - list of character atoms ) :
%%    Reads characters from this input stream upto (and including) the nearest
%%    newline.  The newline is not included in the list of characters that is
%%    returned.

:- mode getline( +, - ).

getline( InputStream, Line ) :-
        getchar( InputStream, C ),
        getline_( InputStream, C, Line ).

%
:- mode getline_( +, +, - ).

getline_( _InputStream, '\n', []        ) :-  !.

getline_( InputStream, C   , [ C | Cs ] ) :-
        getchar( InputStream, NC ),
        getline_( InputStream, NC, Cs ).


%%------------------------------------------------------------------------------
%% putline( + output stream, + list of character strings ) :
%%    Writes the characters to this stream and follows them with a newline.

:- mode putline( +, + ).

putline( OutputStream, Cs ) :-
        putchars( OutputStream, Cs ),
        nl( OutputStream ).


%%------------------------------------------------------------------------------
%% putchars( + output stream, + list of character strings ) :
%%    Writes the characters to the current output stream.

:- mode putchars( +, + ).

putchars( _OutputStream, []         ).

putchars( OutputStream, [ C | Cs ] ) :-
        put_char( OutputStream, C ),
        putchars( OutputStream, Cs ).



%%------------------------------------------------------------------------------
%% warning( + term ):
%% warning( + list of terms ):
%% Print this term or list of terms as a warning.
%% There are no spaces between items on the list.
%% Strings are printed without quotes.

warning( V ) :-
        var( V ),
        !,
        warning( [ 'Incorrect invocation of warning/1: \"',
                   warning( V ),
                   '\"'
                 ]
               ).

warning( [] ) :-
        !,
        begin_warning,
        end_warning.

warning( [ A | B ] ) :-
        !,
        std_warning_stream( WS ),
        begin_warning,
        write_list( WS, [ A | B ] ),
        end_warning.

warning( NotAList ) :-
        begin_warning,
        std_warning_stream( WS ),
        write( WS, NotAList ),
        end_warning.


%%------------------------------------------------------------------------------
%% begin_warning:
%% Begin a warning printout.

begin_warning :-
        std_warning_stream( WS ),
        write( WS, '--- WARNING: ' ).


%%------------------------------------------------------------------------------
%% end_warning:
%% End a warning printout.

end_warning :-
        std_warning_stream( WS ),
        writeln( WS, ' ---' ).



%%------------------------------------------------------------------------------
%% error( + term ):
%% error( + list of terms ):
%% Print this term or list of terms as a error, then abort the computation.
%% There are no spaces between items on the list.
%% Strings are printed without quotes.

error( V ) :-
        var( V ),
        !,
        warning( [ 'Incorrect invocation of error/1: \"',
                   error( V ),
                   '\"'
                 ]
               ).

error( [] ) :-
        !,
        begin_error,
        end_error.

error( [ A | B ] ) :-
        !,
        begin_error,
        std_error_stream( ES ),
        write_list( ES, [ A | B ] ),
        write( ES, ' ' ),
        end_error.

error( NotAList ) :-
        begin_error,
        std_error_stream( ES ),
        write( ES, NotAList ),
        write( ES, ' ' ),
        end_error.


%%------------------------------------------------------------------------------
%% begin_error:
%% Begin an error printout.

begin_error :-
        std_error_stream( ES ),
        write( ES, '*** ERROR: ' ).


%%------------------------------------------------------------------------------
%% end_error:
%% End an error printout.

end_error :-
        std_error_stream( ES ),
        writeln( ES, '***' ),
        abort.

%%------------------------------------------------------------------------------
