require_relative '../model'
require_relative '../file_uploader'
require 'spaceship/globals'

module Spaceship
  class ConnectAPI
    class AppAssetLibraryImage
      include Spaceship::ConnectAPI::Model

      # Much of the functionality below is modified from `spaceship/connect_api/models/app_clip_header_image.rb`

      attr_accessor :category
      attr_accessor :created_date
      attr_accessor :last_modified_date
      attr_accessor :file_name
      attr_accessor :file_size
      attr_accessor :image_asset
      attr_accessor :reference_name
      attr_accessor :spec_id
      attr_accessor :state
      attr_accessor :state_details
      attr_accessor :upload_operations

      attr_mapping({
        "category" => "category",
        "createdDate" => "created_date",
        "lastModifiedDate" => "last_modified_date",
        "fileName" => "file_name",
        "fileSize" => "file_size",
        "imageAsset" => "image_asset",
        "referenceName" => "reference_name",
        "specId" => "spec_id",
        "state" => "state",
        "stateDetails" => "state_details",
        "uploadOperations" => "upload_operations"
      })

      module Category
        CREATIVE_ASSETS = "CREATIVE_ASSETS"
        APP_SCREENSHOTS_AND_PREVIEWS = "APP_SCREENSHOTS_AND_PREVIEWS"
      end

      module State
        AWAITING_UPLOAD = "AWAITING_UPLOAD"
        UPLOAD_COMPLETE = "UPLOAD_COMPLETE"
        FAILED = "FAILED"
        COMPLETE = "COMPLETE"
        PREPARE_FOR_SUBMISSION = "PREPARE_FOR_SUBMISSION"
        READY_FOR_REVIEW = "READY_FOR_REVIEW"
        WAITING_FOR_REVIEW = "WAITING_FOR_REVIEW"
        IN_REVIEW = "IN_REVIEW"
        ACCEPTED = "ACCEPTED"
        APPROVED = "APPROVED"
        REJECTED = "REJECTED"
        ARCHIVED = "ARCHIVED"
      end

      def self.type
        'appAssetLibraryImages'
      end

      # Still being uploaded or processed by Apple - not yet usable in a placement or review submission
      def processing?
        [State::AWAITING_UPLOAD, State::UPLOAD_COMPLETE].include?(state)
      end

      def failed?
        state == State::FAILED
      end

      def error_messages
        errors = (state_details || [])
        errors.map { |error| [error["code"], error["description"]].compact.join(" - ") }
      end

      # This does not download the source image (exact image that was uploaded)
      # This downloads a modified version.
      def image_asset_url(width: nil, height: nil, type: "png")
        return nil if image_asset.nil?

        template_url = image_asset["templateUrl"]
        width ||= image_asset["width"]
        height ||= image_asset["height"]

        return template_url
               .gsub("{w}", width.to_s)
               .gsub("{h}", height.to_s)
               .gsub("{f}", type)
      end

      #
      # API
      #

      def self.create(client: nil, asset_library_id:, path:, category: Category::CREATIVE_ASSETS, reference_name: nil, wait_for_processing: true)
        client ||= Spaceship::ConnectAPI
        require 'faraday'

        filename = File.basename(path)
        filesize = File.size(path)
        bytes = File.binread(path)

        post_attributes = {
          fileSize: filesize,
          fileName: filename,
          category: category,
          referenceName: reference_name
        }.compact

        # Create placeholder to upload the creative asset image
        begin
          app_asset_library_image = client.post_app_asset_library_image(
            asset_library_id: asset_library_id,
            attributes: post_attributes
          ).first
        rescue => error
          raise "Unable to create app asset library image reservation: #{error}"
        end

        # Upload the file
        upload_operations = app_asset_library_image.upload_operations
        Spaceship::ConnectAPI::FileUploader.upload(upload_operations, bytes)

        # Update file uploading complete
        patch_attributes = { uploaded: true }

        # Patch app asset library image that file upload is complete
        # Catch error if patch retries due to 504. Original patch
        # may go through by return response as 504.
        begin
          app_asset_library_image = Spaceship::ConnectAPI.patch_app_asset_library_image(
            app_asset_library_image_id: app_asset_library_image.id,
            attributes: patch_attributes
          ).first
        rescue => error
          puts("Failed to patch app asset library image. Update may have gone through so verifying") if Spaceship::Globals.verbose?

          app_asset_library_image = client.get_app_asset_library_image(app_asset_library_image_id: app_asset_library_image.id).first
          raise error if app_asset_library_image.processing?
        end

        # Wait for processing
        if wait_for_processing
          loop do
            unless app_asset_library_image.processing?
              if app_asset_library_image.failed?
                messages = ["Error processing app asset library image '#{app_asset_library_image.file_name}'"] + app_asset_library_image.error_messages
                raise messages.join(". ")
              end

              puts("App asset library image processing complete!") if Spaceship::Globals.verbose?
              break
            end

            # Poll every 2 seconds
            sleep_time = 2
            puts("Waiting #{sleep_time} seconds before checking status of processing...") if Spaceship::Globals.verbose?
            sleep(sleep_time)

            app_asset_library_image = client.get_app_asset_library_image(app_asset_library_image_id: app_asset_library_image.id).first
          end
        end

        return app_asset_library_image
      end

      def get_placements(client: nil, filter: {}, includes: nil, limit: nil, sort: nil)
        client ||= Spaceship::ConnectAPI
        resps = client.get_app_asset_library_image_placements(app_asset_library_image_id: id, filter: filter, includes: includes, limit: limit, sort: sort).all_pages
        return resps.flat_map(&:to_models)
      end

      def delete!(client: nil, filter: {}, includes: nil, limit: nil, sort: nil)
        client ||= Spaceship::ConnectAPI
        client.delete_app_asset_library_image(app_asset_library_image_id: id)
      end
    end
  end
end
