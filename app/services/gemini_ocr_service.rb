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
      Please extract RELEVANT data from this document and return it as a well-structured JSON object.

      IMPORTANT GUIDELINES:
      1. Focus on TRANSACTIONAL and CUSTOMER-SPECIFIC data that varies between documents
      2. EXCLUDE company branding, contact information, and boilerplate text
      3. EXCLUDE standard disclaimers, cautions, terms & conditions, and legal text
      4. EXCLUDE company addresses, phone numbers, emails, and website URLs
      5. Include customer information, service details, amounts, quantities, dates, and reference numbers
      6. Include any handwritten content or form field data
      7. For tables, extract each meaningful row with appropriate keys

      EXTRACT:
      ✓ Customer names, addresses, contact details
      ✓ Invoice/reference/tracking numbers#{'  '}
      ✓ Dates, times, and deadlines
      ✓ Service descriptions and specifications
      ✓ Quantities, weights, measurements
      ✓ Rates, amounts, charges, and totals
      ✓ Origin and destination information
      ✓ Item descriptions and categories
      ✓ Any handwritten notes or special instructions

      DO NOT EXTRACT:
      ✗ Company name, logo, or branding information
      ✗ Company contact details (phone, email, address, website)
      ✗ Standard disclaimers, terms, conditions, or legal text
      ✗ Caution messages or warning text
      ✗ Company registration details or certifications
      ✗ Boilerplate text that appears on every document

      Return ONLY valid JSON with descriptive keys and clean values. Use format:
      {
        "customer_name": "John Doe",
        "reference_number": "INV-2024-001",#{' '}
        "service_date": "01/15/2024",
        "total_amount": "1,250.00"
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
