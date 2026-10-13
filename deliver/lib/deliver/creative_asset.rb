require_relative 'module'

module Deliver
  # CreativeAsset represents one App Store creative asset (e.g. a product page header or
  # App Store search results image) for one specific locale.
  class CreativeAsset
    attr_accessor :path
    attr_accessor :language

    # @param path (String) path to the creative asset file
    # @param language (String) Language of this creative asset (e.g. en-US)
    def initialize(path, language)
      self.path = path
      self.language = language
    end
  end
end
