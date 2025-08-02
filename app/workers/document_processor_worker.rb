class DocumentProcessorWorker
  include Sidekiq::Worker

  sidekiq_options retry: 8, retry_in: proc { |count| 2 ** count }

  def perform(document_id)
    Rails.logger.info "Starting document processing for document #{document_id}"

    document = Document.find(document_id)
    document.mark_as_processing!

    begin
      ocr_service = GeminiOcrService.new
      extracted_data = ocr_service.extract_data(document)

      store_extracted_data(document, extracted_data)

      document.mark_as_completed!
      Rails.logger.info "Successfully processed document #{document.id}"

    rescue => e
      Rails.logger.error "Failed to process document #{document.id}: #{e.message}"
      Rails.logger.error e.backtrace.join("\n")
      document.mark_as_failed!(e.message)
      raise e
    end
  end

  private

  def store_extracted_data(document, data_hash)
    return unless data_hash.is_a?(Hash)

    data_hash.each do |key, value|
      next if key.blank? || value.blank?

      data_type = determine_data_type(value)

      document.extracted_data.create!(
        key: sanitize_key(key),
        value: value.to_s.strip,
        data_type: data_type
      )
    end
  end

  def determine_data_type(value)
    return "number" if value.to_s.match?(/^\d+(\.\d+)?$/)

    return "date" if looks_like_date?(value.to_s)

    "text"
  end

  def looks_like_date?(value)
    date_patterns = [
      /\d{1,2}\/\d{1,2}\/\d{4}/,     # MM/DD/YYYY or M/D/YYYY
      /\d{1,2}-\d{1,2}-\d{4}/,       # MM-DD-YYYY
      /\d{4}-\d{1,2}-\d{1,2}/,       # YYYY-MM-DD
      /\w+ \d{1,2}, \d{4}/           # Month DD, YYYY
    ]

    date_patterns.any? { |pattern| value.match?(pattern) }
  end

  def sanitize_key(key)
    key.to_s.strip.gsub(/[^\w\s-]/, "").gsub(/\s+/, "_").downcase
  end
end
