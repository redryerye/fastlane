require_relative '../model'

module Spaceship
  class ConnectAPI
    class AppAssetLibraryPlacement
      include Spaceship::ConnectAPI::Model

      attr_accessor :media_type
      attr_accessor :placement_type
      attr_accessor :placement_group
      attr_accessor :created_date
      attr_accessor :last_modified_date
      attr_accessor :state
      attr_accessor :state_details

      attr_mapping({
        "mediaType" => "media_type",
        "placementType" => "placement_type",
        "placementGroup" => "placement_group",
        "createdDate" => "created_date",
        "lastModifiedDate" => "last_modified_date",
        "state" => "state",
        "stateDetails" => "state_details"
      })

      module PlacementType
        APP_SCREENSHOT = "APP_SCREENSHOT"
        IMESSAGE_APP_SCREENSHOT = "IMESSAGE_APP_SCREENSHOT"
        APP_PREVIEW = "APP_PREVIEW"
        PRODUCT_PAGE_HEADER_ASSET = "PRODUCT_PAGE_HEADER_ASSET"
        APP_STORE_SEARCH_RESULTS_ASSET = "APP_STORE_SEARCH_RESULTS_ASSET"
        SEARCH_RESULTS_ADS_ASSET = "SEARCH_RESULTS_ADS_ASSET"
        TODAY_TAB_ADS_ASSET = "TODAY_TAB_ADS_ASSET"
        EVENT_CARD_ASSET = "EVENT_CARD_ASSET"
        EVENT_DETAILS_PAGE_ASSET = "EVENT_DETAILS_PAGE_ASSET"
        RETENTION_MESSAGE_ASSET = "RETENTION_MESSAGE_ASSET"
      end

      def self.type
        'appAssetLibraryPlacements'
      end

      #
      # API
      #

      # Links an already-uploaded appAssetLibraryImage (or appAssetLibraryVideo) to exactly one
      # of an app's localizations so it renders in the given `placement_type` (e.g. the product
      # page header or App Store search results).
      def self.create(client: nil, placement_type:, image_id: nil, video_id: nil, placement_group: nil,
                      app_store_version_localization_id: nil, app_custom_product_page_localization_id: nil,
                      app_event_localization_id: nil, app_store_version_experiment_treatment_localization_id: nil)
        client ||= Spaceship::ConnectAPI

        attributes = {
          placementType: placement_type,
          placementGroup: placement_group
        }.compact

        relationships = {}

        if image_id
          relationships[:image] = { data: { type: "appAssetLibraryImages", id: image_id } }
        elsif video_id
          relationships[:video] = { data: { type: "appAssetLibraryVideos", id: video_id } }
        else
          raise "Either image_id or video_id is required to create an app asset library placement"
        end

        if app_store_version_localization_id
          relationships[:appStoreVersionLocalization] = { data: { type: "appStoreVersionLocalizations", id: app_store_version_localization_id } }
        elsif app_custom_product_page_localization_id
          relationships[:appCustomProductPageLocalization] = { data: { type: "appCustomProductPageLocalizations", id: app_custom_product_page_localization_id } }
        elsif app_event_localization_id
          relationships[:appEventLocalization] = { data: { type: "appEventLocalizations", id: app_event_localization_id } }
        elsif app_store_version_experiment_treatment_localization_id
          relationships[:appStoreVersionExperimentTreatmentLocalization] = { data: { type: "appStoreVersionExperimentTreatmentLocalizations", id: app_store_version_experiment_treatment_localization_id } }
        else
          raise "A localization (app_store_version_localization_id, app_custom_product_page_localization_id, app_event_localization_id or app_store_version_experiment_treatment_localization_id) is required to create an app asset library placement"
        end

        resp = client.post_app_asset_library_placement(attributes: attributes, relationships: relationships)
        return resp.to_models.first
      end

      def delete!(client: nil)
        client ||= Spaceship::ConnectAPI
        client.delete_app_asset_library_placement(app_asset_library_placement_id: id)
      end
    end
  end
end
