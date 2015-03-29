# -*- coding: UTF-8 -*-
require "computable/version"

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
    attr_accessor :name, :calc_method, :used_for, :expired_from, :value, :value_calced, :count
    def initialize(name, calc_method)
      @name = name
      @calc_method = calc_method
      @used_for = {}
      @expired_from = {}
      @count = 0
      @value = Unknown
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

    def recalc_value
      return if !value_calced || expired_from.empty?

      puts "recalc #{inspect}" if Computable.computable_debug
      expired_from.each do |name2, v2|
        v2.recalc_value
      end

      unless expired_from.empty?
        recalced_value = self.calc!
        if self.value == recalced_value
          revoke_expire
        else
          self.value = recalced_value
          used_for.clear
        end
        expired_from.clear
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

      recalc_value

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

  def computable_display_dot(params={})
    IO.popen("dot -Tpng | display -", "w") do |fd|
      fd.puts computable_to_dot(params)
    end
  end

  def computable_to_dot(params={})
    rankdir = params.delete(:rankdir){ "TB" }
    multiline = params.delete(:multiline){ true }
    raise ArgumentError, "invalid params #{params.inspect}" unless params.empty?

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

  def self.calc_value name, format=nil, params={}, &block
    freeze = params.delete(:freeze){ true }
    raise ArgumentError, "invalid params #{params.inspect}" unless params.empty?

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

  def self.input_value name, format=nil, params={}
    calc_value name, format, params do
      raise UndefinedValue, "input variable '#{name}' is not assigned"
    end
  end
end
