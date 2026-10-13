# frozen_string_literal: true

module Alchemy
  class StorageAdapter
    # Stores Active Storage blobs at the keys Alchemy's Dragonfly setup used
    # and serves them from the bucket directly.
    #
    # Enable with +Alchemy.config.active_storage_dragonfly_compat = true+
    #
    module ActiveStorage::DragonflyCompat
      PICTURES_PREFIX = "pictures"
      ATTACHMENTS_PREFIX = "attachments"

      # Keys Active Storage generates itself (+has_secure_token+, base36)
      GENERATED_KEY = /\A[0-9a-z]{#{::ActiveStorage::Blob::MINIMUM_TOKEN_LENGTH}}\z/

      extend self

      def enabled?
        Alchemy.storage_adapter.active_storage? &&
          Alchemy.config.active_storage_dragonfly_compat
      end

      # Sets a Dragonfly style key on a newly attached original.
      #
      # @param [ActiveRecord::Base] record
      # @param [String] name The attachment name
      # @param [String] prefix
      def assign_original_key(record, name, prefix:)
        blob = new_blob(record, name)
        return unless blob

        blob.key = original_key(prefix, blob.filename)
      end

      # Sets a Dragonfly thumb style key on a new variant of a picture.
      #
      # @param [ActiveStorage::VariantRecord] variant_record
      def assign_variant_key(variant_record)
        return unless enabled?

        blob = new_blob(variant_record, "image")
        return unless blob

        picture_id = ::ActiveStorage::Attachment.where(
          blob_id: variant_record.blob_id,
          record_type: "Alchemy::Picture",
          name: "image_file"
        ).pick(:record_id)
        return unless picture_id

        blob.key = variant_key(picture_id, variant_record, blob.filename)
      end

      # @example
      #   original_key("pictures", "Auge.jpg") # => "pictures/2017/01/10/83ppgg6hyu_auge.jpg"
      #
      # @return [String]
      def original_key(prefix, filename, time: Time.current)
        token = SecureRandom.base36(10)
        "#{prefix}/#{time.strftime("%Y/%m/%d")}/#{token}_#{sanitize(filename)}"
      end

      # The signature depends on the original's key, so replacing the image
      # file of a picture never reuses the key of a variant of the old file.
      #
      # @example
      #   variant_key(42, variant_record, "auge.webp") # => "pictures/42/3f1c…/auge.webp"
      #
      # @return [String]
      def variant_key(picture_id, variant_record, filename)
        signature = Digest::SHA1.hexdigest(
          "#{variant_record.blob.key}/#{variant_record.variation_digest}"
        )
        "#{PICTURES_PREFIX}/#{picture_id}/#{signature}/#{sanitize(filename)}"
      end

      private

      # Only blobs that are about to be uploaded can get a new key, and a key
      # set by the caller (e.g. a migration passing +key:+) is kept.
      def new_blob(record, name)
        change = record.attachment_changes[name]
        return unless change.is_a?(::ActiveStorage::Attached::Changes::CreateOne)

        blob = change.blob
        return unless blob.new_record?
        return if blob.key.present? && !GENERATED_KEY.match?(blob.key)

        blob
      end

      def sanitize(filename)
        filename = ::ActiveStorage::Filename.wrap(filename)
        base = ::I18n.transliterate(filename.base).downcase.gsub(/[^\w.-]+/, "_").first(100)
        base = "file" unless base.match?(/[a-z0-9]/)
        [base, filename.extension_without_delimiter&.downcase].compact_blank.join(".")
      end
    end
  end
end
