require_relative 'helper'

class TestBacktrace < Minitest::Test
  class MyBuilder < Computable
    calc_value :b do
      c
    end

    calc_value :c do
      raise "my error" if enable
      :x
    end

    calc_value :a do
      b
    end
    input_value :enable
  end

  def setup
    @b = MyBuilder.new
  end

  def teardown
#     @b.computable_display_dot
  end

  def test_backtrace_decoration
    @b.enable = true
    err = assert_raises(StandardError){ @b.b }
    bt = err.backtrace.join("\n")
    assert_match(/my error/, err.to_s)
    assert_match(/test_backtrace.rb:10:.* #c$/, bt)
    assert_match(/test_backtrace.rb:6:.* #b$/, bt)
  end

  def test_recalc_backtrace_decoration
    @b.enable = false
    @b.b
    @b.enable = true

    err = assert_raises(StandardError){ @b.b }
    bt = err.backtrace.join("\n")
    assert_match(/my error/, err.to_s)
    assert_match(/test_backtrace.rb:10:.* #c$/, bt)
    assert_match(/block in recalc_value' #b$/, bt) unless @b.computable_max_threads
  end

  def test_recalc_longer_backtrace_decoration
    @b.enable = false
    @b.a
    @b.enable = true

    err = assert_raises(StandardError){ @b.a }
    bt = err.backtrace.join("\n")
    assert_match(/my error/, err.to_s)
    assert_match(/test_backtrace.rb:10:.* #c$/, bt)
    assert_match(/block in recalc_value' #b.*block in recalc_value' #a$/m, bt) unless @b.computable_max_threads
  end
end

class TestBacktraceParallel < TestBacktrace
  include Helper::EnableParallel
end
