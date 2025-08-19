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

  # Public entry point: preprocess image, send to OpenAI, parse response
  def extract_data(document)
    return {} unless document.file.attached?

    # 1. Download and preprocess image for better OCR
    raw_data      = document.file.download
    # processed_img = preprocess_image(raw_data)
    file_content  = Base64.strict_encode64(raw_data)

    # 2. Send to GPT-5-mini
    response = send_to_openai(file_content, document.content_type)

    # 3. Parse and clean JSON response
    parse_openai_response(response)
  end

  private

  # Adjust contrast, brightness, grayscale, and sharpen image for OCR
  # Adjust contrast, brightness, grayscale, sharpen, and upscale image for OCR
  def preprocess_image(raw_data)
    image = MiniMagick::Image.read(raw_data)

    # 1. Convert to grayscale (fast)
    image.colorspace "Gray"

    # 2. Simple contrast boost
    image.level "0%,100%,1.2"    # only boost contrast, not full auto-level

    # 3. Light sharpening (optional; remove to save time)
    image.unsharp "0x0.5+0.5+0.02"

    # 4. Ensure PNG for consistent encoding
    image.format "png"
    image.to_blob
  end

  # Build and send the chat completion request to GPT-5-mini
  def send_to_openai(file_content, content_type)
    supported = %w[image/jpeg image/jpg image/png image/gif image/webp]
    return OpenStruct.new(success?: false) unless supported.include?(content_type)

    body = {
      model: "gpt-5-mini",
      messages: [
        {
          role: "system",
          content: "You are the world’s foremost OCR specialist. Extract ALL fields from this Indian transport form in the exact visual order (header → parties → cargo → charges → footer) with ≥95% character-level accuracy. Copy labels verbatim and interpret handwritten text meticulously."
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
      # temperature: 0.0,
      max_completion_tokens: 20384,
      response_format: { type: "json_object" }
    }

    options = {
      headers: {
        "Content-Type"  => "application/json",
        "Authorization" => "Bearer #{@api_key}"
      },
      body:    body.to_json,
      timeout: 180
    }

    response = self.class.post("/v1/chat/completions", options)
    unless response.success?
      Rails.logger.error "GPT-5-mini API error: #{response.body}"
      return OpenStruct.new(success?: false, body: response.body)
    end

    generated = response.parsed_response.dig("choices", 0, "message", "content")
    OpenStruct.new(
      success?:        true,
      parsed_response: { "choices" => [ { "message" => { "content" => generated } } ] }
    )
  end

  # Detailed prompt optimized for ≥90% overall and ≥95% handwritten accuracy
  def build_gpt5_ocr_prompt
    <<~PROMPT
      You are the world’s leading OCR specialist for Indian transport forms. Your goal is to extract every field with ≥95% character-level accuracy, preserving the document’s original layout.

      1. Order & Structure
        – Follow visual order: Header → Parties → Cargo → Charges → Footer.
        – Divide into zones and process label then value line by line.

      2. Label Fidelity
        – Copy printed labels verbatim (including punctuation, apostrophes, ampersands, colons, spacing).
        – Keys in JSON must match labels exactly.

      3. Handwritten Text
        – Transcribe every handwritten stroke.
        – If unclear, output best guess and append " (illegible)".
        – Use context, repeated occurrences, and common Indian names/places (–kar, –pur, –nagar) to disambiguate.

      4. Numeric Verification
        – Cross-check LR No, GC No, dates, and numeric fields if they repeat.
        – Sum all charge rows; ensure they match the grand total. If not, re-OCR mismatched fields.

      5. Spelling & Codes
        – Correct obvious printed-text OCR typos.
        – Never alter alphanumeric codes (GST, MR No, reference numbers) except to fix clear stroke errors.

      6. Output Requirements
        – Return only valid JSON: a flat object with keys exactly as labels and values extracted (empty strings for blank fields).
        – Do not include confidence scores, commentary, or promotional/company info.

      QUALITY TARGET: ≥95% accuracy on printed text, ≥95% on handwritten text, complete coverage of all visible fields.
    PROMPT
  end

  # Parse, extract JSON, clean out unwanted fields, and return hash
  def parse_openai_response(response)
    return {} unless response.success?
    text = response.parsed_response.dig("choices", 0, "message", "content")
    return {} unless text

    json_str = extract_json_from_response(text)
    data     = JSON.parse(json_str) rescue {}
    return {} unless data.is_a?(Hash)

    clean_form_data(data)
  end

  # Extract pure JSON substring from possible markdown fences
  def extract_json_from_response(text)
    t = text.strip
    # Remove markdown fences (```json ... ```) and any backticks
    t.gsub!(/^```(?:json)?\s*\n?/, "")        # Remove starting fence with optional 'json'
    t.gsub!(/\n?```$/, "")                     # Remove ending fence
    # Alternatively, handle code fences more broadly:
    # t.gsub!(/^```.*$\n?/, '') # If fence line starts with ```AnyText
    start_idx = t.index("{")
    end_idx   = t.rindex("}")
    return t if start_idx.nil? || end_idx.nil?
    t[start_idx..end_idx].strip
  end

  # Remove empty values and company branding fields
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

  # Normalize arrays & strings
  def process_value(val)
    case val
    when Array
      val.map { |i| i.to_s.strip.gsub(/^["']|["']$/, "").gsub(/\s+\(.*\)$/, "") }.reject(&:empty?).join(", ")
    when String
      v = val.strip
      v = v.gsub(/^\[|\]$/, "")
      v = v.gsub(/^["']|["']$/, "")
      v = v.gsub(/\s+\(.*\)$/, "") # Remove confidence scores
      v.gsub(/", "/, ", ").gsub(/'\s*,\s*'/, ", ")
    else
      val.to_s.strip
    end
  end

  # Filter out company promotional info
  def is_company_info?(key, value)
    kp = key.downcase; vp = value.downcase
    terms = %w[dilipl roadlines agarwal packers website email tel mob gmail.com www caution carrier breakage leakages subject regd nse iso limca world book brand toll phone]
    terms.any? { |t| kp.include?(t) || vp.include?(t) }
  end
end
