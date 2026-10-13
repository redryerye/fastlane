require 'deliver/upload_creative_assets'
require 'deliver/creative_asset'

describe Deliver::UploadCreativeAssets do
  let(:uploader) { Deliver::UploadCreativeAssets.new }
  let(:option_key) { :product_page_header_path }

  describe '#assign_default_images' do
    let(:options) do
      {
        languages: ['en-US', 'ko', 'ja'],
        product_page_header_path: '/path/to/creative_assets'
      }
    end

    it 'should assign default image to languages without images' do
      default_image = Deliver::CreativeAsset.new('/path/to/creative_assets/default/header.jpg', nil)
      en_image = Deliver::CreativeAsset.new('/path/to/creative_assets/en-US/header.jpg', 'en-US')
      creative_assets = [default_image, en_image]

      uploader.send(:assign_default_images, options, option_key, creative_assets)

      expect(creative_assets.length).to eq(3)
      expect(creative_assets.map(&:language)).to contain_exactly('en-US', 'ko', 'ja')

      ko_image = creative_assets.find { |img| img.language == 'ko' }
      ja_image = creative_assets.find { |img| img.language == 'ja' }
      expect(ko_image.path).to eq('/path/to/creative_assets/default/header.jpg')
      expect(ja_image.path).to eq('/path/to/creative_assets/default/header.jpg')
    end

    it 'should not assign default image to languages that already have images' do
      default_image = Deliver::CreativeAsset.new('/path/to/creative_assets/default/header.jpg', nil)
      en_image = Deliver::CreativeAsset.new('/path/to/creative_assets/en-US/header.jpg', 'en-US')
      ko_image = Deliver::CreativeAsset.new('/path/to/creative_assets/ko/header.jpg', 'ko')
      ja_image = Deliver::CreativeAsset.new('/path/to/creative_assets/ja/header.jpg', 'ja')
      creative_assets = [default_image, en_image, ko_image, ja_image]

      uploader.send(:assign_default_images, options, option_key, creative_assets)

      expect(creative_assets.length).to eq(3)
      expect(creative_assets.map(&:language)).to contain_exactly('en-US', 'ko', 'ja')
      expect(creative_assets.find { |img| img.language == 'en-US' }.path).to eq('/path/to/creative_assets/en-US/header.jpg')
    end

    it 'should remove default image from the list after assignment' do
      default_image = Deliver::CreativeAsset.new('/path/to/creative_assets/default/header.jpg', nil)
      en_image = Deliver::CreativeAsset.new('/path/to/creative_assets/en-US/header.jpg', 'en-US')
      creative_assets = [default_image, en_image]

      uploader.send(:assign_default_images, options, option_key, creative_assets)

      expect(creative_assets.none? { |img| img.language.nil? }).to be(true)
    end

    it 'should do nothing when there is no default folder' do
      en_image = Deliver::CreativeAsset.new('/path/to/creative_assets/en-US/header.jpg', 'en-US')
      ko_image = Deliver::CreativeAsset.new('/path/to/creative_assets/ko/header.jpg', 'ko')
      creative_assets = [en_image, ko_image]

      original_count = creative_assets.length
      uploader.send(:assign_default_images, options, option_key, creative_assets)

      expect(creative_assets.length).to eq(original_count)
      expect(creative_assets.map(&:language)).to contain_exactly('en-US', 'ko')
    end
  end

  describe '#detect_languages' do
    it 'should detect languages from options[:languages]' do
      options = { languages: ['en-US', 'ko', 'ja'] }
      creative_assets = []

      allow(Deliver::Languages).to receive(:detect_languages).and_return(['en-US', 'ko', 'ja'])

      languages = uploader.send(:detect_languages, options, option_key, creative_assets)

      expect(languages).to contain_exactly('en-US', 'ko', 'ja')
    end

    it 'should include languages from existing creative assets' do
      options = { languages: ['en-US'] }
      ko_image = Deliver::CreativeAsset.new('/path/ko/header.jpg', 'ko')
      ja_image = Deliver::CreativeAsset.new('/path/ja/header.jpg', 'ja')
      creative_assets = [ko_image, ja_image]

      allow(Deliver::Languages).to receive(:detect_languages).and_return(['en-US'])

      languages = uploader.send(:detect_languages, options, option_key, creative_assets)

      expect(languages).to contain_exactly('en-US', 'ko', 'ja')
    end

    it 'should filter out nil and empty languages from creative assets' do
      options = { languages: ['en-US'] }
      nil_image = Deliver::CreativeAsset.new('/path/default/header.jpg', nil)
      en_image = Deliver::CreativeAsset.new('/path/en-US/header.jpg', 'en-US')
      creative_assets = [nil_image, en_image]

      allow(Deliver::Languages).to receive(:detect_languages).and_return(['en-US'])

      languages = uploader.send(:detect_languages, options, option_key, creative_assets)

      expect(languages).to contain_exactly('en-US')
    end
  end
end
