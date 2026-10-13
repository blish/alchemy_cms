# frozen_string_literal: true

require "rails_helper"

RSpec.describe Alchemy::StorageAdapter::ActiveStorage::DragonflyCompat, if: Alchemy.storage_adapter.active_storage? do
  let(:compat) { true }

  before do
    stub_alchemy_config(active_storage_dragonfly_compat: compat)
  end

  describe ".original_key" do
    subject { described_class.original_key("pictures", filename, time: Time.zone.local(2017, 1, 10)) }

    let(:filename) { "auge.jpg" }

    it "returns a Dragonfly style key" do
      is_expected.to match(%r{\Apictures/2017/01/10/[0-9a-z]{10}_auge\.jpg\z})
    end

    context "with special characters in the filename" do
      let(:filename) { "Grüne Äpfel & #1+2.JPG" }

      it "returns a key safe for S3" do
        is_expected.to match(%r{\Apictures/2017/01/10/[0-9a-z]{10}_grune_apfel_1_2\.jpg\z})
      end
    end

    context "with a filename without usable characters" do
      let(:filename) { "???.png" }

      it "uses a placeholder" do
        is_expected.to match(%r{_file\.png\z})
      end
    end
  end

  describe "creating a picture" do
    let(:picture) { create(:alchemy_picture) }

    it "stores the image file at a Dragonfly style key" do
      expect(picture.image_file.key).to match(%r{\Apictures/\d{4}/\d{2}/\d{2}/[0-9a-z]{10}_image\.png\z})
    end

    it "uploads the file to that key" do
      expect(picture.image_file.service.exist?(picture.image_file.key)).to be(true)
    end

    context "with a key given" do
      let(:picture) do
        Alchemy::Picture.create!(
          image_file: {
            io: File.open(Alchemy::Engine.root.join("lib/alchemy/test_support/fixtures/image.png")),
            filename: "image.png",
            key: "pictures/2017/01/10/83ppgg6hyu_image.png"
          }
        )
      end

      it "keeps the key" do
        expect(picture.image_file.key).to eq("pictures/2017/01/10/83ppgg6hyu_image.png")
      end
    end

    context "with an existing blob" do
      let(:blob) do
        ActiveStorage::Blob.create_and_upload!(
          io: File.open(Alchemy::Engine.root.join("lib/alchemy/test_support/fixtures/image.png")),
          filename: "image.png"
        )
      end

      let(:picture) { Alchemy::Picture.create!(image_file: blob) }

      it "keeps the key" do
        expect(picture.image_file.key).to eq(blob.key)
      end
    end

    context "if disabled" do
      let(:compat) { false }

      it "stores the image file at an Active Storage key" do
        expect(picture.image_file.key).to match(/\A[0-9a-z]{28}\z/)
      end
    end
  end

  describe "replacing the image file of a picture" do
    let(:picture) { create(:alchemy_picture) }

    it "stores the new image file at a new Dragonfly style key" do
      old_key = picture.image_file.key
      picture.update!(image_file: fixture_file_upload("image2.PNG"))
      expect(picture.reload.image_file.key).to match(%r{\Apictures/\d{4}/\d{2}/\d{2}/[0-9a-z]{10}_image2\.png\z})
      expect(picture.image_file.key).not_to eq(old_key)
    end
  end

  describe "creating an attachment" do
    let(:attachment) { create(:alchemy_attachment) }

    it "stores the file at a Dragonfly style key" do
      expect(attachment.file.key).to match(%r{\Aattachments/\d{4}/\d{2}/\d{2}/[0-9a-z]{10}_image\.png\z})
    end

    context "if disabled" do
      let(:compat) { false }

      it "stores the file at an Active Storage key" do
        expect(attachment.file.key).to match(/\A[0-9a-z]{28}\z/)
      end
    end
  end

  describe "processing a picture variant" do
    let(:picture) { create(:alchemy_picture) }

    subject(:variant_key) do
      picture.image_file.variant(resize_to_limit: [10, 10], format: :webp).processed.key
    end

    it "stores the variant at a Dragonfly thumb style key" do
      expect(variant_key).to match(%r{\Apictures/#{picture.id}/\h{40}/image\.webp\z})
    end

    it "uses a different signature per variation" do
      other_key = picture.image_file.variant(resize_to_limit: [20, 20], format: :webp).processed.key
      expect(other_key).not_to eq(variant_key)
    end

    context "if disabled" do
      let(:compat) { false }

      it "stores the variant at an Active Storage key" do
        expect(variant_key).to match(/\A[0-9a-z]{28}\z/)
      end
    end
  end

  describe "processing a variant of a blob not attached to a picture" do
    let(:attachment) { create(:alchemy_attachment) }

    it "stores the variant at an Active Storage key" do
      key = attachment.file.variant(resize_to_limit: [10, 10]).processed.key
      expect(key).to match(/\A[0-9a-z]{28}\z/)
    end
  end

  describe ".enabled?" do
    context "with dragonfly storage adapter" do
      before do
        allow(Alchemy.storage_adapter).to receive(:active_storage?) { false }
      end

      it { expect(described_class.enabled?).to be(false) }
    end
  end
end
