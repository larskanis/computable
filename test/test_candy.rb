require 'minitest/autorun'
require 'computable'

class TestCandy < Minitest::Test
  class MyBuilder < Computable
    attr_reader :counters

    def initialize *args
      super
      @counters = {}
    end

    def self.counted_value name, format=nil, params={}, &block
      define_method "#{name}_counted", &block
      calc_value name, format do
        @counters[name] ||= 0
        @counters[name] += 1
        send "#{name}_counted"
      end
    end

    input_value :il, String
    input_value :ir, String

    counted_value :top do
      i = il + ir
      p = i.length / 2
      i[p] = i[p].upcase
      i
    end

    counted_value :l0 do
      i = top.dup
      p = 0
      i[p] = i[p].upcase
      i
    end
    counted_value :l1 do
      i = l0.dup
      p = 1
      i[p] = i[p].upcase
      i
    end

    counted_value :r0 do
      i = top.dup
      p = -1
      i[p] = i[p].upcase
      i
    end
    counted_value :r1 do
      i = r0.dup
      p = -2
      i[p] = i[p].upcase
      i
    end

    counted_value :bot do
      l1 + r1
    end

    counted_value :fl do
      i = bot.dup
      p = (i.length-1) / 2
      i[p] = i[p].upcase
      i
    end

    counted_value :fr do
      i = bot.dup
      p = i.length / 2
      i[p] = i[p].upcase
      i
    end
  end

  def setup
    @b = MyBuilder.new
    @b.il, @b.ir = "abc", "def"
  end

  def teardown
#     @b.computable_display_dot
  end

  def test_full_calc
    assert_equal "ABcDeFabcDEF", @b.fl
    assert_equal "ABcDefAbcDEF", @b.fr
    assert_equal [1]*8, @b.counters.values_at(:top, :l0, :r0, :l1, :r1, :bot, :fl, :fr)

    @b.il = "abC"
    assert_equal "ABCDeFabCDEF", @b.fl
    assert_equal "ABCDefAbCDEF", @b.fr
    assert_equal [2]*8, @b.counters.values_at(:top, :l0, :r0, :l1, :r1, :bot, :fl, :fr)
  end

  def test_partial_1
    @b.fl
    @b.il = "Abc"
    assert_equal [1,1,1,1,1,1,1,nil], @b.counters.values_at(:top, :l0, :r0, :l1, :r1, :bot, :fl, :fr)
    @b.fr
    assert_equal [2,2,2,1,2,2,1,1], @b.counters.values_at(:top, :l0, :r0, :l1, :r1, :bot, :fl, :fr)
  end
end
