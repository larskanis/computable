require_relative 'helper'

class TestRecursionDetection < Minitest::Test
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

  def teardown
#     @b.computable_display_dot
  end

  def test_recursion1
    assert_raises(Computable::RecursionDetected){ @b.recursion1 }
  end

  def test_recursion2
    assert_raises(Computable::RecursionDetected){ @b.recursion2 }
  end
end

class TestRecursionDetectionParallel < TestCandy
  include Helper::EnableParallel
end
