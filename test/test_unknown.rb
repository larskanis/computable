require 'minitest/autorun'
require 'computable'

class TestUnknown < Minitest::Test
  class MyTruth
    def ==(obj)
      true
    end
  end

  class MyFault
    def ==(obj)
      false
    end
  end

  class MyBuilder < Computable
    input_value :v1

    calc_value :v2 do
      v1
    end
  end

  def setup
    @b = MyBuilder.new
  end

  def teardown
#     @b.computable_display_dot
  end

  def test_eq_true
    @b.v1 = v = MyTruth.new
    assert_same @b.v1, v
    assert_same @b.v2, v
  end

  def test_eq_false
    @b.v1 = v = MyFault.new
    assert_same @b.v1, v
    assert_same @b.v2, v
  end
end
