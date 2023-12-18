class User < ActiveRecord::Base
  validates :name, presence: true

  has_one_attached :avatar
  has_one_attached :cover_photo, dependent: false, service: :local
  has_one_attached :avatar_with_variants do |attachable|
    attachable.variant :thumb, resize_to_limit: [100, 100]
  end
  has_one_attached :avatar_with_preprocessed do |attachable|
    attachable.variant :bool, resize_to_limit: [1, 1], preprocessed: true
  end
  has_one_attached :avatar_with_conditional_preprocessed do |attachable|
    attachable.variant :proc, resize_to_limit: [2, 2],
      preprocessed: ->(user) { user.name == "transform via proc" }
    attachable.variant :method, resize_to_limit: [3, 3],
      preprocessed: :should_preprocessed?
  end
  has_one_attached :intro_video
  has_one_attached :name_pronunciation_audio

  has_many_attached :highlights
  has_many_attached :vlogs, dependent: false, service: :local
  has_many_attached :highlights_with_variants do |attachable|
    attachable.variant :thumb, resize_to_limit: [100, 100]
  end
  has_many_attached :highlights_with_preprocessed do |attachable|
    attachable.variant :bool, resize_to_limit: [1, 1], preprocessed: true
  end
  has_many_attached :highlights_with_conditional_preprocessed do |attachable|
    attachable.variant :proc, resize_to_limit: [2, 2],
      preprocessed: ->(user) { user.name == "transform via proc" }
    attachable.variant :method, resize_to_limit: [3, 3],
      preprocessed: :should_preprocessed?
  end

  accepts_nested_attributes_for :highlights_attachments, allow_destroy: true

  def should_preprocessed?
    name == "transform via method"
  end
end
