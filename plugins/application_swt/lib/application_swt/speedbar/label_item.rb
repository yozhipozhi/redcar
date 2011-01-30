module Redcar
  class ApplicationSWT
    class Speedbar
      class LabelItem
        def initialize(speedbar, composite, item)
          # Support style in the UI hints.
          ui_hints = UIHints.get_item_hints(item)
          style = 0
          if ui_hints && (ui_hints.has_key? :style)
            style = UIHints.get_hint_value(nil, :style, ui_hints[:style])
            ui_hints = ui_hints.dup
            ui_hints.delete(:style)
          end

          # Construct the label.
          label = Swt::Widgets::Label.new(composite, style)
          label.set_text(item.text)
          item.add_listener(:changed_text) do |new_text|
            label.set_text(item.text)
          end
          UIHints.apply_hints(label, ui_hints)
        end
      end
    end
  end
end
