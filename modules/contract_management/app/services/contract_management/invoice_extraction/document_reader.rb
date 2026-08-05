# frozen_string_literal: true

require "open3"
require "tmpdir"

module ContractManagement
  module InvoiceExtraction
    class DocumentReader
      ACCEPTED_TYPES = %w[application/pdf image/jpeg image/png image/webp].freeze
      MAX_PDF_PAGES = 10

      class Error < StandardError; end

      def read(attachment)
        validate!(attachment)

        Dir.mktmpdir("contract-invoice") do |directory|
          images = images_for(attachment, directory)
          sources(attachment, images).each do |method, reader|
            text = reader.call
            return { text:, method: } if FieldParser.new(text).summary?
          end
        end

        raise Error, I18n.t("contract_management.invoice_extraction.errors.unreadable")
      end

      private

      def validate!(attachment)
        return if ACCEPTED_TYPES.include?(attachment.content_type)

        raise Error, I18n.t("contract_management.invoice_extraction.errors.unsupported_file")
      end

      def sources(attachment, images)
        {
          "qr_code" => -> { read_qr_codes(images) },
          "pdf_text" => -> { pdf_text(attachment) },
          "ocr" => -> { images.filter_map { |image| ocr(image) }.join("\n") }
        }
      end

      def source_path(attachment)
        attachment.file.local_file.path
      end

      def images_for(attachment, directory)
        return [source_path(attachment)] unless attachment.content_type == "application/pdf"

        prefix = File.join(directory, "page")
        run!("pdftoppm", "-f", "1", "-l", MAX_PDF_PAGES.to_s, "-r", "200", "-png", source_path(attachment), prefix)
        Dir.glob("#{prefix}-*.png")
      end

      def read_qr_codes(images)
        images.filter_map do |image|
          stdout, = Open3.capture3("zbarimg", "--quiet", "--raw", image)
          stdout.presence
        rescue Errno::ENOENT
          raise Error, I18n.t("contract_management.invoice_extraction.errors.missing_dependency", command: "zbarimg")
        end.join("\n")
      end

      def pdf_text(attachment)
        return "" unless attachment.content_type == "application/pdf"

        stdout, = run!("pdftotext", "-layout", source_path(attachment), "-")
        stdout
      end

      def ocr(image)
        stdout, = run!("tesseract", image, "stdout", "-l", "por")
        stdout
      end

      def run!(*command)
        stdout, stderr, status = Open3.capture3(*command)
        raise Error, stderr.presence || "Falha ao executar #{command.first}." unless status.success?

        [stdout, stderr]
      rescue Errno::ENOENT
        raise Error,
              I18n.t("contract_management.invoice_extraction.errors.missing_dependency", command: command.first)
      end
    end
  end
end
