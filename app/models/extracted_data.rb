class ExtractedData < ApplicationRecord
  belongs_to :document

  validates :key, presence: true
  validates :data_type, inclusion: { in: %w[text number date] }

  scope :by_key, ->(key) { where(key: key) }

  def formatted_value
    case data_type
    when "date"
      begin
        Date.parse(value).strftime("%B %d, %Y") if value.present?
      rescue Date::Error
        value
      end
    when "number"
      begin
        number = value.to_f
        number == number.to_i ? number.to_i.to_s : number.to_s
      rescue
        value
      end
    else
      value
    end
  end
end
