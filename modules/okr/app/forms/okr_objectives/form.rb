# frozen_string_literal: true

module OkrObjectives
  class Form < ApplicationForm
    form do |f|
      f.text_field(
        name: :title,
        label: OkrObjective.human_attribute_name(:title),
        required: true
      )

      f.text_area(
        name: :description,
        label: OkrObjective.human_attribute_name(:description),
        input_width: :large
      )

      f.group(layout: :horizontal) do |dates|
        dates.single_date_picker(
          name: :start_date,
          label: OkrObjective.human_attribute_name(:start_date),
          value: model.start_date&.iso8601,
          leading_visual: { icon: :calendar }
        )
        dates.single_date_picker(
          name: :target_date,
          label: OkrObjective.human_attribute_name(:target_date),
          value: model.target_date&.iso8601,
          leading_visual: { icon: :calendar }
        )
      end

      f.submit(name: :submit, label: submit_label, scheme: :primary)
    end

    private

    def submit_label
      model.persisted? ? I18n.t(:button_save) : I18n.t(:button_create)
    end
  end
end
