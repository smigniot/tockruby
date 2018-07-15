#!/bin/env ruby
# encoding: utf-8

require_relative "Game"
require "test/unit"


def factored_game(position,hand)
    g = Game.new "Sample game"
    POSITIONS.zip(["Alice","Bob","Carol","David"]).collect do |p,name|
        g.join(p,name)
    end
    g.players[position].hand = hand
    g
end

def forged_game(d)
    g = Game.new "Forged game"
    POSITIONS.zip(["Alice","Bob","Carol","David"]).collect do |p,name|
        g.join(p,name)
    end
    d.each do |color,hand|
        g.players[color].hand = ashand(hand)
    end
    g
end

def ashand(l)
    l.scan(/[A2345678910JQK]+[♠♥♦♣]/).collect{|s| Card.from_s(s)}
end

class TestGame < Test::Unit::TestCase

    def test_equality
        i = 1
        c1 = Card.new :spades,10
        c2 = Card.new :spades,9+i
        c3 = Card.new :hearts,11
        assert_equal(c1,c2)
        assert_equal(c3.to_s,"J♥")
    end

    def test_join
        g = Game.new "Sample game"
        g.join(:north,"Alice")
        g.join(:east,"Bob")
        g.join(:south,"Carol")
        assert_equal(0,g.players[:north].hand.length)
        g.join(:west,"David")
        assert_equal(5,g.players[:north].hand.length)
        g.players.each { |p,player| player.hand = [] }
        g.distribute
        assert_equal(4,g.players[:north].hand.length)
    end

    def test_ashand
        h1 = ashand "A♦2♥K♣"
        assert_equal([
            Card.new(:diamonds,1),
            Card.new(:hearts,2),
            Card.new(:clubs,13),
        ],h1)
    end

    def test_enter
        # Ace or kings allow entering the board
        g = factored_game :north, (ashand "A♦2♥K♣")
        assert_equal(2, g.moves(:north).select{
                |m| m.instance_of? EnterMove}.length)

        # No entering with other cards
        g = factored_game :north,(ashand "J♦2♥J♣")
        assert_equal(0, g.moves(:north).select{
                |m| m.instance_of? EnterMove}.length)

        # No entering when base is occupied by player color
        [:onbase,:running].each do |status|
            g = factored_game :north, (ashand "A♦2♥K♣")
            g.players[:north].pawns[0] = Pawn.new status,BASES[:north]
            assert_equal(0, g.moves(:north).select{
                    |m| m.instance_of? EnterMove}.length)
        end
    end

    def test_run_simple
        g = factored_game :north, (ashand "2♥")
        p = Pawn.new :running,BASES[:north]
        g.players[:north].pawns[0] = p
        runs = g.moves(:north).select{ |m| m.instance_of? RunMove}
        assert_equal(1, runs.length)
        run = runs.first
        assert_equal(p, run.pawnBefore)
        assert_equal((Card.from_s "2♥"), run.card)
        assert_equal(Pawn.new(:running,BASES[:north]+2), run.pawnAfter)
    end
    def test_run_enter
        g = factored_game :west, (ashand "2♥")
        p = Pawn.new :running,18
        g.players[:west].pawns[0] = p
        runs = g.moves(:west).select{ |m| m.instance_of? RunMove}
        assert_equal(2, runs.length)
        assert_equal([20,24], runs.collect{|rm| rm.pawnAfter.position}.sort)
    end
    def test_run_wrongparking
        g = factored_game :north, (ashand "2♥")
        p = Pawn.new :running,18
        g.players[:north].pawns[0] = p
        runs = g.moves(:north).select{ |m| m.instance_of? RunMove}
        assert_equal(1, runs.length)
        assert_equal([24], runs.collect{|rm| rm.pawnAfter.position}.sort)
    end
    def test_run_failpark
        [2,3,5].each do |val|
            g = factored_game :west, (ashand "#{val}♥")
            p = Pawn.new :running,17
            g.players[:west].pawns[0] = p
            runs = g.moves(:west).select{ |m| m.instance_of? RunMove}
            assert_equal(2, runs.length)
            assert_equal([17+val,17+val+4], runs.collect{
                    |rm| rm.pawnAfter.position}.sort)
        end
        g = factored_game :west, (ashand "6♥")
        p = Pawn.new :running,17
        g.players[:west].pawns[0] = p
        runs = g.moves(:west).select{ |m| m.instance_of? RunMove}
        assert_equal(1, runs.length)
        assert_equal([17+4+6], runs.collect{|rm| rm.pawnAfter.position}.sort)
    end
    def test_run_constants
        assert_equal(96-4, NEXTOF.length) # last 4 parked pos have no next
        assert_equal(96-4*4, PREVIOUSOF.length) # no previous in parkings
        FORBIDDENOF.each do |position,forbidden|
            assert_equal(4*3, forbidden.length) # other parkings
        end
    end
    def test_run_four1
        g = factored_game :west, (ashand "4♥")
        g.players[:west].pawns[0] = Pawn.new :running,17
        assert_equal(13, g.moves(:west).first.pawnAfter.position)
        g = factored_game :west, (ashand "4♥")
        g.players[:west].pawns[0] = Pawn.new :running,3
        assert_equal(95, g.moves(:west).first.pawnAfter.position)
        g = factored_game :west, (ashand "4♥")
        g.players[:west].pawns[0] = Pawn.new :running,2
        assert_equal(90, g.moves(:west).first.pawnAfter.position)
    end
    def test_run_nofour
        g = factored_game :west, (ashand "4♥")
        g.players[:west].pawns[0] = Pawn.new :parked,22
        assert_equal(0, g.moves(:west).select{
                |m| m.instance_of? RunMove}.length)
    end
    def test_run_nojump
        g = factored_game :west, (ashand "2♥")
        g.players[:west].pawns[0] = Pawn.new :running,10
        g.players[:west].pawns[1] = Pawn.new :running,13
        runs = g.moves(:west).select{ |m| m.instance_of? RunMove}
        assert_equal(2, runs.length)
        assert_equal([12,15], runs.collect{|rm| rm.pawnAfter.position}.sort)

        g = factored_game :west, (ashand "3♥")
        g.players[:west].pawns[0] = Pawn.new :running,10
        g.players[:west].pawns[1] = Pawn.new :running,13
        runs = g.moves(:west).select{ |m| m.instance_of? RunMove}
        assert_equal(1, runs.length)
        assert_equal([16], runs.collect{|rm| rm.pawnAfter.position}.sort)

        g = factored_game :west, (ashand "6♥")
        g.players[:west].pawns[0] =  Pawn.new :running,47
        g.players[:north].pawns[1] = Pawn.new  :onbase,48
        runs = g.moves(:west).select{ |m| m.instance_of? RunMove}
        assert_equal(0, runs.length)
    end
    def test_eight_simple
        g = factored_game :west, (ashand "8♠")
        g.players[:west].pawns[0] =  Pawn.new :running,8
        eights = g.moves(:west).select{ |m| m.instance_of? EightMove}
        assert_equal(3, eights.length)
        assert_equal([32,56,80], eights.collect{
                |rm| rm.pawnAfter.position}.sort)
    end
    def test_eight_multi
        g = factored_game :west, (ashand "8♠")
        g.players[:west].pawns[0] =  Pawn.new :running,8
        g.players[:west].pawns[1] =  Pawn.new :running,56
        eights = g.moves(:west).select{ |m| m.instance_of? EightMove}
        assert_equal(4, eights.length)
        assert_equal([32,32,80,80], eights.collect{
                |rm| rm.pawnAfter.position}.sort)
    end
    def test_eight_crunch
        g = factored_game :west, (ashand "8♠")
        g.players[:west].pawns[0] =  Pawn.new :running,8
        g.players[:north].pawns[1] =  Pawn.new :running,56
        eights = g.moves(:west).select{ |m| m.instance_of? EightMove}
        assert_equal(3, eights.length)
        assert_equal([32,56,80], eights.collect{
                |rm| rm.pawnAfter.position}.sort)
    end

    def test_jack_simple
        g = factored_game :west, (ashand "J♠")
        g.players[:west].pawns[0] =  Pawn.new :running,8
        jms = g.moves(:west).select{ |m| m.instance_of? JackMove}
        assert_equal(0, jms.length)
        g = factored_game :west, (ashand "J♠")
        g.players[:west].pawns[0] =  Pawn.new :running,8
        g.players[:west].pawns[1] =  Pawn.new :running,24
        jms = g.moves(:west).select{ |m| m.instance_of? JackMove}
        l = jms.collect{|jm| "#{jm.mine.position}-#{jm.other.position}"}.sort
        assert_equal(["24-8","8-24"],l)
        g = factored_game :west, (ashand "J♠")
        g.players[:west].pawns[0] =  Pawn.new :running,8
        g.players[:north].pawns[1] =  Pawn.new :running,24
        jms = g.moves(:west).select{ |m| m.instance_of? JackMove}
        l = jms.collect{|jm| "#{jm.mine.position}-#{jm.other.position}"}.sort
        assert_equal(["8-24"],l)
        g = factored_game :west, (ashand "J♠")
        g.players[:west].pawns[0] =  Pawn.new :running,8
        g.players[:west].pawns[1] =  Pawn.new :onbase,24
        jms = g.moves(:west).select{ |m| m.instance_of? JackMove}
        l = jms.collect{|jm| "#{jm.mine.position}-#{jm.other.position}"}.sort
        assert_equal(["24-8"],l)
    end

    def test_jack_impossible
        g = factored_game :west, (ashand "J♠")
        g.players[:west].pawns[0] =  Pawn.new :running,8
        g.players[:south].pawns[0] = Pawn.new :onbase,0
        jms = g.moves(:west).select{ |m| m.instance_of? JackMove}
        assert_equal(0, jms.length)
        g = factored_game :west, (ashand "J♠")
        g.players[:west].pawns[0] = Pawn.new :running,8
        g.players[:west].pawns[1] = Pawn.new :parked,22
        jms = g.moves(:west).select{ |m| m.instance_of? JackMove}
        assert_equal(0, jms.length)
    end

    def test_seven_simple
        g = factored_game :west, (ashand "7♠")
        g.players[:west].pawns[0] = Pawn.new :running,8
        sm = g.moves(:west).select{ |m| m.instance_of? SevenMove}
        assert_equal(1, sm.length)
        g = factored_game :west, (ashand "7♠")
        g.players[:west].pawns[0] = Pawn.new :running,8
        g.players[:west].pawns[2] = Pawn.new :parked,22
        sm = g.moves(:west).select{ |m| m.instance_of? SevenMove}
        assert_equal(1, sm.length)
        g = factored_game :west, (ashand "7♠")
        g.players[:west].pawns[0] = Pawn.new :running,8
        g.players[:west].pawns[1] = Pawn.new :running,50
        g.players[:west].pawns[2] = Pawn.new :parked,22
        sm = g.moves(:west).select{ |m| m.instance_of? SevenMove}
        assert_equal(8, sm.length)
        g = factored_game :west, (ashand "7♠")
        g.players[:west].pawns[0] = Pawn.new :parked,22
        sm = g.moves(:west).select{ |m| m.instance_of? SevenMove}
        assert_equal(0, sm.length)
    end

    def test_seven_kills
        g = factored_game :west, (ashand "7♠")
        g.players[:west].pawns[0] = Pawn.new :running,8
        g.players[:west].pawns[1] = Pawn.new :running,50
        g.players[:north].pawns[0] = Pawn.new :running,51
        sm = g.moves(:west).select{ |m| m.instance_of? SevenMove}
        assert(sm.collect{|x| x.to_s}.include? "51,8,50 -> 51,15,50")
        assert(sm.collect{|x| x.to_s}.include? "51,8,50 -> 13,52")
    end

    def test_seven_multiplayer
        g = factored_game :west, (ashand "7♠")
        g.players[:west].pawns[0] = Pawn.new :parked,22
        g.players[:west].pawns[1] = Pawn.new :parked,21
        g.players[:west].pawns[2] = Pawn.new :parked,19
        g.players[:west].pawns[3] = Pawn.new :running,17

        g.players[:east].pawns[0] = Pawn.new :parked,45
        g.players[:east].pawns[1] = Pawn.new :parked,44
        g.players[:east].pawns[2] = Pawn.new :parked,43
        g.players[:east].pawns[3] = Pawn.new :parked,42

        sm = g.moves(:west).select{ |m| m.instance_of? SevenMove}
        assert(sm.collect{|m| m.to_s}.include?(
            "45,44,43,42,22,21,19,17 -> 46,45,44,43,22,21,20,19"))
    end

    def test_samples
        g = forged_game({
            :north => "6♠5♦9♥10♥Q♣",
            :east => "10♣7♥2♥8♦A♦",
            :south => "3♦Q♠10♦K♦J♥",
            :west => "8♥2♠6♣2♦9♣"
        })
        [:north,:west].each do |pos|
            assert_equal(5,g.moves(:north).select{
                |m|m.instance_of? WithdrawMove}.length)
        end
        [:south,:east].each do |pos|
            l = g.moves(pos)
            assert_equal(1,l.length)
            assert(l.first.instance_of? EnterMove)
        end
    end

    def test_apply
        g = forged_game({
            :north => "6♠5♦9♥10♥Q♣",
            :west => "8♥2♠6♣2♦9♣",
            :south => "3♦Q♠10♦K♦J♥",
            :east => "10♣7♥2♥8♦A♦"
        })
        assert(g.players[:east].pawns.select{|p|p.status != :out}.empty?)
        g.apply!(:north,WithdrawMove.new(Card.from_s("6♠")))
        g.apply!(:west,WithdrawMove.new(Card.from_s("8♥")))
        g.apply!(:south,g.moves(:south).first)
        assert_equal(1,g.players[:south].pawns.select{
            |p|p.status == :onbase}.length)
        g.apply!(:east,g.moves(:east).first)
        assert(! g.players[:east].pawns.select{|p|p.status != :out}.empty?)
        assert_equal(1,g.players[:east].pawns.select{
            |p|p.status == :onbase}.length)
        g.players.each do |color,player|
            assert_equal(4,player.hand.length)
        end
    end

end

