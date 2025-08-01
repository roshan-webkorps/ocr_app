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
      You are an expert OCR specialist. Extract ALL data with PERFECT accuracy. Every character matters.

      CRITICAL RULES - FOLLOW EXACTLY:

      1. FIELD NAMES: Use EXACT field labels from document - do NOT change, abbreviate, or "improve" them
        - If document shows "NO, PNAI" → use "NO, PNAI" (exactly)
        - If document shows "PARTY MOBILE NO." → use "PARTY MOBILE NO." (exactly)
        - If document shows "CONSIGNOR'S NAME & ADDRESS:" → use "CONSIGNOR'S NAME & ADDRESS:" (exactly)
        - Preserve ALL punctuation, spacing, and capitalization from original labels

      2. TABLE EXTRACTION: Extract each cell individually, do NOT create JSON objects
        - For table with columns: Number, Packages, Description, Actual, Charged, Private, Fixed, Amount Rs.
        - Extract as: "row_1_number", "row_1_packages", "row_1_description", "row_1_actual", etc.
        - Continue for ALL rows: row_2_number, row_2_packages, row_2_description, etc.
        - Include empty cells as blank values
        - Extract TOTAL field separately as "total_amount"

      3. HANDWRITING ACCURACY: Read handwritten text character by character
        - Take context into account (e.g., "Baylore" in India context = "Bangalore")
        - Look for partial words and complete them logically
        - Study cursive letters carefully - don't guess quickly
        - If writing continues on next line, combine it

      4. BLANK FIELDS: Include all field labels even if empty
        - "CONSIGNOR'S NAME & ADDRESS:": "" (if blank)
        - "CONSIGNEE NAME & ADDRESS:": "" (if blank)

      EXTRACTION PROTOCOL:
      1. Scan document top to bottom, left to right
      2. Read EVERY field label exactly as written
      3. Extract corresponding values (handwritten or printed)
      4. For tables: extract each cell with proper row/column naming
      5. Look for totals, signatures, and annotations
      6. Double-check all handwritten text for accuracy

      IGNORE ONLY:
      ✗ Company letterhead (logos, company name in header)
      ✗ Company contact info in header
      ✗ Standard disclaimers like "Carrier is not responsible..."

      EXTRACT EVERYTHING ELSE:
      ✓ ALL form field labels and values (exact names)
      ✓ ALL table data (individual cells, not JSON)
      ✓ ALL handwritten text (read carefully)
      ✓ ALL amounts, dates, numbers
      ✓ ALL signatures and notes
      ✓ Totals and calculations

      TABLE PARSING EXAMPLE:
      If you see table with columns: Number | Description | Actual | Amount
      And rows:
      1. | Item A | 5 | 100
      2. | Item B | 3 | 150

      Extract as:
      {
        "row_1_number": "1",
        "row_1_description": "Item A",
        "row_1_actual": "5",
        "row_1_amount": "100",
        "row_2_number": "2",
        "row_2_description": "Item B",
        "row_2_actual": "3",
        "row_2_amount": "150"
      }

      HANDWRITING TIPS:
      - "Baylore" in Indian context = "Bangalore"
      - Look for city/place name patterns
      - Consider document context when reading unclear text
      - Combine partial words across lines
      - Read signatures and totals carefully

      FIELD NAME EXAMPLES (use exactly as shown in document):
      - "NO, PNAI" (not "No Pnai" or "PNAI Number")
      - "DATE" (not "Transaction Date")
      - "PARTY MOBILE NO." (not "Party Mobile No")
      - "Moving FROM" and "TO" (not "Moving From" and "Moving To")

      QUALITY CHECK BEFORE RESPONDING:
      1. Are field names EXACTLY as shown in document?
      2. Is table data extracted as individual cells (not JSON)?
      3. Did I read handwritten text carefully and logically?
      4. Did I find all totals and amounts?
      5. Are blank fields included with empty values?

      Extract with PERFECT accuracy - use EXACT field names and read handwriting intelligently!
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
