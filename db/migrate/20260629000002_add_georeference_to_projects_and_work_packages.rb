# frozen_string_literal: true

class AddGeoreferenceToProjectsAndWorkPackages < ActiveRecord::Migration[8.0]
  def change
    add_column :projects, :latitude, :decimal, precision: 10, scale: 7
    add_column :projects, :longitude, :decimal, precision: 10, scale: 7
    add_column :work_packages, :latitude, :decimal, precision: 10, scale: 7
    add_column :work_packages, :longitude, :decimal, precision: 10, scale: 7
  end
end
