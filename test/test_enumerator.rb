require_relative 'helper'

class TestEnumerator < Minitest::Test
  class MyBuilder < Computable
    calc_value(:v1) { 1 }
    calc_value(:v2) { 2 }
    calc_value(:v3) { 3 }

    calc_value :each_generated_pdi, freeze: false do |&block|
      return enum_for(:each_generated_pdi) unless block

      block.call v1
      block.call v3
      block.call v2
      41
    end

    calc_value :two_times do
      each_generated_pdi.to_a + each_generated_pdi.to_a
    end
  end

  def setup
    @b = MyBuilder.new
  end

  def teardown
#     @b.computable_display_dot
  end

  def test_block
    a = []
    res = @b.each_generated_pdi do |v|
      a << v
    end
    res = @b.each_generated_pdi do |v|
      a << v
    end

    assert_equal [1,3,2, 1,3,2], a
    assert_equal 41, res
  end

  def test_enumerator
    e = @b.each_generated_pdi
    a = e.to_a + e.to_a

    assert_equal [1,3,2, 1,3,2], a
  end

  def test_decendant_enumerator
    a = @b.two_times
    assert_equal [1,3,2, 1,3,2], a

    @b.v2 = 4
    a = @b.two_times
    assert_equal [1,3,4, 1,3,4], a
  end
end

class TestEnumeratorParallel < TestEnumerator
  include Helper::EnableParallel
end
