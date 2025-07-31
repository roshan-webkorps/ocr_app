class Document < ApplicationRecord
  has_many :extracted_data, dependent: :destroy
  has_one_attached :file

  validates :name, presence: true
  validates :original_filename, presence: true
  validates :status, inclusion: { in: %w[pending processing completed failed] }

  scope :completed, -> { where(status: "completed") }
  scope :failed, -> { where(status: "failed") }
  scope :processing, -> { where(status: "processing") }

  def completed?
    status == "completed"
  end

  def failed?
    status == "failed"
  end

  def processing?
    status == "processing"
  end

  def pending?
    status == "pending"
  end

  def mark_as_processing!
    update!(status: "processing")
  end

  def mark_as_completed!
    update!(status: "completed", processed_at: Time.current)
  end

  def mark_as_failed!(error_msg)
    update!(status: "failed", error_message: error_msg, processed_at: Time.current)
  end

  def extracted_data_hash
    extracted_data.pluck(:key, :value).to_h
  end
end
