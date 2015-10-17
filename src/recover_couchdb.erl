%% recover_couchdb: recover_couchdb library's entry point.
-module(recover_couchdb).

-include("couch_db.hrl").

-define(CHUNK_SIZE, 4096).
-define(SIZE_BLOCK, 4096).

-export([main/1]).

%% API

main([DbFile]) ->
    main([DbFile, 0]);
main([DbFile, StartFrom]) ->
    io:format("~nrecover_couchdb: ~p, StartFrom: ~p~n", [DbFile, StartFrom]),
    DatabaseName = filename:basename(DbFile, ".couch"),
    PathToDbFile = filename:absname(DbFile),
    start(DatabaseName, PathToDbFile, list_to_integer(StartFrom)).

%% Internals

start(_DbName, FullPath, StartFrom) ->
    % io:format("~nload_nif: ~p~n", [R]),
    {ok, Fd} = file:open(FullPath, [read]),
    {ok, Db} = couch_file:open(FullPath),
    io:format("Fd: ~p ~n", [Fd]),
    % io:format("Fileinfo: ~p ~n", [file:read_file_info(FullPath)]),
    read_chunks(Fd, Db, StartFrom).

read_chunks(Fd, Db, Pos) ->
    % print some progress
    case Pos rem (1000 * 100) of
        0 -> io:format("~nPos: ~p~n", [Pos]);
        _ -> ok
    end,

    % <<Pattern:2/binary, _/binary>> = term_to_binary(kv_node),
    Pattern = <<"kv_node">>,
    Len = byte_size(Pattern),
    % io:format("read_chunks(Fd, Pos: ~p, Len:~p)~n", [Pos, Len]),
    try
        case file:pread(Fd, {bof, Pos}, Len) of
        eof ->
            io:format("EOF at Pos: ~p~n", [Pos]),
            ok;
        {ok, Data} ->
            % io:format("Pattern: ~p~n", [Pattern]),
            % io:format("Data: ~p~n", [iolist_to_binary(Data)]),
            case iolist_to_binary(Data) of
                Pattern ->
                    io:format("Match at Pos: ~p! ~n", [Pos]),
                    print_term(Db, Pos),
                    read_chunks(Fd, Db, Pos + Len);
                _ ->
                    read_chunks(Fd, Db, Pos + 1)
            end;
        {error, Reason} ->
            io:format("file:pread Error: ~p~n", [Reason])
        end
    catch Class:Error ->
        io:format("Error: ~p:~p~n", [Class, Error]),
        read_chunks(Fd, Db, Pos + 1)
    end.

print_term(Db, Pos) ->
    try
        case couch_file:pread_term(Db, Pos - 13) of
            {ok,  <<Prefix:3/binary, Doc/binary>>} ->
                pretty(Doc);
            Else ->
                io:format("~nKVNode: ~p~n", [Else])
        end
    catch Class:Error ->
        io:format("~ncouch_file:pread Error: ~p:~p~n", [Class, Error]),
        io:format("~nStacktrace: ~p", [erlang:get_stacktrace()])
    end.


pretty(<<>>) ->
    ok;
pretty(Bin) ->
    <<First:1/binary, Rest/binary>> = Bin,
    pretty(First, Rest).

pretty(<<131>>, Rest) ->
    io:format("~nTerm:"),
    pretty(Rest);
pretty(<<104>>, Rest) ->
    parse_small_tuple(Rest);
pretty(<<100>>, Rest) ->
    parse_atom(Rest);
pretty(<<108>>, Rest) ->
    parse_list(Rest);
pretty(<<97>>, Rest) ->
    parse_int(Rest);
pretty(<<109>>, Rest) ->
    parse_binary(Rest).




parse_list(<<Len:32/integer, Rest/binary>>) ->
    io:format("~nList(~p)", [Len]),
    pretty(Rest).

parse_atom(<<Len:16/integer, Term:Len/binary, Rest0/binary>>) ->
    io:format("~nAtom, Len ~p", [Len]),
    % <<Term:Len/binary, Rest/binary>> = Rest0,
    io:format("~nTerm: ~p", [Term]),
    pretty(Rest0).

parse_small_tuple(<<Arity:1/binary, Rest/binary>>) ->
    io:format("~nSmall Tuple, Arity ~p", [Arity]),
    pretty(Rest).

parse_int(<<Int:8/integer, Rest/binary>>) ->
    io:format("~nint(~p)", [Int]),
    pretty(Rest).

parse_binary(<<Len:32/integer, Bin:Len/binary, Misc:4/binary, Rest/binary>>) ->
    io:format("~nBinary, Len ~p: ~p (Misc: ~p)", [Len, Bin, Misc]),
    pretty(Rest).

%% End of Module.
