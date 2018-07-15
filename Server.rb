#!/bin/env ruby
# encoding: utf-8

require "sinatra"
require_relative "Game"
require "pstore"


# Requisites
store = PStore.new "tock.dat"
store.transaction do
	store[:gameids] ||= Array.new
end
enable :sessions


# Sinatra
get '/' do
	@latest_games = []
	store.transaction(true) do
		@latest_games = store[:gameids].reverse.collect{|i| store[i]}
	end
    erb :index
end
post '/' do
	@game = Game.new params[:gamename]	
	store.transaction do
		store[@game.gid] = @game
		store[:gameids].push @game.gid
	end
	redirect to('/')
end

get '/:gameid/join' do
  store.transaction(true) do
	  gid = params[:gameid]
	  @game = store[gid] if store[:gameids].include? gid
  end
  erb :join
end
post '/:gameid/join' do
	gid = params[:gameid]
	@color = ::POSITIONS.find {|x| params.include?(x.to_s)} 
	@name = params[@color.to_s]
	store.transaction do
		@game = store[gid] if store[:gameids].include? gid
		@game.join @color,@name
	end
	redirect to("/#{gid}/#{@color}/play")
end
get '/:gameid/refcount' do
	store.transaction(true) do
		gid = params[:gameid]
		@game = store[gid] if store[:gameids].include? gid
	end
    rc = @game.history.length
    rc.to_s
end
get '/:gameid/:color/state.json' do
	store.transaction(true) do
		gid = params[:gameid]
		@game = store[gid] if store[:gameids].include? gid
	end
	@color = ::POSITIONS.find {|x| x.to_s == params[:color]}
	@player = @game.players[@color]

    @game.to_json(@player)
end
get '/:gameid/:color/play' do
	store.transaction(true) do
		gid = params[:gameid]
		@game = store[gid] if store[:gameids].include? gid
	end
	@color = ::POSITIONS.find {|x| x.to_s == params[:color]}
	@player = @game.players[@color]
	erb :play
end
post '/:gameid/:color/play' do
    request.body.rewind
    msg = JSON.parse request.body.read
	store.transaction(true) do
		gid = params[:gameid]
		@game = store[gid] if store[:gameids].include? gid
	end
	@color = ::POSITIONS.find {|x| x.to_s == params[:color]}
	@player = @game.players[@color]
    if msg["type"] == "exchange"
        @card = Card.from_hash msg["card"]
        if @player.hand.include? @card
            store.transaction do
                gid = params[:gameid]
                @game = store[gid]
                @game.exchange(@player.position, @card)
            end
            puts "DONE on game #{@game.name} as #{@player.name} exchange #{@card}"
        else
            halt 500, "You don't have that card"
        end
    elsif msg["type"] == "play"
        halt 500, "Not implemented yet"
    else
        halt 500, "Tock server expected 'exchange' or 'play' message type"
    end

    return {"guru"=>"meditation"}.to_json
end


