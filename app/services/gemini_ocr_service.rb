require "ostruct"
require "base64"
require "httparty"
require "mini_magick"
require "json"

class GeminiOcrService
  include HTTParty

  base_uri "https://api.openai.com"

  def initialize
    @api_key = ENV["OPENAI_API_KEY"]
    raise "OPENAI_API_KEY environment variable is required" unless @api_key
  end

  def extract_data(document)
    return {} unless document.file.attached?

    raw_data      = document.file.download
    processed_img = preprocess_image(raw_data)
    file_content  = Base64.strict_encode64(processed_img)

    response = send_to_openai(file_content, document.content_type)

    parse_openai_response(response)
  end

  private

  def preprocess_image(raw_data)
    image = MiniMagick::Image.read(raw_data)

    image.colorspace "Gray"

    image.level "0%,100%,1.2"

    image.unsharp "0x0.5+0.5+0.02"

    image.format "png"
    image.to_blob
  end

  def send_to_openai(file_content, content_type)
    supported = %w[image/jpeg image/jpg image/png image/gif image/webp]
    return OpenStruct.new(success?: false) unless supported.include?(content_type)

    body = {
      model: "gpt-4o",
      messages: [
        {
          role: "system",
          content: "You are an expert OCR specialist for Indian logistics documents. Extract ALL visible fields with ≥95% accuracy."
        },
        {
          role: "user",
          content: [
            { type: "text", text: build_gpt5_ocr_prompt },
            {
              type: "image_url",
              image_url: {
                url: "data:#{content_type};base64,#{file_content}",
                detail: "high"
              }
            }
          ]
        }
      ],
      temperature: 0,
      max_tokens: 8000,
      response_format: { type: "json_object" }
    }

    options = {
      headers: {
        "Content-Type"  => "application/json",
        "Authorization" => "Bearer #{@api_key}"
      },
      body: body.to_json,
      timeout: 180
    }

    response = self.class.post("/v1/chat/completions", options)
    unless response.success?
      Rails.logger.error "OpenAI API error: #{response.body}"
      return OpenStruct.new(success?: false, body: response.body)
    end

    generated = response.parsed_response.dig("choices", 0, "message", "content")
    OpenStruct.new(
      success?:        true,
      parsed_response: { "choices" => [ { "message" => { "content" => generated } } ] }
    )
  end

  def build_gpt5_ocr_prompt
    <<~PROMPT
      You are an expert OCR specialist for Indian logistics documents. Extract ALL visible fields with ≥95% accuracy.

      CRITICAL: Extract EVERY field on the document - scan the entire image systematically.
      FOLLOW THE EXACT VISUAL ORDER: Process fields in the same sequence they appear on the document from top-to-bottom, left-to-right.

      PRIORITY FIELDS (99% accuracy required):
      - ALL fields starting with "Consignor" or "Consignee" (names, addresses, GST numbers)
      - ALL "From" and "To" related fields (stations, addresses, locations)
      - Examine these fields extra carefully for handwritten content

      COMPLETE EXTRACTION CHECKLIST:
      1. Header section: Company details, document numbers, dates
      2. Risk/Segment checkboxes: AT OWNER'S RISK, AT CARRIER'S RISK, Commercial, Parcel, HHG
      3. Party details: Complete consignor and consignee information with addresses
      4. Transport details: From/To stations, vehicle details
      5. Package information: Quantity, description, weight details
      6. All charges: Freight, statistical, surcharge, demurrage, totals
      7. Payment terms and conditions
      8. Signatures and stamps
      9. Table data: Include ALL table headers and corresponding values

      ACCURACY RULES:
      - Read handwritten text character-by-character carefully
      - If text is unclear, examine surrounding context and similar words
      - For locations: Look for Indian city/state patterns
      - Cross-verify information that appears multiple times
      - Never guess or substitute - extract exactly what's written

      OUTPUT FORMAT:
      - Extract EVERY visible field as separate JSON entries
      - Use exact field labels as they appear on the document
      - Include empty fields with ""
      - Preserve original punctuation and formatting
      - Maintain the same field order as they appear visually on the document

      EXAMPLE of thorough extraction:
      {
        "GC No.": "4936593",
        "Date": "29/3/25",
        "From Station": "[exact text from document]",
        "To Station": "[exact text from document]",
        "Consignor's Name & Address": "[complete address]",
        "Consignee's Name & Address": "[complete address]"
      }

      REMEMBER: Extract EVERYTHING visible, especially consignor/consignee/from/to fields.
    PROMPT
  end

  def parse_openai_response(response)
    return {} unless response.success?
    text = response.parsed_response.dig("choices", 0, "message", "content")
    return {} unless text

    json_str = extract_json_from_response(text)
    data     = JSON.parse(json_str) rescue {}
    return {} unless data.is_a?(Hash)

    clean_form_data(data)
  end

  def extract_json_from_response(text)
    t = text.strip
    t.gsub!(/^```(?:json)?\s*\n?/, "")
    t.gsub!(/\n?```$/, "")
    start_idx = t.index("{")
    end_idx   = t.rindex("}")
    return t if start_idx.nil? || end_idx.nil?
    t[start_idx..end_idx].strip
  end

  def clean_form_data(data)
    cleaned = {}
    data.each do |k, v|
      key   = k.to_s.strip
      value = process_value(v)
      next if key.empty? || value.empty?
      next if is_company_info?(key, value)
      cleaned[key] = value
    end
    cleaned
  end

  def process_value(val)
    case val
    when Array
      val.map { |i| i.to_s.strip.gsub(/^["']|["']$/, "").gsub(/\s+\(.*\)$/, "") }.reject(&:empty?).join(", ")
    when String
      v = val.strip
      v = v.gsub(/^\[|\]$/, "")
      v = v.gsub(/^["']|["']$/, "")
      v = v.gsub(/\s+\(.*\)$/, "")
      v.gsub(/", "/, ", ").gsub(/'\s*,\s*'/, ", ")
    else
      val.to_s.strip
    end
  end

  def is_company_info?(key, value)
    kp = key.downcase; vp = value.downcase
    terms = %w[dilipl roadlines agarwal packers website email tel mob gmail.com www caution carrier breakage leakages subject regd nse iso limca world book brand toll phone note]
    terms.any? { |t| kp.include?(t) || vp.include?(t) }
  end
end
