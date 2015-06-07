   % NOTICE: %%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%
   %                                                                      %
   %  COPYRIGHT (2009) University of Dallas at Texas.                     %
   %                                                                      %
   %  Developed at the Applied Logic, Programming Languages and Systems   %
   %  (ALPS) Laboratory at UTD by Feliks Kluzniak.                        %
   %                                                                      %
   %  Permission is granted to modify this file, and to distribute its    %
   %  original or modified contents for non-commercial purposes, on the   %
   %  condition that this notice is included in all copies in its         %
   %  original form.                                                      %
   %                                                                      %
   %  THE SOFTWARE IS PROVIDED "AS IS", WITHOUT WARRANTY OF ANY KIND,     %
   %  EXPRESS OR IMPLIED, INCLUDING BUT NOT LIMITED TO THE WARRANTIES     %
   %  OF MERCHANTABILITY, FITNESS FOR A PARTICULAR PURPOSE, TITLE AND     %
   %  NON-INFRINGEMENT. IN NO EVENT SHALL THE COPYRIGHT HOLDERS OR        %
   %  ANYONE DISTRIBUTING THE SOFTWARE BE LIABLE FOR ANY DAMAGES OR       %
   %  OTHER LIABILITY, WHETHER IN CONTRACT, TORT OR OTHERWISE, ARISING    %
   %  FROM, OUT OF OR IN CONNECTION WITH THE SOFTWARE OR THE USE OR       %
   %  OTHER DEALINGS IN THE SOFTWARE.                                     %
   %                                                                      %
   %%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%

%% This is the shell for Sicstus.  See dra2_common.pl for documentation.

hide_this:- module( drap,
           [ % prog/1, load/1, old_top/0,
             op( 1010, fy, coinductive0  ),    % allow  ":- coinductive0 p/k ."
             op( 1010, fy, coinductive1 ),    % allow  ":- coinductive1 p/k ."
             op( 1010, fy, table       ),    % allow  ":- table p/k ."
             op( 1010, fy, old_first    ),    % allow  ":- old_first p/k ."
             op( 1010, fy, traces        ),    % allow  ":- traces  p/k ."
             op( 1010, fy, multifile    ),    % allow  ":- multifile  p/k ."
             op( 1010, fy, topl          ),    % allow  ":- topl p/k ."
             op( 1010, fy, support      ),    % allow  ":- support p/k ."
             op( 1010, fy, load_support )     % allow  ":- load_support filename
           ]
         ).

:- ensure_loaded( 'compatibility_utilities_swi' ).
% :- ensure_loaded( dra_table_record ).    % OK for cyclic terms
:- ensure_loaded( dra3_common ).