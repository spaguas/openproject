# frozen_string_literal: true

class CreateBrandingSettings < ActiveRecord::Migration[8.0]
  def change
    create_table :branding_settings do |t|
      t.string :light_logo
      t.string :dark_logo

      t.timestamps
    end
  end
end
