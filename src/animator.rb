require_relative "animation"

class Animator

  extend Forwardable

  attr_accessor :animation_image

  def_delegator :@animation, :pause, :pause_animation
  def_delegator :@animation, :resume, :resume_animation

  def initialize
    @motions = {}
    @animation = Animation.new
    @animation_image = []
  end

  def add_animation(key, wait, pattern, forward=nil)
    @motions[key] = Animation::Motion.new(wait, pattern, forward)
  end

  def start_animation(key, pattern=nil, forward=nil)
    if @motions[key]
      @animation.start(@motions[key])
    else
      @animation.start(Animation::Motion.new(key, pattern, forward))
    end
  end

  def change_animation(key, pattern=nil, forward=nil)
    if @motions[key]
      @animation.change(@motions[key])
    else
      @animation.change(Animation::Motion.new(key, pattern, forward))
    end
  end

  def update
    @animation_image[@animation.update]
  end

end
