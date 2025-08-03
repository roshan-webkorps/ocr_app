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
              text: build_form_focused_prompt
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
        temperature: 0.0,
        maxOutputTokens: 4096,
        responseMimeType: "application/json"
      }
    }

    options = {
      headers: {
        "Content-Type" => "application/json"
      },
      body: body.to_json,
      timeout: 120
    }

    self.class.post("/v1beta/models/gemini-1.5-flash:generateContent?key=#{@api_key}", options)
  end

  def build_form_focused_prompt
    <<~PROMPT
      Extract ONLY the filled form data from this business document. Ignore all company header information.

      WHAT TO EXTRACT:
      1. Form field labels and their handwritten/typed values
      2. Table data with actual content
      3. Document numbers, dates, and business details
      4. Any totals or calculated amounts

      WHAT TO IGNORE:
      - Company name and logo in header
      - Contact information (phone, email, address in header)
      - Legal disclaimers and caution text
      - "Carrier is not responsible..." text
      - Company registration details

      EXTRACTION RULES:
      1. Use exact field labels as shown on the form
      2. Read handwritten text carefully - use Indian context for place names
      3. For tables: combine related data from multiple rows into single values
      4. Convert arrays and lists to comma-separated text
      5. All text is in English
      6. Return clean, readable values without extra formatting

      HANDWRITING FOCUS:
      - Look at cursive writing carefully
      - Common Indian cities: Ranchi, Patna, Bangalore, Mumbai, Delhi
      - Numbers: read each digit clearly
      - Combine text that continues on next line

      TABLE HANDLING:
      - Combine multiple table rows into single field values
      - Example: if table has rows "1, 2" and "3, 4" for Number column, return "1, 2, 3, 4"
      - For descriptions: combine all descriptions with commas
      - Extract totals and amounts as single numbers

      OUTPUT FORMAT:
      Return clean JSON with readable string values, not arrays or formatted lists.
      Example: "Number": "1, 2" not "Number": ["1", "2"]

      Focus on creating clean, UI-friendly output.
    PROMPT
  end

  def parse_gemini_response(response)
    return {} unless response.success?

    begin
      response_body = response.parsed_response
      generated_text = response_body.dig("candidates", 0, "content", "parts", 0, "text")

      return {} unless generated_text

      json_text = extract_json_from_response(generated_text)
      parsed_data = JSON.parse(json_text)

      return {} unless parsed_data.is_a?(Hash)

      clean_form_data(parsed_data)

    rescue JSON::ParserError => e
      Rails.logger.error "Failed to parse Gemini response as JSON: #{e.message}"
      Rails.logger.error "Response text: #{generated_text}"
      {}
    rescue => e
      Rails.logger.error "Error processing Gemini response: #{e.message}"
      {}
    end
  end

  def extract_json_from_response(text)
    json_text = text.strip
    json_text = json_text.gsub(/^```json\s*\n?/, "").gsub(/\n?\s*```$/, "")
    json_text = json_text.gsub(/^```\s*\n?/, "").gsub(/\n?\s*```$/, "")

    start_brace = json_text.index("{")
    end_brace = json_text.rindex("}")

    if start_brace && end_brace && end_brace > start_brace
      json_text = json_text[start_brace..end_brace]
    end

    json_text.strip
  end

  def clean_form_data(data)
    cleaned = {}

    data.each do |key, value|
      clean_key = key.to_s.strip
      clean_value = process_value(value)

      next if clean_key.empty? || clean_value.empty?

      next if is_company_info?(clean_key, clean_value)

      cleaned[clean_key] = clean_value
    end

    cleaned
  end

  def process_value(value)
    case value
    when Array
      processed_items = value.map do |item|
        clean_item = item.to_s.strip.gsub(/^["']|["']$/, "") # Remove quotes
        clean_item
      end.reject(&:empty?)

      processed_items.join(", ")
    when String
      clean_value = value.strip
      clean_value = clean_value.gsub(/^\[|\]$/, "")
      clean_value = clean_value.gsub(/^["']|["']$/, "")
      clean_value = clean_value.gsub(/", "/, ", ")
      clean_value = clean_value.gsub(/'\s*,\s*'/, ", ")
      clean_value
    else
      value.to_s.strip
    end
  end

  def is_company_info?(key, value)
    key_lower = key.downcase
    value_lower = value.downcase

    company_terms = [
      "century packers", "specialist", "survey no", "email", "website",
      "tel:", "mob:", "gmail.com", "www.", "caution", "carrier is not",
      "breakage", "leakages", "subject to pune", "consionent copy",
      "century", "specialist of house", "door & door", "regd"
    ]

    company_terms.any? { |term| key_lower.include?(term) || value_lower.include?(term) }
  end
end
