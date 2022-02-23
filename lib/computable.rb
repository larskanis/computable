# -*- coding: UTF-8 -*-
require "computable/version"
require "thread"

class Computable
  class Error < RuntimeError; end
  class UndefinedValue < Error; end
  class InvalidFormat < Error; end
  class RecursionDetected < Error; end

  # This is a special value to mark a variable to be computed.
  Unknown = Object.new
  class << Unknown
    def inspect
      "<Computable::Unknown>"
    end
  end

  class Variable
    attr_accessor :name, :calc_method, :used_for, :expired_from, :value, :value_calced, :count, :in_process
    def initialize(name, calc_method)
      @name = name
      @calc_method = calc_method
      @used_for = {}
      @expired_from = {}
      @count = 0
      @value = Unknown
      @in_process = false
    end

    def inspect
      "<Variable #{name} used_for:#{used_for.keys} expired_from:#{expired_from.keys} has value:#{Unknown==value} value_calced:#{value_calced.inspect}>"
    end

    def calc!
      self.count += 1
      self.value_calced = true
      calc_method.call(self)
    end

    def expire_value
      return if used_for.empty?

      puts "expire #{inspect}" if Computable.computable_debug
      used_for.each do |name2, v2|
        if v2.value_calced && !v2.expired_from[name]
          v2.expire_value
          v2.expired_from[name] = self
        end
      end
    end

    def revoke_expire
      return if used_for.empty?

      puts "revoke expire #{inspect}" if Computable.computable_debug
      used_for.each do |name2, v2|
        if v2.value_calced && v2.expired_from.delete(name) && v2.expired_from.empty?
          v2.revoke_expire
        end
      end
    end

    def process_recalced_value(recalced_value)
      if self.value == recalced_value
        revoke_expire
      else
        self.value = recalced_value
        used_for.clear
      end
      expired_from.clear
    end

    def recalc_value
      return if !value_calced || expired_from.empty?

      puts "recalc #{inspect}" if Computable.computable_debug
      expired_from.each do |name2, v2|
        v2.recalc_value
      end

      unless expired_from.empty?
        recalced_value = self.calc!
        process_recalced_value(recalced_value)
      end
    end

    def new_worker(from_workers, to_workers)
      Thread.new do
        while v = to_workers.pop
          puts "recalc parallel #{v.inspect}" if Computable.computable_debug
          begin
            recalced_value = v.calc!
          rescue Exception => err
          end
          from_workers.push([v, recalced_value, err])
        end
      end
    end

    def recalc_parallel(max_threads)
      workers = []
      from_workers = Queue.new
      to_workers = Queue.new

      master_loop(max_threads, workers, from_workers, to_workers)

      to_workers.close
      workers.each { |t| t.join }
    end

    def master_loop(max_threads, workers, from_workers, to_workers)
      num_working = 0
      loop do
        if num_working == max_threads || !(node = find_recalcable)
          #
          # maxed out or no nodes available -- wait for results
          #
          return if num_working == 0

          node, recalced_value, err = from_workers.pop
          node.in_process = false
          num_working -= 1
          raise err if err

          node.process_recalced_value(recalced_value)
        else
          #
          # not maxed out and found a node -- compute it
          #
          if (max_threads && workers.size < max_threads) ||
             (!max_threads && num_working == workers.size)
            workers << new_worker(from_workers, to_workers)
          end
          node.in_process = true
          num_working += 1
          to_workers.push(node)
        end
      end
    end

    def find_recalcable
      if !value_calced || expired_from.empty? || in_process
        nil
      elsif expired_from.all?{ |_, v2| !v2.value_calced || v2.expired_from.empty? }
        self
      else
        expired_from.each do |_, v2|
          node = v2.find_recalcable and return node
        end
        nil
      end
    end

    def assign_value(value)
      unless self.value == value
        expire_value
        expired_from.clear
        used_for.clear
        self.value = value
      end
      self.value_calced = false
    end

    def query_value(kaller)
      if kaller
        v2 = used_for[kaller.name]
        if v2
          if Unknown==value && Unknown==v2.value && value_calced && v2.value_calced
            raise RecursionDetected, "#{v2.name} depends on #{name}, but #{name} could not be computed without #{v2.name}"
          end
        else
          used_for[kaller.name] = kaller
        end
      end

      max_threads = Computable.computable_max_threads
      if !max_threads || max_threads > 0
        recalc_parallel(max_threads)
      else
        recalc_value
      end

      self.value = calc! if Unknown==value
      self.value
    end
  end

  @@debug = false
  def self.computable_debug=(v)
    @@debug = v
  end
  def self.computable_debug
    @@debug
  end

  @@max_threads = nil
  def self.computable_max_threads=(v)
    @@max_threads = v
  end
  def self.computable_max_threads
    @@max_threads
  end

  def computable_display_dot(**kwargs)
    IO.popen("dot -Tpng | display -", "w") do |fd|
      fd.puts computable_to_dot(**kwargs)
    end
  end

  def computable_to_dot(rankdir: "TB", multiline: true)
    dot = "digraph #{self.class.name.inspect} {\n"
    dot << "graph [ dpi = 45, rankdir=#{rankdir} ];\n"
    @variables.each do |name, v|
      col = case
        when !v.value_calced then "color = red,"
        when !v.used_for.empty? then "color = green,"
        else "color = blue,"
      end
      label = if multiline
        "#{name.to_s.gsub("_","\n")}\n(#{v.count})"
      else
        "#{name.to_s} (#{v.count})"
      end
      dot << "#{name.to_s.inspect} [#{col} label=#{label.inspect}];\n"
      v.used_for.each do |name2, v2|
        dot << "#{name.to_s.inspect} -> #{name2.to_s.inspect};\n"
      end
    end
    dot << "}\n"
  end

  def initialize
    @variables = {}
    @caller = nil
  end


  def self.verify_format(name, value, format)
    if format && !(Unknown==value) && !(format === value)
      raise InvalidFormat, "variable '#{name}': value #{value.inspect} is not in format #{format.inspect}"
    end
  end

  def self.calc_value name, format=nil, freeze: true, &block
    calc_method_id = "calc_#{name}".intern
    define_method(calc_method_id, &block)

    calc_method2_id = "calc_#{name}_with_tracking".intern
    define_method(calc_method2_id) do |v|
      begin
        @caller, old_caller = v, @caller
        begin
          puts "do calc #{v.inspect}" if @@debug
          res = send(calc_method_id)
          Computable.verify_format(name, res, format)
          res.freeze if freeze
          res
        ensure
          @caller = old_caller
        end
      end
    end

    define_method("#{name}=") do |value|
      Computable.verify_format(name, value, format)
      v = @variables[name]
      puts "set #{name}: #{value.inspect} #{v.inspect}" if @@debug
      v = @variables[name] = Variable.new(name, method(calc_method2_id)) unless v

      value.freeze if freeze
      v.assign_value(value)
    end

    define_method(name) do
      v = @variables[name]
      puts "called #{name} #{v.inspect}" if @@debug
      v = @variables[name] = Variable.new(name, method(calc_method2_id)) unless v

      v.query_value(@caller)
    end
  end

  def self.input_value name, format=nil, **kwargs
    calc_value name, format, **kwargs do
      raise UndefinedValue, "input variable '#{name}' is not assigned"
    end
  end
end
