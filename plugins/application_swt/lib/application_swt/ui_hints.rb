module Redcar
  class ApplicationSWT
    # Utility class for applying hints to SWT user interface objects, taking simple values (e.g.
    # color names) and mapping them to the appropriate SWT object needed to configure the UI.
    class UIHints
      # Type transforms to map hint values to the appropriate types.
      HINT_TRANSFORMS = {
        :alignment   => :make_swt_constant_bits,
        :background  => :make_color,
        :font        => :make_font,
        :foreground  => :make_color,
        :layout      => :make_layout,
        :layout_data => :make_layout_data,
        :style       => :make_swt_constant_bits,
      }


      ### UTILITIES ###

      # Safe accessor to retrieve UI hints from the given item.
      def self.get_item_hints(item)
        if item.respond_to? :ui_hints
          item.ui_hints
        else
          nil
        end
      end  # self.get_item_hints()

      # Returns the appropriate (transformed) value for the named UI hint, to be set on the target.
      def self.get_hint_value(target, name, value)
        UIHints.get_transformed_value(target, name, value, HINT_TRANSFORMS)
      end  # self.get_hint_value()

      # Returns the appropriate value for the named parameter, using transforms in the given table,
      # to be set on the target.
      def self.get_transformed_value(target, name, value, transforms)
        transform_sym = transforms[name]
        transform = UIHints.method(transform_sym) if transform_sym
        value = transform.call(target, value) if transform
        value
      end  # self.get_transformed_value()


      ### HINT APPLICATION ###

      # Applies UI hints to the given widget.
      #
      # The hints should be either a hash of hint symbols and values, or item that returns such a
      # hash with a ui_hints method.
      #
      # If the hint name has an entry in the HINT_TRANSFORMS table, the hint value is transformed
      # using the appropriate function.
      #
      # The final hint value is applied to the widget by prepending 'set_' to the method name, e.g.
      # the hint :foreground is set using widget.set_foreground() -- as a backup, a 'name=' method
      # is also tried.
      def self.apply_hints(target, item_or_hints)
        ui_hints = UIHints.get_item_hints(item_or_hints) || item_or_hints
        return unless ui_hints
        UIHints.apply_params_with_transforms(target, ui_hints, HINT_TRANSFORMS)
      end  # self.apply_hints()

      # Applies the set of parameters to the target object, mapping the values using the given
      # transforms table.
      def self.apply_params_with_transforms(target, params, transforms)
        params.each do |name, value|
          #puts "param: #{name} => #{value}"
          # Transform the value to the appropriate type.
          value = UIHints.get_transformed_value(target, name, value, transforms)

          # Retrieve and call the setter method.
          setter_name = "set_#{name}"
          setter_name = "#{name.to_s}=" unless target.respond_to? setter_name
          #puts "target: #{target}  setter: #{setter_name}  value: #{value}"
          setter = target.method(setter_name)
          if setter
            setter.call(value)
          else
            puts "WARNING - Invalid method #{setter_name} on target #{target}."
          end
        end
      end  # self.apply_params_with_transforms()


      ### TRANSFORMS ###

      # Makes a SWT Color instance from the given value, either a hex string, RGB tuple, or simple
      # name of a SWT system color, e.g. 'RED' and 'red' are mapped to SWT::COLOR_RED.
      def self.make_color(target, val)
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

      # Obtains the values of the named constant on the target class.
      def self.make_class_constant(target, cname)
        target.class.const_get(cname.strip.upcase)
      end  # self.make_class_constant()

      # Given a delimited string or list of constant names that are defined on the target class,
      # maps them to their integer values and ORs them together.
      def self.make_class_constant_bits(target, cnames)
        cname_list = (cnames.is_a? Array) ? cnames : cnames.strip.split(/\s*[\s,\|]\s*/)
        constant = 0
        cname_list.each {|c| constant |= target.class.const_get(c.strip.upcase) }
        constant
      end  # self.make_class_constant_bits()

      # Obtains the value of the named Swt::SWT constant.
      def self.make_swt_constant(target, cname)
        Swt::SWT.const_get(cname.strip.upcase)
      end  # self.make_swt_constant()

      # Given a delimited string or list of Swt::SWT constant names, maps them to their integer
      # values and ORs them together.
      def self.make_swt_constant_bits(target, cnames)
        cname_list = (cnames.is_a? Array) ? cnames : cnames.strip.split(/\s*[\s,\|]\s*/)
        constant = 0
        cname_list.each {|c| constant |= Swt::SWT.const_get(c.strip.upcase) }
        constant
      end  # self.make_swt_constant_bits()

      # Constructs a font object from a string of comma-delimited values:
      #   * A number N specifies an exact font height, while +N or -N is relative.
      #   * NORMAL clears out the font style; BOLD and ITALIC are added to the style.
      #   * Any other value specifies the font name.
      #
      # Unspecified settings use the default system font.
      #
      # Examples:
      #   * 'Arial, 18, BOLD' : Arial font, 18pt, bold
      #   * 'BOLD, 18, Arial' : Arial font, 18pt, bold
      #   * 'Courier, +2' : Courier font, +2 height, default style
      #   * '+4, BOLD, ITALIC : Default font, +4 height, bold and italic
      #   * 'NORMAL' : Default font and height; clears out any default style
      def self.make_font(target, val)
        default_font = Swt.display.get_system_font.get_font_data[0]
        name = default_font.name
        height = default_font.height
        style = default_font.style

        val.strip.split(/\s*,\s*/).each do |v|
          case v
          when /^[\+\-]\d+/
            height += v.to_i
          when /^\d+/
            height = v.to_i
          when /^(NORMAL|BOLD|ITALIC)/i
            styles = v.strip.split(/\s*\|\s*/)
            style_bits = styles.map {|s| Swt::SWT::const_get(s.upcase) }
            style_bits.each do |b|
              if b == Swt::SWT::NORMAL
                style = b
              else
                style |= b
              end
            end
          else
            name = v
          end
        end
        Swt::Graphics::Font.new(Swt.display, name, height, style)
      end  # self.make_font

      # Constructs a layout object.
      def self.make_layout(target, params)
        # TODO(yozhipozhi)
      end  # self.make_layout()

      GRID_DATA_TRANSFORMS = {
        :horizontalAlignment => :make_class_constant,
        :verticalAlignment => :make_class_constant,
      }

      # Constructs a layout data object.
      def self.make_layout_data(target, params)
        data_type = Swt::Layout::GridData
        if params[:type]
          data_type = params[:type]
          params = params.dup
          params.delete(:type)
        end

        data = data_type.new
        transforms = (data_type == Swt::Layout::GridData) ? GRID_DATA_TRANSFORMS : {}
        UIHints.apply_params_with_transforms(data, params, transforms)
        data
      end  # self.make_layout_data()

    end  # class UIHints
  end  # class ApplicationSWT
end  # module Redcar