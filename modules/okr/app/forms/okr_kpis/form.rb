# frozen_string_literal: true

module OkrKpis
  class Form < ApplicationForm
    form do |f|
      f.text_field(name: :name, label: OkrKpi.human_attribute_name(:name), required: true)

      f.text_area(name: :description, label: OkrKpi.human_attribute_name(:description), input_width: :large)

      f.group(layout: :horizontal) do |configuration|
        configuration.select_list(
          name: :update_frequency,
          label: OkrKpi.human_attribute_name(:update_frequency),
          required: true
        ) do |list|
          OkrKpi.update_frequencies.each_key do |frequency|
            list.option(
              label: I18n.t("okr.update_frequency.#{frequency}"),
              value: frequency,
              selected: model.update_frequency == frequency
            )
          end
        end

        configuration.text_field(name: :unit, label: OkrKpi.human_attribute_name(:unit), input_width: :small)
      end

      f.group(layout: :horizontal) do |values|
        values.text_field(
          name: :baseline_value,
          label: OkrKpi.human_attribute_name(:baseline_value),
          required: true,
          input_width: :small
        )
        values.text_field(
          name: :current_value,
          label: OkrKpi.human_attribute_name(:current_value),
          input_width: :small
        )
        values.text_field(
          name: :target_value,
          label: OkrKpi.human_attribute_name(:target_value),
          required: true,
          input_width: :small
        )
      end

      f.select_list(
        name: :target_direction,
        label: OkrKpi.human_attribute_name(:target_direction),
        required: true
      ) do |list|
        OkrKpi.target_directions.each_key do |direction|
          list.option(
            label: I18n.t("okr.target.#{direction}"),
            value: direction,
            selected: model.target_direction == direction
          )
        end
      end

      f.submit(name: :submit, label: submit_label, scheme: :primary)
    end

    private

    def submit_label
      model.persisted? ? I18n.t(:button_save) : I18n.t(:button_create)
    end
  end
end
