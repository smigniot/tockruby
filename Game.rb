#!/bin/env ruby
# encoding: utf-8

require "json"

class HistoryEvent
end

COLORS = [:spades,:hearts,:diamonds,:clubs]
class Card
    def initialize(color,value)
        @color = color
        @value = value
    end
    def ==(other)
        (@color == other.color) && (@value == other.value)
    end
    def eql?(other)
        self == other
    end
    def hash
        [@color,@value].hash
    end
    def to_s
        ["A","2","3","4","5","6","7","8","9",
            "10","J","Q","K"][@value-1] +
        {:spades=>"♠", :hearts=>"♥",
            :diamonds=>"♦", :clubs=>"♣"}[@color]
    end
    def self.from_hash(h)
        c = COLORS.find {|x| x.to_s == h["color"]}
        Card.new c,h["value"]
    end
    def self.from_s(s)
        v,c = s.scan(/\w\d*|.$/)
        v = ["A","2","3","4","5","6","7","8","9",
           "10","J","Q","K"].index(v)+1;
        c = {"♠"=>:spades, "♥"=>:hearts,
            "♦"=>:diamonds, "♣"=>:clubs}[c]
        Card.new c,v
    end
    attr_reader :color,:value
end

class Deck
    def initialize
        @cards = []
    end
    def refill
        (1..13).each do |value|
            COLORS.each do |color|
                @cards.push(Card.new color,value)
            end
        end
        @cards.shuffle!
    end
    def empty?
        @cards.empty?
    end
    def draw
        refill if @cards.empty?
        @cards.pop
    end
end

STATUSES = [:out,:onbase,:running,:parked]
class Pawn
    def initialize(status=:out,position=-1)
        @status = status
        @position = position
    end
    attr_accessor :status,:position
    def ==(other)
        (@status == other.status) && (@position == other.position)
    end
    def eql?(other)
        self == other
    end
    def hash
        [@status,@position].hash
    end
end

class Mover < Pawn
    def initialize(color,pawn)
        super(pawn.status, pawn.position)
        @color = color
    end
    attr_accessor :status,:position,:color
    def ==(other)
        (@status == other.status) && (@position == other.position) && (@color == other.color)
    end
    def eql?(other)
        self == other
    end
    def hash
        [@status,@position,@color].hash
    end
end

class Player
    def initialize(name,position)
        @name = name
        @position = position
        @hand = []
        @pawns = (1..4).collect{Pawn.new}
        @exchanged = nil
    end
    def allparked?
        @pawns.select{|p| p.status == :parked}.length == 4
    end
    attr_reader :position,:pawns
    attr_accessor :name,:hand,:exchanged
end

POSITIONS=[:north,:east,:south,:west]
BASES = {:west=>24,:north=>48,:east=>72,:south=>0}
NEXTOF = {}
PREVIOUSOF = {}
FORBIDDENOF = {:west=>[],:north=>[],:east=>[],:south=>[]}
BASES.each do |position,base|
    (0..17).each do |i|
        NEXTOF[base+i] = [base+i+1]
        PREVIOUSOF[base+i+1] = base+i
    end
    NEXTOF[base+18] = [base+19,base+23]
    PREVIOUSOF[base+23] = base+18
    (19..21).each do |i|
        NEXTOF[base+i] = [base+i+1]
    end
    NEXTOF[base+23] = [(base+24)%96]
    PREVIOUSOF[(base+24)%96] = base+23
    (19..22).each do |i|
        FORBIDDENOF[position].concat([
            (base+i)%96,
            (base+24+i)%96,
            (base+(2*24)+i)%96
        ])
    end
end

class JoinEvent < HistoryEvent
    def initialize(position,name)
        @position = position
        @name = name
    end
    def to_json(*any)
        return {:type => "join",
             :name => @name,
             :position => @position}.to_json
    end
    attr_reader :name,:position
end

class ChangeEvent < HistoryEvent
    def initialize(position,card)
        @position = position
        @card = card
    end
    attr_reader :position,:card
end

