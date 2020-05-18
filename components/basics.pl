/*  Part of ClioPatria SeRQL and SPARQL server

    Author:        Jan Wielemaker
    E-mail:        J.Wielemaker@vu.nl
    WWW:           http://www.swi-prolog.org
    Copyright (c)  2010-2018, VU University Amsterdam
    All rights reserved.

    Redistribution and use in source and binary forms, with or without
    modification, are permitted provided that the following conditions
    are met:

    1. Redistributions of source code must retain the above copyright
       notice, this list of conditions and the following disclaimer.

    2. Redistributions in binary form must reproduce the above copyright
       notice, this list of conditions and the following disclaimer in
       the documentation and/or other materials provided with the
       distribution.

    THIS SOFTWARE IS PROVIDED BY THE COPYRIGHT HOLDERS AND CONTRIBUTORS
    "AS IS" AND ANY EXPRESS OR IMPLIED WARRANTIES, INCLUDING, BUT NOT
    LIMITED TO, THE IMPLIED WARRANTIES OF MERCHANTABILITY AND FITNESS
    FOR A PARTICULAR PURPOSE ARE DISCLAIMED. IN NO EVENT SHALL THE
    COPYRIGHT OWNER OR CONTRIBUTORS BE LIABLE FOR ANY DIRECT, INDIRECT,
    INCIDENTAL, SPECIAL, EXEMPLARY, OR CONSEQUENTIAL DAMAGES (INCLUDING,
    BUT NOT LIMITED TO, PROCUREMENT OF SUBSTITUTE GOODS OR SERVICES;
    LOSS OF USE, DATA, OR PROFITS; OR BUSINESS INTERRUPTION) HOWEVER
    CAUSED AND ON ANY THEORY OF LIABILITY, WHETHER IN CONTRACT, STRICT
    LIABILITY, OR TORT (INCLUDING NEGLIGENCE OR OTHERWISE) ARISING IN
    ANY WAY OUT OF THE USE OF THIS SOFTWARE, EVEN IF ADVISED OF THE
    POSSIBILITY OF SUCH DAMAGE.
*/

:- module(html_basics,
          [ hidden//2,                  % +Name, +Value
            form_input//2,              % +Label, +Input
            form_submit//1,             % +Label
            n//2,                       % +Format, +Value
            nc//2,                      % +Format, +Value
            nc//3,                      % +Format, +Value, +Options
            odd_even_row//3,            % +Row, -Next, :Content
            sort_th//3,                 % +Field, +ByNow, :Content
            insert_html_file//1         % +FileSpec
          ]).
:- use_module(library(http/html_write)).
:- use_module(library(sgml)).
:- use_module(library(lists)).
:- use_module(library(option)).
:- use_module(library(occurs)).
:- use_module(library(http/http_dispatch)).
:- use_module(library(http/http_wrapper)).

:- html_meta((
        form_input(html, html, ?, ?),
        odd_even_row(+, -, html, ?, ?),
        sort_th(+, +, html, ?, ?))).

/** <module> Simple Small HTML components
*/

                 /*******************************
                 *             FORMS            *
                 *******************************/

%!  hidden(+Name, +Value)// is det.
%
%   Create a hidden input field with given name and value

hidden(Name, Value) -->
    html(input([ type(hidden),
                 name(Name),
                 value(Value)
               ])).


%!  form_input(+Label, +Input)// is det.
%!  form_submit(+Label)// is det.
%
%   Building blocks for HTML forms. The  form itself is a two-column
%   table of class =form= with labels at  the left and inputs at the
%   right. These rules create rows for input and submit.

form_input(Label, Input) -->
    html(tr([ th(class(label), Label),
              td(Input)
            ])).


form_submit(Label) -->
    html(tr(class(buttons),
            [ th([align(right), colspan(2)],
                 input([ type(submit),
                         value(Label)
                       ]))
            ])).


                 /*******************************
                 *             TABLES           *
                 *******************************/

