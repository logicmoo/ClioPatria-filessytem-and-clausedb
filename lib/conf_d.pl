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

:- module(conf_d,
          [ load_conf_d/2,              % +Directories, +Options
            conf_d_enabled/1,           % -ConfDir
            conf_d_reload/0,
            conf_d_members/3,           % +Directory, -FileData, +Options
            conf_d_member_data/3,       % ?Field, +FileData, -Value
            conf_d_configuration/3      % +Available, +Enabled, -Configs
          ]).
:- use_module(library(option)).
:- use_module(library(ordsets)).
:- use_module(library(lists)).
:- use_module(library(apply)).
:- use_module(library(version)).
:- use_module(library(prolog_xref)).
:- if(exists_source(library(pldoc/doc_process))).
:- use_module(library(pldoc)).
:- use_module(library(pldoc/doc_process)).
:- endif.

/** <module> Load configuration directories

This module deals with  loading   configuration-files  from a directory.
This is pretty simple because  we   assume  that configuration files are
Prolog  source-files.  We  (can)  use    file_search_path/2   to  define
one or more configuration directories.

Files are loaded in alphabetical  order.   If  one  config file requires
another, there are two solutions:

    * Use some numbering scheme, e.g., name the files 00-prefixes.pl,
    01-paths.pl, etc.
    * Use a use_module/1 call to include the config file(s) on which we
    depend.
*/

