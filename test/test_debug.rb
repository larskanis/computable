require_relative 'helper'

class TestDebug < Minitest::Test
  class MyBuilder < Computable
    input_value :inp
    calc_value :cal do
      inp * 2
    end
  end

  def setup
    @b = MyBuilder.new
  end

  def teardown
#     @b.computable_display_dot
  end

  def test_enable_debug
    refute @b.computable_debug
    @b.computable_debug = true
    assert @b.computable_debug
    @b.computable_debug = false
    refute @b.computable_debug
  end

  def test_prints_debug
    @b.computable_debug = true

    assert_output(/set inp/){ @b.inp = 3 }
    cal = nil
    assert_output(/do calc/){ cal = @b.cal }

    assert_equal 6, cal
  end
end

class TestDebugParallel < TestDebug
  include Helper::EnableParallel
end
