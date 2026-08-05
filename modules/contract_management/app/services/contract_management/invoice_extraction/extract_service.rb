# frozen_string_literal: true

module ContractManagement
  module InvoiceExtraction
    class ExtractService
      def initialize(extraction:, reader: DocumentReader.new)
        @extraction = extraction
        @reader = reader
      end

      def call
        mark_processing
        result = reader.read(extraction.attachments.first!)
        mark_completed(result)
        ServiceResult.success(result: extraction)
      rescue StandardError => e
        mark_failed(e)
        ServiceResult.failure(result: extraction, message: e.message)
      end

      private

      attr_reader :extraction, :reader

      def mark_processing
        extraction.update!(status: "processing", model: nil, error_message: nil)
      end

      def mark_completed(result)
        extraction.update!(
          status: "completed",
          extracted_data: FieldParser.new(result.fetch(:text)).call,
          extraction_method: result.fetch(:method)
        )
      end

      def mark_failed(error)
        extraction.update_columns(status: "failed", error_message: error.message)
      end
    end
  end
end
