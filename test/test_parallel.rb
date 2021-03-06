require 'minitest/autorun'
require 'computable'

class TestParallel < Minitest::Test
  class MyBuilder < Computable
    input_value :i1, Integer
    input_value :i2, Integer

    def self.p(idx)
      calc_value "p#{idx}" do
        sleep 0.1
        i1
      end
    end

    def self.q(idx)
      calc_value "q#{idx}" do
        sleep 0.1
        send("p#{idx}") + i2
      end
    end

    0.upto(4) do |idx|
      p idx
      q idx
    end

    calc_value :o do
      0.upto(3).map do |idx|
        send("q#{idx}")
      end.inject(:+)
    end
  end

  def setup
    @b = MyBuilder.new
  end

  def teardown
#     @b.computable_display_dot
  end

  def diff_time
    st = Time.now
    res = yield
    [Time.now - st, res]
  end

  def test_full_parallel
    Computable.computable_max_threads = nil
    @b.i1, @b.i2 = 2, 3
    dt, res = diff_time{ @b.o }
    assert_in_delta 0.8, dt, 0.05
    assert_equal 20, res

    @b.i1, @b.i2 = 4, 5
    dt, res = diff_time{ @b.o }
    assert_in_delta 0.2, dt, 0.05
    assert_equal 36, res
  end

  def test_2_threads
    Computable.computable_max_threads = 2
    @b.i1, @b.i2 = 2, 3
    dt, res = diff_time{ @b.o }
    assert_in_delta 0.8, dt, 0.05
    assert_equal 20, res

    @b.i1, @b.i2 = 4, 5
    dt, res = diff_time{ @b.o }
    assert_in_delta 0.4, dt, 0.05
    assert_equal 36, res
  end
end
