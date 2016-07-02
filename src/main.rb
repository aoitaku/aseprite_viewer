require 'dxruby'
require 'dxruby_sprite_ui'
require 'json'

require_relative 'animative'

module DXRuby::SpriteUI

  class Mouse < Sprite

    def update(scale_x=1,scale_y=1)
      self.x = Input.mouse_x / scale_x
      self.y = Input.mouse_y / scale_y
    end

  end

  class MouseEventDispatcher

    def update(scale_x=1,scale_y=1)
      mouse_prev.x = mouse.x
      mouse_prev.y = mouse.y
      mouse.update(scale_x,scale_y)
    end

  end
end

class AnimeSprite < Sprite

  include Animative

  def update
    super
    update_animation
  end

end

class Application

  attr_accessor :ui, :event, :render_target, :sprite, :animations, :animation_index, :filepath, :zoomrate, :preview

  def initialize(ui, config)
    @render_target = RenderTarget.new(320, 240)
    @zoomrate = 2
    @ui = ui[self]
    @ui.find(:reload).disable
    @ui.find(:previous).disable
    @ui.find(:play).disable
    @ui.find(:forward).disable
    @ui.target = render_target
    @ui.all_components.each {|component| component.target = @ui.target }
    @ui.layout
    @event = SpriteUI::MouseEventDispatcher.new(@ui)
    @config = config
  end

  def update
    event.update(2, 2)
    event.dispatch
    sprite.update if sprite
    ui.draw
    sprite.draw if sprite
    Window.draw_scale(
      (Window.width - render_target.width) / 2 ,
      (Window.height - render_target.height) / 2,
      render_target, 2, 2)
    if preview
      sprite_viewer = ui.find(:sprite_viewer)
      Window.draw_scale(
        sprite_viewer.x * 2 + (sprite_viewer.width * 2 - preview.width) / 2,
        sprite_viewer.y * 2 + (sprite_viewer.height * 2 - preview.height) / 2,
        preview, zoomrate, zoomrate)
    end
  end

  def load
    puts "load"
    @ui.find(:reload).disable
    @ui.find(:previous).disable
    @ui.find(:play).disable
    @ui.find(:forward).disable
    @filepath = Window.open_filename([["Aseprite ファイル(*.ase)","*.ase"]], "読み込むファイルを選んでください")
    return unless filepath
    load_file filepath
  end

  def load_file(filepath)
    Dir.mkdir(__APP_ROOT__ + ?\\ + "sandbox") unless Dir.exist?(__APP_ROOT__ + ?\\ + "sandbox")
    filename = __APP_ROOT__ + ?/ + "sandbox" + ?/ + File.basename(filepath, '.ase')
    `"#{@config[:aseprite]}" -b --list-tags "#{filepath}" --sheet #{filename}.png --sheet-width 72 --data #{filename}.json`
    json = filename + ".json"
    data = JSON.parse(File.read(json), symbolize_names: true)
    first = data[:frames].values.first
    meta = data[:meta]
    sprite_sheet = meta[:image]
    return unless File.exist?(sprite_sheet)
    w, h = meta[:size][:w] / first[:sourceSize][:w], meta[:size][:h] / first[:sourceSize][:h]
    @sprite = AnimeSprite.new(0, 0)
    @sprite.animation_image = Image.load_tiles(sprite_sheet, w, h)
    meta[:frameTags].each do |frame|
      case frame[:direction]
      when 'forward'
        @sprite.add_animation(frame[:name].to_sym, 6, [*frame[:from].to_i..frame[:to].to_i])
      when 'pingpong'
        @sprite.add_animation(frame[:name].to_sym, 6, [
          *frame[:from].to_i...frame[:to].to_i,
          *((frame[:from].to_i + 1)..frame[:to].to_i).to_a.reverse
        ])
      end
    end
    @preview = RenderTarget.new(first[:sourceSize][:w], first[:sourceSize][:h])
    @sprite.target = @preview
    @sprite.image = @sprite.animation_image.first
    @animations = meta[:frameTags].map {|frame| frame[:name].to_sym}
    @animation_index = 0
    ui.find(:previous).enable
    ui.find(:play).enable
    ui.find(:forward).enable
    ui.find(:reload).enable
    ui.find(:sprite_name).text = File.basename(filepath).upcase
    ui.find(:animation_name).text = animations[animation_index].to_s.upcase.gsub(/_/, ?\s)
    ui.layout
  end

  def reload
    puts "reload"
    load_file filepath
  end

  def previous
    @animation_index = animations.size if animation_index == 0
    @animation_index -= 1
    ui.find(:animation_name).text = animations[animation_index].to_s.upcase.gsub(/_/, ?\s)
    ui.layout
    puts animations[animation_index]
    sprite.start_animation animations[animation_index]
  end

  def play
    puts animations[animation_index]
    sprite.start_animation animations[animation_index]
  end

  def forward
    @animation_index += 1
    @animation_index = 0 if animation_index == animations.size
    ui.find(:animation_name).text = animations[animation_index].to_s.upcase.gsub(/_/, ?\s)
    ui.layout
    puts animations[animation_index]
    sprite.start_animation animations[animation_index]
  end

  def zoomin
    ui.find(:zoomout).enable if ui.find(:zoomout).disable?
    @zoomrate *= 2
    ui.find(:zoomrate).text = "*#{zoomrate}.0"
    ui.layout
    if zoomrate == 8
      ui.find(:zoomin).disable
    end
  end

  def zoomout
    ui.find(:zoomin).enable if ui.find(:zoomin).disable?
    @zoomrate /= 2
    ui.find(:zoomrate).text = "*#{zoomrate}.0"
    ui.layout
    if zoomrate == 1
      ui.find(:zoomout).disable
    end
  end

