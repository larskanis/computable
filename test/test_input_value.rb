require 'minitest/autorun'
require 'computable'

class TestInputValue < Minitest::Test
  class MyBuilder < Computable
    input_value :i

    calc_value :o do
      i * 2
    end
  end

  def setup
    @b = MyBuilder.new
  end

  def teardown
#     @b.computable_display_dot
  end

  def test_undefined_input
    assert_raises(Computable::UndefinedValue){ @b.i }
    assert_raises(Computable::UndefinedValue){ @b.o }

    @b.i = 3
    assert_equal 3, @b.i
    assert_equal 6, @b.o

    @b.i = Computable::Unknown
    assert_raises(Computable::UndefinedValue){ @b.o }
    assert_raises(Computable::UndefinedValue){ @b.i }

    @b.i = 3
    assert_equal 6, @b.o
    assert_equal 3, @b.i
  end

  def test_define_calc_value
    @b.o = 5
    assert_equal 5, @b.o

    @b.o = Computable::Unknown
    assert_raises(Computable::UndefinedValue){ @b.o }

    @b.i = 3
    assert_equal 6, @b.o
  end
end
