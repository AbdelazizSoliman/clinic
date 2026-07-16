module Uploads
  class FileSignature
    SIGNATURES = {
      "image/jpeg" => ->(bytes) { bytes.start_with?("\xFF\xD8\xFF".b) },
      "image/png" => ->(bytes) { bytes.start_with?("\x89PNG\r\n\x1A\n".b) },
      "image/webp" => ->(bytes) { bytes.start_with?("RIFF") && bytes.byteslice(8, 4) == "WEBP" },
      "application/pdf" => ->(bytes) { bytes.start_with?("%PDF-") }
    }.freeze

    def self.valid?(io, content_type)
      validator = SIGNATURES[content_type]
      return false unless validator
      position = io.pos if io.respond_to?(:pos)
      bytes = io.read(16).to_s.b
      validator.call(bytes)
    ensure
      io.seek(position || 0) if io.respond_to?(:seek)
    end
  end
end
