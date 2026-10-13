# frozen_string_literal: true

require "rails_helper"

RSpec.describe Alchemy::StorageAdapter::ActiveStorage::DragonflyCompat::PictureUrl, if: Alchemy.storage_adapter.active_storage? do
  let(:picture) { create(:alchemy_picture, image_file:) }
  let(:image_file) { fixture_file_upload("image.png") }
  let(:public_service) { true }
  let(:options) { {size: "10x10", format: "webp"} }

  before do
    stub_alchemy_config(active_storage_dragonfly_compat: true)
    allow_any_instance_of(ActiveStorage::Service::DiskService).to receive(:public?) { public_service }
    ActiveStorage::Current.url_options = {host: "https://bucket.example.com"}
  end

  after do
    ActiveStorage::Current.reset
  end

  subject(:url) { described_class.new(picture).call(options) }

  context "when picture has no image_file" do
    before do
      allow(picture).to receive(:image_file).and_return(nil)
    end

    it { expect(url).to be_nil }
  end

  context "with a public service" do
    it "returns the service url of the variant" do
      expect(url).to eq(picture.image_file.blob.variant_records.last.image.url)
      expect(url).to start_with("https://bucket.example.com/")
    end

    it "renders the variant while generating the url" do
      expect { url }.to change { ActiveStorage::VariantRecord.count }.by(1)
    end

    it "reuses an existing variant" do
      described_class.new(picture).call(options)
      expect { url }.not_to change { ActiveStorage::VariantRecord.count }
    end

    context "with a not variable file" do
      let(:image_file) { fixture_file_upload("icon.svg") }
      let(:options) { {} }

      it "returns the service url of the original" do
        expect(url).to start_with("https://bucket.example.com/")
        expect(url).to include("icon.svg")
      end
    end

    context "if processing fails" do
      before do
        allow_any_instance_of(ActiveStorage::VariantWithRecord).to receive(:processed) do
          raise ActiveStorage::FileNotFoundError
        end
      end

      it "returns nil" do
        expect(url).to be_nil
      end
    end
  end

  context "with a private service" do
    let(:public_service) { false }

    it "returns the redirect url" do
      expect(url).to match(%r{\A/rails/active_storage/representations/redirect/.+/image\.webp\z})
    end
  end
end
