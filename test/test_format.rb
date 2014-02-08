require 'minitest/autorun'
require 'computable'

class TestFormat < MiniTest::Unit::TestCase
  class MyBuilder < Computable
    def self.verify_uniq_array(a)
      a.uniq.length == a.length
    end

    input_value :any
    input_value :integer, Integer
    input_value :string4, /\A.{4}\z/
    input_value :uniq_array, method(:verify_uniq_array).to_proc

    calc_value :sqrt, Numeric do
      Math.sqrt(integer) if integer>=0
    end
  end

  def setup
    @b = MyBuilder.new
  end

  def teardown
#     @b.computable_display_dot
  end

  def test_any
    @b.any = "string"
    @b.any = []
    @b.any = 123
  end

  def test_check_by_class
    assert_raises(Computable::UndefinedValue){ @b.integer }
    @b.integer = 3

    assert_raises(Computable::InvalidFormat){ @b.integer = :test }

    assert_equal 3, @b.integer
  end

  def test_check_by_regexp
    @b.string4 = "abcd"
    assert_equal "abcd", @b.string4

    assert_raises(Computable::InvalidFormat){ @b.string4 = 4 }
    assert_raises(Computable::InvalidFormat){ @b.string4 = "abcde" }

    @b.string4 = :abcd
    assert_equal :abcd, @b.string4
  end

  def test_check_by_method
    @b.uniq_array = %w[ a b c d ]
    assert_equal %w[ a b c d ], @b.uniq_array

    assert_raises(Computable::InvalidFormat){ @b.uniq_array = %w[ a b c a ] }
  end

  def test_check_calc_value
    @b.integer = 4
    assert_equal 2, @b.sqrt

    @b.integer = -4
    assert_raises(Computable::InvalidFormat){ @b.sqrt }
  end
end