end

Window.caption = "スプライトビューアー"
Window.mag_filter = TEXF_POINT
Font.install("#{__APP_ROOT__}/assets/fonts/04b11.ttf")
Font.default = Font.new(8, "04b11")
SpriteUI.equip :MouseEventHandler

ui = -> app do
  SpriteUI.build {
    width 320
    height 240
    HBox {
      width :full
      height :full
      ContainerBox {
        width 0.7
        height :full
        VBox {
          border width: 1, color: 0xffffff
          width :full
          height :full
          margin [2, 1, 2, 2]
          TextLabel(:sprite_name) {
            width :full
            height 0.1
            margin 0
            text "---"
            text_align :center
            align_items :center
          }
          HBox {
            width :full
            height 0.1
            align_items :center
            justify_content :center
            TextButton(:zoomin) {
              margin [2, 8]
              text "+"
              onclick -> _ {
                return if _.disable?
                app.zoomin
              }
              line_height 12
            }
            TextLabel(:zoomrate) {
              width 0.1
              text_align :center
              margin [2, 8]
              text "*#{app.zoomrate}.0"
              line_height 12
            }
            TextButton(:zoomout) {
              margin [2, 8]
              text "-"
              onclick -> _ {
                return if _.disable?
                app.zoomout
              }
              line_height 12
            }
          }
          ContainerBox(:sprite_viewer) {
            width :full
            height 0.6
          }
          TextLabel(:animation_name) {
            width :full
            height 0.1
            margin 0
            text "---"
            text_align :center
            align_items :center
          }
          HBox {
            width :full
            height 0.1
            align_items :center
            justify_content :space_between
            TextButton(:previous) {
              margin [2, 8]
              text "<< PREV"
              onclick -> _ {
                return if _.disable?
                app.previous
              }
              line_height 12
            }
            TextButton(:play) {
              margin [2, 8]
              text "PLAY"
              onclick -> _ {
                return if _.disable?
                app.play
              }
              line_height 12
            }
            TextButton(:forward) {
              margin [2, 8]
              text "NEXT >>"
              onclick -> _ {
                return if _.disable?
                app.forward
              }
              line_height 12
            }
          }
        }
      }
      ContainerBox {
        width 0.3
        height :full
        VBox {
          border width: 1, color: 0xffffff
          width :full
          height :full
          margin [2, 2, 2, 1]
          TextLabel {
            margin [4, 8, 2]
            text "MENU\n-----------"
          }
          TextButton(:reload) {
            margin [2, 8]
            text "+ RELOAD"
            onclick -> _ {
              return if _.disable?
              app.reload
            }
            line_height 12
          }
          TextButton(:load) {
            margin [2, 8]
            text "+ LOAD"
            onclick -> * {
              app.load
            }
            line_height 12
          }
        }
      }
    }
  }
end

config_file = __APP_ROOT__ + ?\\ + "config.json"
config = {}
aseprite = nil
if File.exist?(config_file)
  config = JSON.parse(File.read(config_file), symbolize_names: true)
  aseprite = config[:aseprite]
end
aseprite ||= Window.open_filename([["Aseprite 実行ファイル(*.exe)","aseprite.exe"]], "Aseprite の場所を指定してください")
version = `"#{aseprite}" --version`
puts version
unless config[:aseprite]
  config[:aseprite] = aseprite
  File.write(config_file, JSON.dump(config))
end

application = Application.new(ui, config)

Window.loop do
  application.update
end
