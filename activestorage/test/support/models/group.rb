# frozen_string_literal: true

class Group < ActiveRecord::Base
  has_one_attached :avatar
  has_many :users, autosave: true

  accepts_nested_attributes_for :users
end
