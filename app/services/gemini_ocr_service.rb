class GeminiOcrService
  include HTTParty

  base_uri "https://generativelanguage.googleapis.com"

  def initialize
    @api_key = ENV["GEMINI_API_KEY"]
    raise "GEMINI_API_KEY environment variable is required" unless @api_key
  end

  def extract_data(document)
    return {} unless document.file.attached?

    file_content = get_file_content(document)

    response = send_to_gemini(file_content, document.content_type)

    parse_gemini_response(response)
  end

  private

  def get_file_content(document)
    file_data = document.file.download
    Base64.strict_encode64(file_data)
  end

  def send_to_gemini(file_content, content_type)
    mime_type = case content_type
    when "application/pdf"
      "application/pdf"
    when "image/jpeg", "image/jpg"
      "image/jpeg"
    when "image/png"
      "image/png"
    else
      "image/jpeg"
    end

    body = {
      contents: [
        {
          parts: [
            {
              text: build_ocr_prompt
            },
            {
              inline_data: {
                mime_type: mime_type,
                data: file_content
              }
            }
          ]
        }
      ],
      generationConfig: {
        temperature: 0.1,
        maxOutputTokens: 8192
      }
    }

    options = {
      headers: {
        "Content-Type" => "application/json"
      },
      body: body.to_json,
      timeout: 60
    }

    self.class.post("/v1beta/models/gemini-2.0-flash-exp:generateContent?key=#{@api_key}", options)
  end

  def build_ocr_prompt
    <<~PROMPT
      Please extract all visible text, data, and information from this document and return it as a well-structured JSON object.

      Instructions:
      1. Extract ALL visible text including handwritten content, form fields, tables, headers, and any other readable information
      2. Organize the data into logical key-value pairs with descriptive keys
      3. Include numbers, dates, addresses, names, amounts, quantities, and any other structured data
      4. For tables, extract each cell with appropriate keys
      5. Make keys descriptive and human-readable (e.g., "customer_name", "invoice_date", "total_amount")
      6. Preserve the original values but ensure they are clean and readable
      7. If there are multiple similar items (like line items), number them (e.g., "item_1_description", "item_1_quantity")

      Return ONLY valid JSON with no additional text or explanation. The JSON should be a flat object with string keys and string values.

      Example format:
      {
        "customer_name": "John Doe",
        "invoice_number": "INV-2024-001",
        "invoice_date": "01/15/2024",
        "total_amount": "1,250.00",
        "item_1_description": "Moving Services",
        "item_1_quantity": "1",
        "item_1_rate": "1000.00"
      }
    PROMPT
  end

  def parse_gemini_response(response)
    return {} unless response.success?

    begin
      response_body = response.parsed_response

      generated_text = response_body.dig("candidates", 0, "content", "parts", 0, "text")

      return {} unless generated_text

      json_text = generated_text.strip
      json_text = json_text.gsub(/^```json\n/, "").gsub(/\n```$/, "").strip

      parsed_data = JSON.parse(json_text)

      return {} unless parsed_data.is_a?(Hash)

      cleaned_data = {}
      parsed_data.each do |key, value|
        cleaned_key = key.to_s.strip
        cleaned_value = value.to_s.strip

        next if cleaned_key.empty? || cleaned_value.empty?

        cleaned_data[cleaned_key] = cleaned_value
      end

      cleaned_data

    rescue JSON::ParserError => e
      Rails.logger.error "Failed to parse Gemini response as JSON: #{e.message}"
      Rails.logger.error "Response text: #{generated_text}"
      {}
    rescue => e
      Rails.logger.error "Error processing Gemini response: #{e.message}"
      {}
    end
  end
end
