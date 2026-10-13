require_relative '../model'

module Spaceship
  class ConnectAPI
    class AppAssetLibrary
      include Spaceship::ConnectAPI::Model

      def self.type
        'appAssetLibraries'
      end

      #
      # API
      #

      def self.get(client: nil, app_id:, includes: nil)
        client ||= Spaceship::ConnectAPI
        resp = client.get_app_asset_library(app_id: app_id, includes: includes)
        return resp.to_models.first
      end

      def get_images(client: nil, filter: {}, includes: nil, limit: nil, sort: nil)
        client ||= Spaceship::ConnectAPI
        resps = client.get_app_asset_library_images(asset_library_id: id, filter: filter, includes: includes, limit: limit, sort: sort).all_pages
        return resps.flat_map(&:to_models)
      end
    end
  end
end
