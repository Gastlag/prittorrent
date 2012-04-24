-module(ui_tracker_handler).
-export([init/3, handle/2, terminate/2]).

-behaviour(cowboy_http_handler).

init({tcp, http}, Req, _Opts) ->
    {ok, Req, undefined_state}.

handle(Req, _State) ->
    T1 = util:get_now_us(),

    %% HTTP parameters
    %% FIXME: use cowboy_http_req:peer_addr/1 when using a frontend proxy
    {{Host, _}, _} = cowboy_http_req:peer(Req),
    {Method, _} = cowboy_http_req:method(Req),
    {Path, _} = cowboy_http_req:path(Req),

    Reply =
	case (catch handle1(Req, Host, Method, Path)) of
	    {ok, Peers, Peers6} ->
		[{<<"interval">>, 600},
		 {<<"peers">>, Peers},
		 {<<"peers6">>, Peers6}];
	    {'EXIT', Reason} ->
		io:format("Error handling ~s ~p:~n~p~n", [Method, Path, Reason]),
		[{<<"failure">>, <<"Internal server error">>}]
	end,
    
    Body = benc:to_binary(Reply),
    {ok, Req2} =
	cowboy_http_req:reply(200, [{<<"Content-Type">>, <<"application/x-bittorrent">>}],
			      Body, Req),

    T2 = util:get_now_us(),
    io:format("[~.1fms] ui_tracker_handler ~s ~p~n", [(T2 - T1) / 1000, Method, Path]),
    
    {ok, Req2, undefined_state}.

handle1(Req, {0, 0, 0, 0, 0, 16#ffff, AB, CD}, Method, Path) ->
    %% Handle bindv6only=0:
    A = AB bsr 8,
    B = AB band 16#ff,
    C = CD bsr 8,
    D = CD band 16#ff,
    handle1(Req, {A, B, C, D}, Method, Path);

handle1(Req, Host, Method, Path) ->
    %% Tracker parameters
    {InfoHash, _} = cowboy_http_req:qs_val(<<"info_hash">>, Req),
    {PeerId, _} = cowboy_http_req:qs_val(<<"peer_id">>, Req),
    {Port, _} = cowboy_http_req:qs_val(<<"port">>, Req),
    {Uploaded, _} = cowboy_http_req:qs_val(<<"uploaded">>, Req),
    {Downloaded, _} = cowboy_http_req:qs_val(<<"downloaded">>, Req),
    {Left, _} = cowboy_http_req:qs_val(<<"left">>, Req),
    {Event, _} = cowboy_http_req:qs_val(<<"event">>, Req),
    {Compact, _} = cowboy_http_req:qs_val(<<"compact">>, Req),
    io:format("Tracker request: ~p ~p ~p ~p ~p ~p ~p ~p~n", [InfoHash, Host, Port, PeerId, Event, Uploaded, Downloaded, Left]),

    handle2(Method, Path, InfoHash,
	    host_to_binary(Host), binary_to_integer_or(Port, undefined), PeerId,
	    Event, Uploaded, Downloaded, Left, Compact).

handle2('GET', [<<"announce">>], <<InfoHash:20/binary>>, 
	Host, Port, <<PeerId:20/binary>>, 
	Event, Uploaded, Downloaded, Left, Compact)
  when is_integer(Port) ->
    IsSeeder = case Left of
		   <<"0">> -> true;
		   undefined -> true;
		   _ -> false
	       end,
    {ok, Peers} = model_tracker:get_peers(InfoHash, PeerId, IsSeeder),
    case Compact of
	<<"1">> ->
	    {ok,
	     << <<PeerHost/binary, PeerPort:16>>
		|| {_, <<PeerHost:4/binary>>, PeerPort} <- Peers >>,
	     << <<PeerHost/binary, PeerPort:16>>
		|| {_, <<PeerHost:16/binary>>, PeerPort} <- Peers >>};
	_ ->
	    {ok,
	     [[{<<"id">>, PeerPeerId},
	       {<<"ip">>, PeerHost},
	       {<<"port">>, PeerPort}]
	      || {PeerPeerId, <<PeerHost:4/binary>>, PeerPort} <- Peers],
	     [[{<<"id">>, PeerPeerId},
	       {<<"ip">>, PeerHost},
	       {<<"port">>, PeerPort}]
	      || {PeerPeerId, <<PeerHost:16/binary>>, PeerPort} <- Peers]}
    end;

handle2(_Method, _Path, _InfoHash,
	_Host, _Port, _PeerId,
	_Event, _Uploaded, _Downloaded, _Left, _Compact) ->
    exit(invalid_request).

terminate(_Req, _State) ->
    ok.



binary_to_integer_or(<<Bin/binary>>, _) ->
    list_to_integer(binary_to_list(Bin));
binary_to_integer_or(_, Default) ->
    Default.


host_to_binary({A, B, C, D}) ->
    <<A:8, B:8, C:8, D:8>>;
host_to_binary({A, B, C, D, E, F, G, H}) ->
    <<A:16, B:16, C:16, D:16, E:16, F:16, G:16, H:16>>.