class Game
    def initialize(name)
        @name = name
        @creation = Time.new
        @players = {}
        @history = [:registering]
    end
    attr_accessor :name
    attr_reader :creation,:players,:history
    def join(position,name)
        raise ArgumentError,position unless POSITIONS.include? position
        n1 = @players.length
        if @players[position]
            @players[position].name = name
        else
            @players[position] = Player.new name,position
        end
        @history.push (JoinEvent.new position,name)
        n2 = @players.length
        if n1 == 3 and n2 == 4
            @deck = Deck.new
            @history.push :exchanging
            distribute
        end
    end
    def distribute
        size = @deck.empty? ? 5 : 4
        @players.each do |position,player|
            player.hand = []
            size.times { player.hand.push(@deck.draw) }
        end
    end
    def moves(position)
        result = []
        result.concat(enter_moves position)
        result.concat(  run_moves position)
        result.concat(eight_moves position)
        result.concat( jack_moves position)
        result.concat(seven_moves position)
        if result.empty?
            @players[position].hand.collect{|c|
                WithdrawMove.new c}
        else
            result
        end
    end
    def enter_moves(position)
        player = @players[position]
        ace_kings = player.hand.select{|c| [1,13].include? c.value}
        if ace_kings.length == 0; return []; end
        if player.allparked?
            partner = @players[POSITIONS[((POSITIONS.index position)+2)%4]]
            base = BASES[partner.position]
            pawns = partner.pawns
        else
            base = BASES[position]
            pawns = player.pawns
        end
        if pawns.select{|p| p.status == :out}.length == 0; return []; end
        if pawns.select{|p| p.position == base}.length != 0; return []; end
        result = []
        ace_kings.each do |c|
            result.push(EnterMove.new c)
        end
        result
    end
    def run_moves(position)
        player = @players[position]
        runners = [1,2,3,4,5,6,8,9,10,12,13]
        runcards = player.hand.select{|c| runners.include? c.value}
        runs = []
        runcards.each do |card|
            if card.value == 4
                runs.push([-4,card])
            elsif card.value == 1
                runs.concat([[1,card],[14,card]])
            else 
                runs.push([card.value,card])
            end
        end
        color = position
        if player.allparked?
            partner = @players[POSITIONS[((POSITIONS.index position)+2)%4]]
            color = partner.position
            pawns = partner.pawns
        else
            pawns = player.pawns
        end
        pawns = pawns.select{|p| p.status != :out}
        result = []
        pawns.each do |pawn|
            runs.each do |run|
                count,card = run
                trails = dry_run([[pawn]],count,card,color)
                trails.each do |trail|
                    result.push(RunMove.new pawn,card,trail.last)
                end
            end
        end
        result
    end
    def dry_run(trails,count,card,color)
        allpawns = []
        bypawn = {}
        @players.each do |position,player|
            allpawns.concat(player.pawns)
            player.pawns.each{|p| bypawn[p] = position}
        end
        survivors = trails.dup
        count.abs.times do
            gen2 = []
            survivors.each do |trail|
                before = trail.last
                (nextones before,count,color).each do |afterPos|
                    colliders = allpawns.select{|p|p.position==afterPos}
                    if colliders.empty? or (
                            (colliders.first.status != :onbase) and
                            (bypawn[colliders.first] != color) )
                        m24 = afterPos % 24
                        newstatus = ((19<=m24)and(m24<=22)) ? :parked : :running
                        gen2.push(trail.dup.push(
                            Pawn.new newstatus,afterPos))
                    end
                end
            end
            survivors = gen2
        end
        survivors
    end
    def nextones(pawn,count,color)
        pos = pawn.position
        result = []
        if count < 0
            result = (PREVIOUSOF.include? pos)?([PREVIOUSOF[pos]]):([])
        else
            result = (NEXTOF.include? pos)?(NEXTOF[pos]):([])
        end
        toremove = FORBIDDENOF[color]
        result.select{|p| not (toremove.include? p)}
    end
    def eight_moves(position)
        player = @players[position]
        eights = player.hand.select{|c| c.value == 8}
        if eights.length == 0; return []; end
        color = position
        if player.allparked?
            partner = @players[POSITIONS[((POSITIONS.index position)+2)%4]]
            color = partner.position
            pawns = partner.pawns
        else
            pawns = player.pawns
        end
        pawns = pawns.select{|p| ((p.position % 24) == 8)}
        occupied = pawns.collect{|p| p.position}
        result = []
        eights.each do |card|
            pawns.each do |warper|
                [8,24+8,24*2+8,24*3+8].each do |destination|
                    if not (occupied.include? destination)
                        result.push(EightMove.new warper,card,
                            (Pawn.new :running,destination))
                    end
                end
            end
        end
        result
    end
    def jack_moves(position)
        player = @players[position]
        jacks = player.hand.select{|c| c.value == 11}
        if jacks.length == 0; return []; end
        color = position
        if player.allparked?
            partner = @players[POSITIONS[((POSITIONS.index position)+2)%4]]
            color = partner.position
            pawns = partner.pawns
        else
            pawns = player.pawns
        end
        result = []
        pawns.select{|p| [:running,:onbase].include? p.status}.each do |pawn|
            @players.collect{|pos,p| p.pawns}.reduce(:+).each do |candidate|
                if (candidate != pawn) and (candidate.status == :running)
                    result.push(JackMove.new pawn,candidate)
                end
            end
        end
        result
    end
    def playername(position)
        return "" if not @players
        return "" if not @players[position]
        return @players[position].name
    end
    def seven_moves(position)
        sevens = @players[position].hand.select{|c| c.value == 7}
        if sevens.length == 0; return []; end
        initial = @players.collect{|pos,p| p.pawns.collect{
            |pawn| Mover.new pos,pawn}}.reduce(:+)
        trails = [initial]
        7.times do
               trails = plusones(position,trails)
        end
        trails.collect{|trail| SevenMove.new initial,trail}
    end
    def plusones(position,trails)
        exhuberantplusones(position, trails).uniq
    end
    def exhuberantplusones(position,trails)
        survivors = []
        trails.each do |trail|
            color = position
            moving = trail.select{|m| m.color == position}
            if moving.select{|p| p.status == :parked}.length == 4
                color = POSITIONS[((POSITIONS.index position)+2)%4]
                moving = trail.select{|m| m.color == color}
            end
            moving = moving.select{|m| m.status != :out}
            moving.each do |mover|
                a = mover.position
                outcomes = (NEXTOF.include? a)?(NEXTOF[a]):([])
                toremove = FORBIDDENOF[mover.color]
                outcomes.select{|p| not (toremove.include? p)}
                outcomes.each do |b|
                    ontarget = trail.select{|m| m.position == b}
                    if(ontarget.empty? or ontarget.first.color != mover.color)
                        parked = (19 <= (b%24)) and ((b%24) <= 22)
                        s = parked ? :parked : :running
                        c = Mover.new(mover.color, (Pawn.new s,b))
                        survivors.push(trail.collect{|p| 
                            if(p == mover)
                                c
                            elsif ontarget.first == p
                                Mover.new(p.color,Pawn.new)
                            else
                                p
                            end
                        })
                    end
                end
            end
        end
        survivors
    end
	def gid
		return "game_#{@creation.to_i}"
	end
    def to_json(playing=nil)
        o = {}
        @players.each do |color,player|
            ismine = (playing == player) || (playing.nil?)
            o[color] = {
                :pawns => player.pawns.collect{|p| {
                    :position => p.position,
                    :status => p.status
                }},
                :hand => player.hand.collect{|c| {
                    :color => ismine ? c.color : 0,
                    :value => ismine ? c.value : 0
                }},
                :name => player.name
            }
        end
        o["phase"] = @history.select{|x| x.is_a?(Symbol)}.last
        o["history"] = @history
        o.to_json
    end
    def apply!(color,move)
        if move.instance_of? EnterMove
            pawn = @players[color].pawns.find{|p|p.status == :out}
            pawn.status = :onbase
            pawn.position = BASES[color]
            @players[color].hand.delete(move.card)
        elsif move.instance_of? WithdrawMove
            @players[color].hand.delete(move.card)
        else
            raise ArgumentError,move
        end
    end
    def exchange(color,card)
        n1 = @players.select{|c,p| !p.exchanged.nil?}.length
        me = @players[color]
        me.exchanged = card
        n2 = @players.select{|c,p| !p.exchanged.nil?}.length
        @history.push (ChangeEvent.new color,card)
        puts "Exchange #{color} #{card}"
        if n1 == 3 and n2 == 4
            (0..3).each do |i|
                c1,c2 = POSITIONS[i],POSITIONS[(i+2)%4]
                @players[c1].hand.push (@players[c2].exchanged)
            end
            @players.each do |c,player|
                player.hand.select!{|c| c != player.exchanged}
            end
            @history.push :playing
        end
    end
