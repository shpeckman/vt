# src/vt/dsl.cr
# Provides macros for declarative routing of ANSI sequences based on their
# final character and intermediates.
module VT::DSL
  # Matches a CSI dispatch event by evaluating the final `char` and optional
  # `intermediates`. If they match, the block is executed.
  macro on_csi(chars, intermediates = nil, &block)
    if {% if chars.is_a?(ArrayLiteral) || chars.is_a?(TupleLiteral) %}{% for c, i in chars %}char == {{c}}.ord{% if i < chars.size - 1 %} || {% end %}{% end %}{% else %}char == {{chars}}.ord{% end %}
      {% if intermediates %}
        {% if intermediates.is_a?(ArrayLiteral) || intermediates.is_a?(TupleLiteral) %}
          if intermediates.size == {{intermediates.size}} && {% for c, i in intermediates %}intermediates[{{i}}] == {{c}}.ord.to_u8 && {% end %}true
            {{yield}}
          end
        {% else %}
          if intermediates.size == 1 && intermediates[0] == {{intermediates}}.ord.to_u8
            {{yield}}
          end
        {% end %}
      {% else %}
        if intermediates.empty?
          {{yield}}
        end
      {% end %}
    end
  end

  # Matches a DCS hook event by evaluating the final `char` and optional
  # `intermediates`. If they match, the block is executed.
  macro on_dcs(chars, intermediates = nil, &block)
    if {% if chars.is_a?(ArrayLiteral) || chars.is_a?(TupleLiteral) %}{% for c, i in chars %}char == {{c}}.ord{% if i < chars.size - 1 %} || {% end %}{% end %}{% else %}char == {{chars}}.ord{% end %}
      {% if intermediates %}
        {% if intermediates.is_a?(ArrayLiteral) || intermediates.is_a?(TupleLiteral) %}
          if intermediates.size == {{intermediates.size}} && {% for c, i in intermediates %}intermediates[{{i}}] == {{c}}.ord.to_u8 && {% end %}true
            {{yield}}
          end
        {% else %}
          if intermediates.size == 1 && intermediates[0] == {{intermediates}}.ord.to_u8
            {{yield}}
          end
        {% end %}
      {% else %}
        if intermediates.empty?
          {{yield}}
        end
      {% end %}
    end
  end
end
