require 'fastlane_core'
require 'spaceship/tunes/tunes'

require_relative 'module'
require_relative 'loader'
require_relative 'languages'

module Deliver
  # Uploads the new App Store creative assets (product page header and App Store search results
  # images) introduced with the App Asset Library API.
  #
  # Unlike screenshots, these assets are not attached directly to a locale - instead an image is
  # uploaded once to the app's asset library, and then a "placement" links that image to a specific
  # `AppStoreVersionLocalization` for a given placement type (e.g. the product page header). Newly
  # created images also need to be approved by Apple (via a review submission) before the placement
  # becomes visible on the App Store - see `Deliver::SubmitForReview`.
  class UploadCreativeAssets
    UploadCreativeAssetJob = Struct.new(:path, :localization)

    # Apple also accepts a single 5244x2950 (16:9) "universal" image for either placement - see
    # https://developer.apple.com/help/app-store-connect/reference/app-information/creative-assets-specifications
    UNIVERSAL_ASSET_SIZE = "5244x2950".freeze

    PLACEMENT_CONFIGS = {
      product_page_header_path: {
        placement_type: Spaceship::ConnectAPI::AppAssetLibraryPlacement::PlacementType::PRODUCT_PAGE_HEADER_ASSET,
        asset_name: "product page header image",
        valid_sizes: ["3840x1646", UNIVERSAL_ASSET_SIZE]
      },
      app_store_search_results_asset_path: {
        placement_type: Spaceship::ConnectAPI::AppAssetLibraryPlacement::PlacementType::APP_STORE_SEARCH_RESULTS_ASSET,
        asset_name: "App Store search results image",
        valid_sizes: [UNIVERSAL_ASSET_SIZE],
        size_range: { min_width: 1920, max_width: 3840, min_height: 1280, max_height: 2560 }
      }
    }.freeze

    def find_and_upload(options)
      return if options[:edit_live]

      configs = PLACEMENT_CONFIGS.select { |option_key, _| options[option_key] }
      return if configs.empty?

      app = Deliver.cache[:app]

      asset_library = app.get_app_asset_library
      UI.user_error!("Could not find the App Store Connect asset library for app '#{app.name}'") unless asset_library

      platform = Spaceship::ConnectAPI::Platform.map(options[:platform])
      version = app.get_edit_app_store_version(platform: platform)
      UI.user_error!("Could not find a version to edit for app '#{app.name}' for '#{platform}'") unless version

      localizations = version.get_app_store_version_localizations

      configs.each do |option_key, config|
        creative_assets = collect_creative_assets(options, option_key, config)
        next if creative_assets.empty?

        UI.important("Will begin uploading #{config[:asset_name]}s for '#{version.version_string}' on App Store Connect")
        upload(asset_library, localizations, creative_assets, config)
      end
    end

    def upload(asset_library, localizations, creative_assets, config)
      worker = FastlaneCore::QueueWorker.new do |job|
        begin
          UI.verbose("[#{job.localization.locale}] Uploading '#{job.path}'...")
          start_time = Time.now

          image = Spaceship::ConnectAPI::AppAssetLibraryImage.create(
            asset_library_id: asset_library.id,
            path: job.path,
            wait_for_processing: true
          )

          Spaceship::ConnectAPI::AppAssetLibraryPlacement.create(
            placement_type: config[:placement_type],
            image_id: image.id,
            app_store_version_localization_id: job.localization.id
          )

          Deliver.cache[:pending_asset_library_image_ids] ||= []
          Deliver.cache[:pending_asset_library_image_ids] << image.id

          UI.message("Uploaded '#{job.path}'... (#{Time.now - start_time} secs)")
        rescue => error
          UI.error(error)
        end
      end

      creative_assets.each do |creative_asset|
        localization = localizations.find { |l| l.locale.eql?(creative_asset.language) }
        unless localization
          UI.error("Could not find localization for '#{creative_asset.language}' - make sure metadata or screenshots for this language have already been uploaded")
          next
        end

        worker.enqueue(UploadCreativeAssetJob.new(creative_asset.path, localization))
      end

      worker.start

      UI.message("Successfully uploaded #{config[:asset_name]}s to App Store Connect")
    end

    def collect_creative_assets(options, option_key, config)
      creative_assets = Loader.load_creative_assets(
        options[option_key],
        options[:ignore_language_directory_validation],
        asset_name: config[:asset_name],
        valid_sizes: config[:valid_sizes] || [],
        size_range: config[:size_range]
      )

      # Apply default folder logic similar to metadata/app clip header images
      assign_default_images(options, option_key, creative_assets)

      creative_assets
    end

    # If the user has a 'default' language folder, assign that image to languages that don't have one
    def assign_default_images(options, option_key, creative_assets)
      enabled_languages = detect_languages(options, option_key, creative_assets)

      default_image = creative_assets.find do |creative_asset|
        File.basename(File.dirname(creative_asset.path)).casecmp?("default")
      end
      return unless default_image

      enabled_languages.each do |language|
        next if language&.casecmp?("default")

        existing_image = creative_assets.find { |creative_asset| creative_asset.language.eql?(language) }
        unless existing_image
          UI.message("Using default folder image for language '#{language}'")
          creative_assets << Deliver::CreativeAsset.new(default_image.path, language)
        end
      end

      # Remove the default image from the list (language is nil for default folder)
      creative_assets.reject! { |creative_asset| creative_asset.language.nil? }
    end

    def detect_languages(options, option_key, creative_assets)
      enabled_languages = Languages.detect_languages(
        options: options,
        metadata_path: options[option_key],
        ignore_validation: options[:ignore_language_directory_validation]
      )

      creative_assets.each do |creative_asset|
        language = creative_asset.language
        next if language.nil? || language.empty?
        enabled_languages << language unless enabled_languages.include?(language)
      end

      enabled_languages.uniq
    end
  end
end
