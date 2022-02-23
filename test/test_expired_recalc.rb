require_relative 'helper'

class TestExpiredRecalc < Minitest::Test
  class MyBuilder < Computable
    input_value :enable

    calc_value :a do
      b if enable
    end

    calc_value :b do
      raise StandardError, "not enabled" unless enable
      :x
    end
  end

  def setup
    @b = MyBuilder.new
  end

  def teardown
#     @b.computable_display_dot
  end

  def test_on_off
    @b.enable = true
    assert_equal :x, @b.a

    @b.enable = false
    assert_nil @b.a  # this shouldn't raise an error although b is internally recalced
    assert_raises(StandardError){ @b.b }

    @b.enable = true
    assert_equal :x, @b.a
  end
end

class TestExpiredRecalcParallel < TestExpiredRecalc
  include Helper::EnableParallel
end
