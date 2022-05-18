require_relative 'helper'

class TestBacktrace < Minitest::Test
  class MyBuilder < Computable
    calc_value :a do
      b
    end

    calc_value :b do
      raise "my error"
    end
  end

  def setup
    @b = MyBuilder.new
  end

  def teardown
#     @b.computable_display_dot
  end

  def test_backtrace_decoration
    err = assert_raises(StandardError){ @b.a }
    bt = err.backtrace.join("\n")
    assert_match(/my error/, err.to_s)
    assert_match(/test_backtrace.rb:10:.* #b$/, bt)
    assert_match(/test_backtrace.rb:6:.* #a$/, bt)
  end
end

class TestBacktraceParallel < TestBacktrace
  include Helper::EnableParallel
end
