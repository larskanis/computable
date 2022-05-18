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
    attr_accessor :name, :calc_method, :used_for, :expired_from, :value, :value_calced, :count, :in_process, :recalc_error

    def initialize(name, calc_method, comp, mutex)
      @name = name
      @calc_method = calc_method
      @comp = comp
      @mutex = mutex
      @used_for = {}
      @expired_from = {}
      @count = 0
      @value = Unknown
      @in_process = false
      @recalc_error = nil
    end

    def inspect
      has = @recalc_error ? "error!" : "value:#{Unknown!=value}"
      "<Variable #{name} used_for:#{used_for.keys} expired_from:#{expired_from.keys} has #{has} value_calced:#{value_calced.inspect}>"
    end

    def calc!
      self.count += 1
      self.value_calced = true
      @mutex.unlock
      begin
        calc_method.call(self)
      ensure
        @mutex.lock
      end
    end

    def expire_value
      return if used_for.empty?

      puts "expire #{inspect}" if @comp.computable_debug
      used_for.each do |name2, v2|
        if v2.value_calced && !v2.expired_from[name]
          v2.expire_value
          v2.expired_from[name] = self
        end
      end
    end

    def revoke_expire
      return if used_for.empty?

      puts "revoke expire #{inspect}" if @comp.computable_debug
      used_for.each do |name2, v2|
        if v2.value_calced && v2.expired_from.delete(name) && v2.expired_from.empty?
          v2.revoke_expire
        end
      end
    end

    def process_recalced_value(recalced_value, err)
      if err
        self.recalc_error = err
        self.value = Unknown
        used_for.clear
      elsif self.value == recalced_value
        revoke_expire
      else
        self.recalc_error = nil
        self.value = recalced_value
        used_for.clear
      end
      expired_from.clear
    end

    def recalc_value
      return if !value_calced || expired_from.empty?

      puts "recalc #{inspect}" if @comp.computable_debug
      expired_from.each do |name2, v2|
        v2.recalc_value
      end

      unless expired_from.empty?
        begin
          recalced_value = self.calc!
        rescue Exception => err
        end
        process_recalced_value(recalced_value, err)
      end
    end

    def new_worker(from_workers, to_workers)
      Thread.new do
        while v = to_workers.pop
          puts "recalc parallel #{v.inspect}" if @comp.computable_debug
          err = nil
          begin
            recalced_value = v.calc_method.call(v)
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

          puts "recalc join" if @comp.computable_debug
          @mutex.unlock
          begin
            node, recalced_value, err = from_workers.pop
          ensure
            @mutex.lock
          end
          node.in_process = false
          num_working -= 1

          if err
            # Add the backtrace of the caller to the small in-thread backtrace for better debugging
            err.set_backtrace(err.backtrace + caller)
          end

          node.process_recalced_value(recalced_value, err)
        else
          #
          # not maxed out and found a node -- compute it
          #
          if (max_threads && workers.size < max_threads) ||
             (!max_threads && num_working == workers.size)
            workers << new_worker(from_workers, to_workers)
          end
          node.in_process = true
          node.count += 1
          node.value_calced = true
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

      max_threads = @comp.computable_max_threads
      if !max_threads || max_threads > 0
        recalc_parallel(max_threads)
      else
        recalc_value
      end

      raise recalc_error if recalc_error
      self.value = calc! if Unknown==value
      self.value
    end
  end

  def computable_debug=(v)
    @computable_debug = v
  end
  def computable_debug
    @computable_debug
  end

  def computable_max_threads=(v)
    @computable_max_threads = v
  end
  def computable_max_threads
    @computable_max_threads
  end

  def computable_display_dot(**kwargs)
    IO.popen("dot -Tpng | display -", "w") do |fd|
      fd.puts computable_to_dot(**kwargs)
    end
  end

  def computable_to_dot(rankdir: "TB", multiline: true)
    dot = "digraph #{self.class.name.inspect} {\n"
    dot << "graph [ dpi = 45, rankdir=#{rankdir} ];\n"
    @computable_variables.each do |name, v|
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
    @computable_debug = false
    @computable_max_threads = 0
    @computable_variables = {}
    @computable_caller = nil
    @computable_mutex = Mutex.new
  end


  def self.verify_format(name, value, format)
    if format && !(Unknown==value) && !(format === value)
      raise InvalidFormat, "variable '#{name}': value #{value.inspect} is not in format #{format.inspect}"
    end
  end

  private def improve_backtrace(err, block, text)
    fpath, lineno = block.source_location
    bt = err.backtrace
    myloc = err.backtrace_locations.select.with_index{|loc, i| loc.path == fpath && loc.lineno >= lineno && !bt[i].include?("#") }.min{|a,b| a.lineno <=> b.lineno }
    idx = err.backtrace_locations.index(myloc)
    bt[idx] += " ##{text}"
    raise err
  end

  def self.calc_value name, format=nil, freeze: true, &block
    calc_method_id = "calc_#{name}".intern
    define_method(calc_method_id) do
      instance_eval(&block)
    rescue Exception => err
      improve_backtrace(err, block, name)
    end

    calc_method2_id = "calc_#{name}_with_tracking".intern
    define_method(calc_method2_id) do |v|
      old_caller = Thread.current.thread_variable_get("Computable #{object_id}")
      Thread.current.thread_variable_set("Computable #{self.object_id}", v)
      begin
        puts "do calc #{v.inspect}" if @computable_debug
        res = send(calc_method_id)
        Computable.verify_format(name, res, format)
        res.freeze if freeze
        res
      ensure
        Thread.current.thread_variable_set("Computable #{self.object_id}", old_caller)
      end
    end

    define_method("#{name}=") do |value|
      Computable.verify_format(name, value, format)
      @computable_mutex.synchronize do
        v = @computable_variables[name]
        puts "set #{name}: #{value.inspect} #{v.inspect}" if @computable_debug
        v = @computable_variables[name] = Variable.new(name, method(calc_method2_id), self, @computable_mutex) unless v

        value.freeze if freeze
        v.assign_value(value)
      end
    end

    define_method(name) do
      @computable_mutex.synchronize do
        v = @computable_variables[name]
        puts "called #{name} #{v.inspect}" if @computable_debug
        v = @computable_variables[name] = Variable.new(name, method(calc_method2_id), self, @computable_mutex) unless v

        kaller = Thread.current.thread_variable_get("Computable #{object_id}")
        v.query_value(kaller)
      end
    end
  end

  def self.input_value name, format=nil, **kwargs
    calc_value name, format, **kwargs do
      raise UndefinedValue, "input variable '#{name}' is not assigned"
    end
  end
end
