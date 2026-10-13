# frozen_string_literal: true

require "rails_helper"

RSpec.describe Alchemy::StorageAdapter::ActiveStorage::DragonflyCompat::AttachmentUrl, if: Alchemy.storage_adapter.active_storage? do
  let(:attachment) { create(:alchemy_attachment) }
  let(:public_service) { true }
  let(:options) { {} }

  before do
    stub_alchemy_config(active_storage_dragonfly_compat: true)
    allow_any_instance_of(ActiveStorage::Service::DiskService).to receive(:public?) { public_service }
    ActiveStorage::Current.url_options = {host: "https://bucket.example.com"}
  end

  after do
    ActiveStorage::Current.reset
  end

  subject(:url) { described_class.new(attachment).call(options) }

  context "with a public service" do
    it "returns the service url of the file" do
      expect(url).to start_with("https://bucket.example.com/")
      expect(url).to include("image.png")
    end

    context "with download option" do
      let(:options) { {download: true} }

      it "returns the url to download the file" do
        expect(url).to match(/\/attachment\/\d+\/download\.png/)
      end
    end
  end

  context "with a private service" do
    let(:public_service) { false }

    it "returns the url to show the file" do
      expect(url).to match(/\/attachment\/\d+\/show\.png/)
    end
  end
end
