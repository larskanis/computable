require_relative 'helper'

class TestFreeze < Minitest::Test
  class MyBuilder < Computable
    input_value :no_freeze1, String, freeze: false
    calc_value :no_freeze2, String, freeze: false do
      no_freeze1 * 2
    end

    input_value :freeze1, String
    calc_value :freeze2, String do
      freeze1 * 2
    end
  end

  def setup
    @b = MyBuilder.new
  end

  def teardown
#     @b.computable_display_dot
  end

  def test_no_freeze
    @b.no_freeze1 = "abc"
    assert !@b.no_freeze1.frozen?, "shouldn't be frozen"
    assert !@b.no_freeze2.frozen?, "shouldn't be frozen"
  end

  def test_freeze
    @b.freeze1 = "def"
    assert @b.freeze1.frozen?, "should be frozen"
    assert @b.freeze2.frozen?, "should be frozen"
  end
end

class TestFreezeParallel < TestFreeze
  include Helper::EnableParallel
end
