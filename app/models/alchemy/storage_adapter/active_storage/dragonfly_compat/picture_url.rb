# frozen_string_literal: true

module Alchemy
  class StorageAdapter
    # Picture URLs pointing directly at the bucket, like Alchemy's Dragonfly
    # S3 setup did, instead of the +/rails/active_storage/representations+ route.
    #
    # Takes the same options as {ActiveStorage::PictureUrl}, so variants are identical.
    # A missing variant is rendered synchronously while the page renders.
    #
    # Falls back to the redirect route if the service is not +public: true+,
    # because presigned URLs expire.
    #
    class ActiveStorage::DragonflyCompat::PictureUrl < ActiveStorage::PictureUrl
      # ImageProcessing and Vips (or MiniMagick) are only loaded when a variant
      # is processed, and only one of them is installed, so resolve them lazily.
      RESCUABLE_ERRORS = %w[
        ActiveStorage::Error
        ImageProcessing::Error
        MiniMagick::Error
        Vips::Error
        Aws::S3::Errors::ServiceError
        Seahorse::Client::NetworkingError
      ].freeze

      def call(options = {})
        return nil unless image_file
        return super unless image_file.service.public?

        started = monotonic_now
        variant = image_variant(options.merge(format: output_format(options)))
        return nil unless variant

        # Not variable (e.g. SVG): image_variant returns the original blob
        return variant.url if variant.is_a?(::ActiveStorage::Blob)

        existed = variant.send(:processed?)
        url = variant.processed.url
        unless existed
          Rails.logger.info do
            "[Alchemy] Rendered variant of picture ##{picture.id} (#{options[:size] || "original size"}) " \
              "in #{elapsed_ms(started)} ms"
          end
        end
        url
      rescue *rescuable_errors => e
        # A single missing or broken original must not break the page.
        # Alchemy renders its missing image placeholder instead.
        Rails.logger.warn(
          "[Alchemy] Variant of picture ##{picture.id} failed after #{elapsed_ms(started)} ms: " \
          "#{e.class}: #{e.message}"
        )
        nil
      end

      private

      def elapsed_ms(started)
        started ? ((monotonic_now - started) * 1000).round(1) : 0
      end

      def monotonic_now
        Process.clock_gettime(Process::CLOCK_MONOTONIC)
      end

      def rescuable_errors
        RESCUABLE_ERRORS.filter_map(&:safe_constantize)
      end
    end
  end
end
