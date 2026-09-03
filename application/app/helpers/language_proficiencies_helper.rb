# frozen_string_literal: true

module LanguageProficienciesHelper
  # Styles: :code => "B2", :full => "B2 · Upper-intermediate", :label => "Upper-intermediate".
  def language_proficiency_label(level, style: :full)
    code = level.to_s.downcase
    label = LanguageProficiency::CEFR_LEVELS[code]
    return if label.blank?

    case style.to_sym
    when :code then code.upcase
    when :label then label
    when :full then "#{code.upcase} · #{label}"
    else
      raise ArgumentError, "Unknown language proficiency style: #{style}"
    end
  end

  def language_proficiency_badge(level, style: :full, **options)
    content_tag(:span, language_proficiency_label(level, style:), { class: "language-proficiency-badge" }.merge(options))
  end
end
