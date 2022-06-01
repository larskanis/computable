require_relative 'helper'

class TestInheritance < Minitest::Test
  class MyBuilder < Computable
    calc_value :a do |*d|
      "x#{d.inspect}"
    end
  end

  class MyChild < MyBuilder
    calc_value :a do |*d|
      super() + "y#{d.inspect}"
    end
  end

  def setup
    @b = MyChild.new
  end

  def teardown
#     @b.computable_display_dot
  end

  def test_super
    assert_equal "x[]y[]", @b.a
  end
end

class TestInheritanceParallel < TestInheritance
  include Helper::EnableParallel
end