%!  load_conf_d(+Spec, +Options) is det.
%
%   Locate configuration directories and load   their  config files.
%   Config files themselves are Prolog source files.  Options:
%
%       * solutions(+Sols)
%       Passed to absolute_file_name/3.  Default is =all=, loading
%       config files from all directories described by Spec.
%       * extension(+Ext)
%       File-name extension for the config files.  Default is =pl=.
%
%   Other options are passed to load_files/2.
%
%   @param  Spec is either the specification of a directory according
%           to absolute_file_name/3 or a list thereof.  Duplicate
%           directories are removed.
%   @tbd    There is a bug forking processes in one thread and
%           waiting for X11 in another, which deadlocks in
%           fork_atfree().  So, we must ensure we have the git
%           versions in time :-(

load_conf_d(Spec, Options) :-
    set_top_dir,
    select_option(solutions(Sols), Options, LoadOptions0, all),
    merge_options(LoadOptions0,
                  [ if(changed),
                    extension(pl)
                  ], LoadOptions),
    phrase(collect_dirs(Spec, Sols), Dirs),
    list_to_set(Dirs, Set),
    maplist(conf_d_files(Options), Set, Pairs),
    keep_last(Pairs, Final),
    maplist(load_conf_dir(LoadOptions), Final),
    git_update_versions(_).         % See above

collect_dirs([], _) --> !.
collect_dirs([H|T], Sols) -->
    !,
    collect_dirs(H, Sols),
    collect_dirs(T, Sols).
collect_dirs(Spec, Sols) -->
    findall(Dir, absolute_file_name(Spec, Dir,
                                    [ file_type(directory),
                                      file_errors(fail),
                                      access(read),
                                      solutions(Sols)
                                    ])).


:- dynamic
    conf_d/3.                       % Directory, Options, Files

load_conf_dir(Options, Dir-Files) :-
    delete(Options, extension(_), LoadOptions),
    update_conf_d(Dir, Files, Options),
    maplist(load_conf(LoadOptions), Files).

load_conf(Options, File) :-
    print_message(informational, conf_d(load(File))),
    load_files(user:File, [module(File)|Options]).

conf_d_files(Options, Dir, Dir-Files) :-
    option(extension(Ext), Options, pl),
    atomic_list_concat([Dir, '/*.', Ext], Pattern),
    expand_file_name(Pattern, Matches),
    include(accessible, Matches, MatchedFiles),
    maplist(absolute_file_name, MatchedFiles, CanonicalFiles),
    sort(CanonicalFiles, Files).

accessible(File) :-
    access_file(File, read).

%!  keep_last(+PairsIn, -PairsOut) is det.
%
%   PairsIn is a list Dir-Files holding Files to be loaded from Dir.
%   We remove all  files  from  Files   that  appear  with  a  later
%   directory.

keep_last([], []).
keep_last([Dir-Files0|T0], [Dir-Files|T]) :-
    exclude(in_later_dir(T0), Files0, Files),
    keep_last(T0, T).

in_later_dir(Pairs, File) :-
    file_base_name(File, Base),
    \+ multi(Base),
    member(_-Files, Pairs),
    member(F2, Files),
    file_base_name(F2, Base).

multi('010-packs.pl').

update_conf_d(Dir, Files, Options) :-
    \+ conf_d(Dir, _, _),
    !,
    assert(conf_d(Dir, Options, Files)).
update_conf_d(Dir, Files, Options) :-
    retract(conf_d(Dir, _, OldFiles)),
    !,
    ord_subtract(OldFiles, Files, Removed),
    (   Removed \== []
    ->  print_message(informational, conf_d(unload(Removed))),
        catch(maplist(unload_file, Removed), E,
              print_message(error, E))
    ;   true
    ),
    ord_subtract(Files, OldFiles, New),
    (   New \== []
    ->  print_message(informational, conf_d(new(New)))
    ;   true
    ),
    assert(conf_d(Dir, Options, Files)).

%!  conf_d_enabled(-Dir) is nondet.
%
%   True if Dir is a directory from which config files are loaded.

conf_d_enabled(Dir) :-
    conf_d(Dir, _, _).

%!  conf_d_reload is det.
%
%   Reload configuration files  after  adding   or  deleting  config
%   files. Note that this is not exactly  the same as restarting the
%   server. First of all, the order in   which  the files are loaded
%   may be different and second, wiping a config file only wipes the
%   clauses and module. Side effects, for   example  due to executed
%   directives, are *not* reverted.

conf_d_reload :-
    findall(Dir-Options-Files, conf_d(Dir, Options, Files), Triples),
    forall(member(Dir-Options-Files, Triples),
           load_conf_dir(Options, Dir-Files)).

%!  conf_d_members(+Dir, -InfoRecords:list, Options) is det
%
%   Provide information about config files in Dir.
%
%   @param InfoRecords is a list of terms. The predicate
%   conf_d_member_data/3 must be used to extract data from these
%   terms.

conf_d_members(DirSpec, InfoRecords, Options) :-
    findall(Files,
            ( absolute_file_name(DirSpec, Dir,
                                 [ file_type(directory),
                                   solutions(all)
                                 ]),
              conf_d_files(Dir, Files, Options)
            ), FileLists),
    append(FileLists, Files0),
    sort(Files0, Files), % remove duplicates introduced by absolute & relative ClioPatria paths
    maplist(conf_file, Files, InfoRecords).

conf_file(File, config_file(Path, Module, Title)) :-
    xref_public_list(File, Path, Module, _Public, _Meta, []),
    !,
    (   current_predicate(doc_comment/4),
        doc_comment(_:module(Title), Path:_, _Summary, _Comment)
    ->  true
    ;   true
    ).
conf_file(File, config_file(File, _Module, _Title)).

%!  conf_d_member_data(?Field, +ConfigInfo, ?Value) is nondet.
%
%   True if Value is the value   for Field in ConfigInfo. ConfigInfo
%   is an opaque term as returned   by conf_d_info/3. Defined fields
%   are:
%
%       * file
%       Absolute path of the file
%       * module
%       Module defined in the file (can fail)
%       * title
%       Comment-title (from /** <module> Title .. */)
%       * loaded
%       Boolean, indicating whether the file is currently loaded.

conf_d_member_data(file,   config_file(F, _, _), F).
conf_d_member_data(module, config_file(_, M, _), M) :- nonvar(M).
conf_d_member_data(title,  config_file(_, _, T), T) :- nonvar(T).
conf_d_member_data(loaded, config_file(F, _, _), B) :-
    (   source_file(F)
    ->  B = true
    ;   B = false
    ).


%!  set_top_dir
%
%   Maintains a file search path =cp_application=   to  point to the
%   directory from which the configuration is loaded. Normally, that
%   is the directory holding =|run.pl|=.

set_top_dir :-
    (   source_file(add_relative_search_path(_,_), File)
    ->  file_directory_name(File, Dir)
    ;   prolog_load_context(directory, Dir)
    ->  true
    ;   working_directory(Dir,Dir)
    ),
    (   user:file_search_path(cp_application, Dir)
    ->  true
    ;   assert(user:file_search_path(cp_application, Dir))
    ).

%!  conf_d_configuration(+Available, +Enabled, -Configs) is det.
%
%   @param  Available is a directory or alias providing the
%           available configurations (e.g., config_available(.))
%   @param  Enabled is a directory or alias providing the installed
%           configuration (e.g., 'config-enabled')
%   @param  Configs is a list if Key-[Example,Installed], where
%           either is (-) or a config data item as required by
%           conf_d_member_data/3.  The list is sorted on Key.

conf_d_configuration(Available, Enabled, Configs) :-
    keyed_config(Available, Templ),
    keyed_config(Enabled, Installed),
    merge_pairlists([Templ, Installed], Configs).


keyed_config(Dir, List) :-
    conf_d_members(Dir, TemplMembers, []),
    map_list_to_pairs(key_by_file, TemplMembers, List0),
    keysort(List0, List).

key_by_file(Data, Key) :-
    conf_d_member_data(file, Data, Path),
    file_name_extension(Plain, _, Path),
    file_base_name(Plain, Key).


                 /*******************************
                 *             LIB              *
                 *******************************/

%!  merge_pairlists(+PairLists, -Merged)
%
%   PairLists is a list of lists  of   K-V  pairs.  Merged is a K-VL
%   list, where each VL is  a  list   of  values  on K in PairLists.
%   Missing values are returned as (-).  For example:
%
%     ==
%     ?- merge_pairlists([ [a-1, d-4],
%                          [a-1, c-3],
%                          [b-2]
%                        ], Merged).
%     Merged = [a-[1,1,-], b-[-,-,2], d-[4,-,-], c-[-,3,-]].
%     ==
%
%   @tbd Is this useful and generic enough for library(pairs)?

merge_pairlists(Lists, Merged) :-
    heads(Lists, Heads),
    sort(Heads, Sorted),
    merge_pairlists(Sorted, Lists, Merged).

heads([], []).
heads([[K-_|_]|T0], [K|T]) :-
    !,
    heads(T0, T).
heads([[]|T0], T) :-
    heads(T0, T).

merge_pairlists([], _, []).
merge_pairlists([K|T0], Lists, [K-Vs|T]) :-
    take_key(Lists, K, NewLists, NewKsUnsorted, Vs),
    sort(NewKsUnsorted, NewKs),
    ord_union(T0, NewKs, Ks),
    merge_pairlists(Ks, NewLists, T).

take_key([], _, [], [], []).
take_key([List|T0], K, NewLists, NewKs, Vs) :-
    (   List = [KH-V|ListT],
        KH == K
    ->  NewLists = [ListT|T],
        Vs = [V|Vs1],
        (   ListT = [NewK-_|_]
        ->  NewKs = [NewK|NewKs1]
        ;   NewKs1 = NewKs
        ),
        take_key(T0, K, T, NewKs1, Vs1)
    ;   NewLists = [List|T],
        Vs = [(-)|Vs1],
        take_key(T0, K, T, NewKs, Vs1)
    ).


                 /*******************************
                 *            MESSAGES          *
                 *******************************/

:- multifile
    prolog:message//1.

prolog:message(conf_d(Message)) -->
    message(Message).

message(unload(Files)) -->
    [ 'Unloaded the following config files:'-[] ],
    files(Files).
message(new(Files)) -->
    [ 'Added the following config files:'-[] ],
    files(Files).
message(load(File)) -->
    [ 'Config: ~w'-[File] ].

files([]) --> [].
files([H|T]) --> [ nl, '    ~w'-[H] ], files(T).
