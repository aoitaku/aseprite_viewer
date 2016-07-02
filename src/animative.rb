require_relative "animator"

module Animative

  extend Forwardable

  def_delegators :@__animative_animator,
    :animation_image, :animation_image=,
    :add_animation,
    :start_animation, :change_animation,
    :pause_animation, :resume_animation

  def initialize(*arg)
    super
    @__animative_animator = Animator.new
  end

  def update_animation
    self.image = @__animative_animator.update
  end

  def animator
     @__animative_animator
  end

  def animator=(animator)
     @__animative_animator = animator
  end

end
