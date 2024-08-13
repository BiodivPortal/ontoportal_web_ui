# frozen_string_literal: true
require 'iso-639'

class LanguageFieldComponent < ViewComponent::Base

  include FlagIconsRails::Rails::ViewHelpers

  def initialize(value:, label: nil, auto_label: false, icon: nil)
    super
    @value = value
    @lang_code = nil
    @label = label
    @icon = icon

    iso = ISO_639.find(value.to_s.split('/').last)
    if iso
      @lang_code = iso.alpha2
      @label ||= iso.english_name if auto_label
    end
  end

  def lang_code
    case @lang_code
    when 'en'
      @lang_code = 'gb'
    when 'ar'
      @lang_code = 'sa'
    when 'hi'
      @lang_code = 'in'
    when 'ur'
      @lang_code =  'pk'
    when 'zh'
      @lang_code =  'cn'
    when 'ja'
      @lang_code = 'jp'
    end
    @lang_code
  end

  def value
    @value&.is_a?(String) ? @value.to_s.split('/').last : 'NO-LANG'
  end
end
