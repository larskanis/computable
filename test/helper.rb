require 'minitest/autorun'
require 'computable'

module Helper
  module EnableParallel
    def setup
      Computable.computable_max_threads = 100
      super
    end

    def teardown
      super
      Computable.computable_max_threads = 0
    end
  end
end
