-module(server).

-export([start_server/0]).

-include_lib("./defs.hrl").

-spec start_server() -> _.
-spec loop(_State) -> _.
-spec do_join(_ChatName, _ClientPID, _Ref, _State) -> _.
-spec do_leave(_ChatName, _ClientPID, _Ref, _State) -> _.
-spec do_new_nick(_State, _Ref, _ClientPID, _NewNick) -> _.
-spec do_client_quit(_State, _Ref, _ClientPID) -> _NewState.

start_server() ->
    catch(unregister(server)),
    register(server, self()),
    case whereis(testsuite) of
	undefined -> ok;
	TestSuitePID -> TestSuitePID!{server_up, self()}
    end,
    loop(
      #serv_st{
	 nicks = maps:new(), %% nickname map. client_pid => "nickname"
	 registrations = maps:new(), %% registration map. "chat_name" => [client_pids]
	 chatrooms = maps:new() %% chatroom map. "chat_name" => chat_pid
	}
     ).

loop(State) ->
    receive 
	%% initial connection
	{ClientPID, connect, ClientNick} ->
	    NewState =
		#serv_st{
		   nicks = maps:put(ClientPID, ClientNick, State#serv_st.nicks),
		   registrations = State#serv_st.registrations,
		   chatrooms = State#serv_st.chatrooms
		  },
	    loop(NewState);
	%% client requests to join a chat
	{ClientPID, Ref, join, ChatName} ->
	    NewState = do_join(ChatName, ClientPID, Ref, State),
	    loop(NewState);
	%% client requests to join a chat
	{ClientPID, Ref, leave, ChatName} ->
	    NewState = do_leave(ChatName, ClientPID, Ref, State),
	    loop(NewState);
	%% client requests to register a new nickname
	{ClientPID, Ref, nick, NewNick} ->
	    NewState = do_new_nick(State, Ref, ClientPID, NewNick),
	    loop(NewState);
	%% client requests to quit
	{ClientPID, Ref, quit} ->
	    NewState = do_client_quit(State, Ref, ClientPID),
	    loop(NewState);
	{TEST_PID, get_state} ->
	    TEST_PID!{get_state, State},
	    loop(State)
    end.

%% executes join protocol from server perspective
do_join(ChatName, ClientPID, Ref, State) ->
    Chats = State#serv_st.chatrooms,
	ClientNick = maps:find(ClientPID,State#serv_st.nicks),
	case maps:find(ChatName,Chats) of 
		%% room exists
		{ok, Value} -> Value!{self(), Ref, register, ClientPID,ClientNick},
						State;
		%% room doesn't exist
		error -> Room = spawn(chatroom,start_chatroom,[ChatName]),
				 Room!{self(), Ref, register, ClientPID,ClientNick},
				 NewChats = maps:put(ChatName,Room, State#serv_st.chatrooms),
				 NewState = #serv_st {nicks = State#serv_st.nicks , registrations = State#serv_st.registrations, chatrooms= NewChats}			
	end.

	% io:format("server:do_join(...): IMPLEMENT ME~n"),
    % State.

%% executes leave protocol from server perspective
do_leave(ChatName, ClientPID, Ref, State) ->
	Chats = State#serv_st.chatrooms,
	ChatPID = maps:get(ChatName,Chats),
	OldRegList = maps:get(ChatName,State#serv_st.registrations),
	NewRegList = lists:delete(ClientPID,OldRegList),
	NewState = #serv_st {nicks = State#serv_st.nicks, registrations = maps:update(ChatName,NewRegList,State#serv_st.registrations), chatrooms = State#serv_st.chatrooms },
    ChatPID!{self(), Ref, unregister, ClientPID},
	ClientPID!{self(), Ref, ackleave},
	NewState.
	% io:format("server:do_leave(...): IMPLEMENT ME~n"),
    % State.

%% executes new nickname protocol from server perspective
do_new_nick(State, Ref, ClientPID, NewNick) ->
	Nicks = State#serv_st.nicks,
	case maps:find(NewNick,Nicks) of
		{ok, Value} -> ClientPID!{self(), Ref, errnickused},
						State;
		error -> 	NewNicks = maps:update(ClientPID,NewNick,Nicks),
					ChatNames = list:filter(fun(Id) -> maps:get(Id, State#serv_st.registrations) == ClientPID end, maps:keys(State#serv_st.registrations)),
					ChatPIDs =  list:map(fun(ChatName) -> maps:get(ChatName,State#serv_st.chatrooms) end, ChatNames),
					lists:map(fun(PID) -> PID!{self(), Ref, updatenick, ClientPID, NewNick} end , ChatPIDs),
					ClientPID!{self(), Ref, oknick},
					NewState = #serv_st {nicks = NewNicks, registrations = State#serv_st.registrations, chatrooms = State#serv_st.chatrooms}
	end. 
	 % io:format("server:do_new_nick(...): IMPLEMENT ME~n"),
    % State.

%% executes client quit protocol from server perspective
do_client_quit(State, Ref, ClientPID) ->
    io:format("server:do_client_quit(...): IMPLEMENT ME~n"),
    State.
