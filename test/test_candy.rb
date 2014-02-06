require 'minitest/autorun'
require 'computable'

class TestCandy < MiniTest::Unit::TestCase
  class MyBuilder < Computable
    input_value :inp, String

    calc_value :top do
      i = inp.dup
      p = i.length / 2
      i[p] = i[p].upcase
      i
    end

    calc_value :l0 do
      i = top.dup
      p = 0
      i[p] = i[p].upcase
      i
    end
    calc_value :l1 do
      i = l0.dup
      p = 1
      i[p] = i[p].upcase
      i
    end

    calc_value :r0 do
      i = top.dup
      p = -1
      i[p] = i[p].upcase
      i
    end
    calc_value :r1 do
      i = r0.dup
      p = -2
      i[p] = i[p].upcase
      i
    end

    calc_value :bot do
      l1 + r1
    end

    calc_value :fin do
      i = bot.dup
      p = (i.length-1) / 2
      i[p] = i[p].upcase
      i
    end
  end

  def setup
    @b = MyBuilder.new
  end

  def teardown
#     @b.computable_display_dot
  end

  def test_full_calc
    @b.inp = "abcdef"
    assert_equal "ABcDeFabcDEF", @b.fin
  end
end
