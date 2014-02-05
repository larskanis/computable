require 'minitest/autorun'
require 'computable'

class TestGraphs < MiniTest::Unit::TestCase
  class MyBuilder < Computable
    calc_value :recursion1 do
      recursion1
    end

    calc_value :recursion2 do
      recursion3
    end
    calc_value :recursion3 do
      recursion4
    end
    calc_value :recursion4 do
      recursion2
    end
  end

  def setup
    @b = MyBuilder.new
  end

  def test_recursion1
    assert_raises(Computable::RecursionDetected){ @b.recursion1 }
  end

  def test_recursion2
    assert_raises(Computable::RecursionDetected){ @b.recursion2 }
  end
end