%!  nc(+Format, +Value)// is det.
%!  nc(+Format, +Value, +Options)// is det.
%
%   Numeric  cell.  The  value  is    formatted   using  Format  and
%   right-aligned in a table cell (td).
%
%   @param  Format is a (numeric) format as described by format/2 or
%           the constant =human=.  _Human_ formatting applies to
%           integers and prints then in abreviated (K,M,T) form,
%           e.g., 4.5M for 4.5 million.
%   @param  Options is passed as attributed to the =td= element.
%           Default alignment is =right=.

nc(Fmt, Value) -->
    nc(Fmt, Value, []).

nc(Fmt, Value, Options) -->
    { class(Value, Class),
      merge_options(Options,
                    [ align(right),
                      class(Class)
                    ], Opts),
      number_html(Fmt, Value, HTML)
    },
    html(td(Opts, HTML)).

class(Value, Class) :-
    (   integer(Value)
    ->  Class = int
    ;   float(Value)
    ->  Class = float
    ;   Class = value
    ).


%!  odd_even_row(+Row, -Next, :Content)//
%
%   Create odd/even alternating table rows from a DCG.

odd_even_row(Row, Next, Content) -->
    { (   Row mod 2 =:= 0
      ->  Class = even
      ;   Class = odd
      ),
      Next is Row+1
    },
    html(tr(class(Class), Content)).

%!  sort_th(+Field, +ByNow, :Label)
%
%   Provide a column-header for a table   that can be resorted. This
%   call creates a =th= element holding an   =a=. The =a= has either
%   CSS class =sorted= if the column is   sorted  or =resort= if the
%   column can be sorted on this column.   The use of this component
%   demands that the handler processes the parameter =sort_by= using
%   the field-name as argument.
%
%   @param  Field is the field-name that describes the sort on this
%           column.
%   @param  ByNow is the field on which the table is currently
%           sorted.
%   @param  Label is the label of the =a= element

sort_th(Name, Name, Label) -->
    html(th(a([class(sorted)], Label))).
sort_th(Name, _By, Label) -->
    { http_current_request(Request),
      http_reload_with_parameters(Request, [sort_by(Name)], HREF)
    },
    html(th(a([href(HREF), class(resort)], Label))).


                 /*******************************
                 *             NUMBERS          *
                 *******************************/

%!  n(+Format, +Value)//
%
%   HTML component to emit a number.
%
%   @see nc//2 for details.

n(Fmt, Value) -->
    { number_html(Fmt, Value, HTML) },
    html(HTML).

number_html(human, Value, HTML) :-
    integer(Value),
    !,
    human_count(Value, HTML).
number_html(Fmt, Value, HTML) :-
    number(Value),
    !,
    HTML = Fmt-[Value].
number_html(_, Value, '~p'-[Value]).


human_count(Number, HTML) :-
    Number < 1024,
    !,
    HTML = '~d'-[Number].
human_count(Number, HTML) :-
    Number < 1024*1024,
    !,
    KB is Number/1024,
    digits(KB, N),
    HTML = '~*fK'-[N, KB].
human_count(Number, HTML) :-
    Number < 1024*1024*1024,
    !,
    MB is Number/(1024*1024),
    digits(MB, N),
    HTML = '~*fM'-[N, MB].
human_count(Number, HTML) :-
    TB is Number/(1024*1024*1024),
    digits(TB, N),
    HTML = '~*fG'-[N, TB].

digits(Count, N) :-
    (   Count < 100
    ->  N = 1
    ;   N = 0
    ).


                 /*******************************
                 *         INCLUDE FILES        *
                 *******************************/

%!  insert_html_file(+Specification)//
%
%   Insert the content of an HTML   file  into the current document.
%   Only the content of the =body= element is included.

insert_html_file(Alias) -->
    { absolute_file_name(Alias, Page, [access(read)]),
      load_html_file(Page, DOM),
      contains_term(element(body, _, Body), DOM),
      Style = element(style, _, _),
      findall(Style, sub_term(Style, DOM), Styles),
      append(Styles, Body, Content)
    },
    html(Content).
