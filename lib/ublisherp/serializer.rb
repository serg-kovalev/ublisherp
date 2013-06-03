module Ublisherp::Serializer
  OPTIONS = { symbolize_keys: true, pretty: false }

  def self.dump(obj)
    MultiJson.dump obj, OPTIONS
  end

  def self.load(obj)
    MultiJson.load obj, OPTIONS
  end
end
