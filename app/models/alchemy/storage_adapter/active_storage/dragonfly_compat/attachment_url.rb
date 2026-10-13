# frozen_string_literal: true

module Alchemy
  class StorageAdapter
    # Attachment URLs pointing directly at the bucket, like Alchemy's Dragonfly
    # S3 setup did.
    #
    # Download URLs keep using Alchemy's download route, because a public
    # bucket URL cannot force +Content-Disposition: attachment+ and
    # {Alchemy::Attachment.deletable} detects linked attachments by that route.
    #
    # Falls back to Alchemy's routes if the service is not +public: true+,
    # because presigned URLs expire.
    #
    class ActiveStorage::DragonflyCompat::AttachmentUrl < ActiveStorage::AttachmentUrl
      def call(options = {})
        return super if options[:download] || !attachment.file.attached?

        blob = attachment.file.blob
        blob.service.public? ? blob.url : super
      end
    end
  end
end
