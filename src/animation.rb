require 'fiber'
require 'forwardable'

class Animation

  extend Forwardable

  def_delegators :@fiber, :alive?

  def initialize(init_motion=Motion.new, init_offset=nil)
    @fiber = Fiber.new do |motion, offset=nil|
      reset, restart = nil, nil
      loop do
        catch :reset do
          motion, reset = reset, nil if reset
          motion.step do |count|
            catch :restart do
              offset, restart = restart, nil if restart
              offset = 0 if offset and offset >= motion.length
              if offset
                next unless offset == count
              end
              offset = nil
              params = Fiber.yield(motion.key(count), count)
              if params
                reset, restart = params
              end
              throw :reset if reset
              throw :restart if restart
            end
          end
        end
        break if motion.forward
      end
      Fiber.yield(motion.forward, nil)
    end
    @motion = init_motion
    @offset = init_offset
    @key = @motion.first
    @pause = false
    @count = 0
  end

  def start(motion)
    @offset = 0
    @motion = motion
  end

  def change(motion)
    @offset = @count.succ
    @motion = motion
  end

  def update
    unless pause?
      if @motion or @offset
        @key, @count = @fiber.resume(@motion, @offset)
        @motion, @offset = nil, nil
      else
        @key, @count = @fiber.resume
      end
    end
    @key
  end

  def pause
    @pause = true
  end

  def resume
    @pause = false
  end

  def pause?
    @pause
  end

  class Motion

    extend Forwardable

    attr_accessor :wait, :pattern, :forward

    def_delegators :@pattern, :first

    def initialize(wait=0, pattern=[0], forward=nil)
      @wait, @pattern, @forward = wait, pattern, forward
    end

    def step
      length.times {|count| yield count }
    end

    def length
      (1 + @wait) * @pattern.size
    end

    def key(count)
      @pattern[count / (1 + @wait)]
    end

  end

end