end

class Move
end

class EnterMove < Move
    def initialize(card)
        @card = card
    end
    attr_reader :card
end

class BeforeAfterMove < Move
    def initialize(pawnBefore,card,pawnAfter)
        @pawnBefore = pawnBefore
        @card = card
        @pawnAfter = pawnAfter
    end
    attr_reader :pawnBefore,:card,:pawnAfter
end

class RunMove < BeforeAfterMove
end
class EightMove < BeforeAfterMove
end

class JackMove < Move
    def initialize(mine,other)
        @mine = mine
        @other = other
    end
    attr_reader :mine,:other
end

class SevenMove < Move
    def initialize(before,after)
        @before = before
        @after = after
    end
    def to_s
        @before.select{|p|p.status != :out}.collect{|p|p.position}.join(
            ",")+" -> "+ @after.select{|p|p.status != :out}.collect{|p|p.position}.join(
                ",")
    end
    attr_reader :before,:after
end

class WithdrawMove < Move
    def initialize(card)
        @card = card
    end
    attr_reader :card
end

def puts_rand_game
    g = Game.new "Sample game"
    POSITIONS.zip(["Alice","Bob","Carol","David"]).collect do |p,name|
        g.join(p,name)
    end

    puts "{"
    g.players.each do |pos,p|
        s = p.hand.collect{|x| x.to_s}.join("")
        puts(":#{pos} => \"#{s}\",")
    end
    puts "}"
end

#	data History = Registering | Registration {
#	    registrationPosition :: Position,
#	    registrationName :: String
#	} | Exchanging | Exchange {
#	    exchangePosition :: Position,
#	    exchangeCard :: Card
#	} | Playing {
#	    firstPlayer :: Position
#	} | MoveEvent {
#	    eventPosition :: Position,
#	    eventMove :: Move
#	} | WinEvent deriving (Eq,Show,Read)

