# frozen_string_literal: true

module OkrProgressEntries
  class Form < ApplicationForm
    form do |f|
      f.group(layout: :horizontal) do |values|
        values.text_field(
          name: :value,
          label: OkrProgressEntry.human_attribute_name(:value),
          required: true,
          input_width: :small
        )
        values.single_date_picker(
          name: :recorded_on,
          label: OkrProgressEntry.human_attribute_name(:recorded_on),
          value: model.recorded_on&.iso8601 || Date.current.iso8601,
          leading_visual: { icon: :calendar }
        )
      end

      f.text_area(name: :note, label: OkrProgressEntry.human_attribute_name(:note), input_width: :large)

      f.submit(name: :submit, label: I18n.t("okr.label_new_progress"), scheme: :primary)
    end
  end
end
