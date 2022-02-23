require 'minitest/autorun'
require 'computable'

module Helper
  module EnableParallel
    def setup
      super
      @b.computable_max_threads = 100
    end

    def teardown
      @b.computable_max_threads = 0
      super
    end
  end
end
