require_relative 'helper'

class TestEnumerator < Minitest::Test
  class MyBuilder < Computable
    attr_reader :counters

    def initialize *args
      super
      @counters = {}
    end

    def self.counted_value name, format=nil, **kwargs, &block
      define_method "#{name}_counted", &block
      calc_value name, format, **kwargs do |&bl2|
        n = "#{name}#{bl2 && '!'}".to_sym
        @counters[n] ||= 0
        @counters[n] += 1
        send "#{name}_counted", &bl2
      end
    end

    counted_value(:v1) { 1 }
    counted_value(:v2) { 2 }
    counted_value(:v3) { 3 }

    counted_value :each_generated_pdi, freeze: false do |&block|
      return enum_for(:each_generated_pdi) unless block

      block.call v1
      block.call v3
      block.call v2
      41
    end

    counted_value :two_times do
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
    assert_equal [1,1,1, nil,2, nil], @b.counters.values_at(:v1, :v2, :v3, :each_generated_pdi, :each_generated_pdi!, :two_times)
  end

  def test_enumerator
    e = @b.each_generated_pdi
    a = e.to_a + e.to_a

    assert_equal [1,3,2, 1,3,2], a
    assert_equal [1,1,1, 1,2, nil], @b.counters.values_at(:v1, :v2, :v3, :each_generated_pdi, :each_generated_pdi!, :two_times)
  end

  def test_decendant_enumerator
    a = @b.two_times
    assert_equal [1,3,2, 1,3,2], a
    assert_equal [1,1,1, 1,2, 1], @b.counters.values_at(:v1, :v2, :v3, :each_generated_pdi, :each_generated_pdi!, :two_times)
#
    @b.v2 = 4
    a = @b.two_times
    assert_equal [1,3,4, 1,3,4], a
    assert_equal [1,1,1, 2,4, 2], @b.counters.values_at(:v1, :v2, :v3, :each_generated_pdi, :each_generated_pdi!, :two_times)
  end
end

class TestEnumeratorParallel < TestEnumerator
  include Helper::EnableParallel
end
