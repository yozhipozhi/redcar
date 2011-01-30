module Redcar
  class ApplicationSWT
    # Utility class for applying hints to SWT user interface objects, taking simple values (e.g.
    # color names) and mapping them to the appropriate SWT object needed to configure the UI.
    class UIHints
      # Type transforms to map hint values to the appropriate types.
      HINT_TRANSFORMS = {
        :background => :make_color,
        :foreground => :make_color,
      }

      # Applies UI hints to the given widget.
      #
      # The hints should be either a hash of hint symbols and values, or item that returns such a
      # hash with a ui_hints method.
      #
      # If the hint name has an entry in the HINT_TRANSFORMS table, the hint value is transformed
      # using the appropriate function.
      #
      # The final hint value is applied to the widget by prepending 'set_' to the method name, e.g.
      # the hint :foreground is set using widget.set_foreground().
      def self.apply_hints_to_widget(widget, item_or_hints)
        ui_hints = item_or_hints.respond_to? :ui_hints : item_or_hints.ui_hints : item_or_hints
        ui_hints.each do |name, val|
          # Transform the hint value to the appropriate type.
          transform_sym = HINT_TRANSFORMS[name]
          transform = UIHints.method(transform_sym) if transform_sym
          val = transform.call(val) if transform

          # Retrieve and call the setter method.
          setter_name = "set_#{name.to_s}"
          setter = widget.method(setter_name)
          if setter
            setter.call(val)
          else
            puts "WARNING - Invalid method #{setter_name} on widget #{widget}."
          end
        end
      end  # self.apply_to_widget()

      # Makes a SWT Color instance from the given value, either a hex string, RGB tuple, or simple
      # name of a SWT system color, e.g. 'RED' and 'red' are mapped to SWT::COLOR_RED.
      def self.make_color(val)
        puts "Color value: #{val}"
        case val
        when /^\#([\dA-Fa-f]{2})([\dA-Fa-f]{2})([\dA-Fa-f]{2})$/  # HTML hex
          Swt::Graphics::Color.new(Swt.display, $1.hex, $2.hex, $3.hex)
        when /^\(?(\d+),\s*(\d+),\s*(\d+)\)?/
          Swt::Graphics::Color.new(Swt.display, $1.to_i, $2.to_i, $3.to_i)
        else
          sys_color = Swt::SWT.const_get("COLOR_#{val.upcase}")
          Swt.display.get_system_color(sys_color)
        end
      end  # self.make_color()
    end  # class UIHints
  end  # class ApplicationSWT
end  # module Redcar