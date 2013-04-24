module Ublisherp::Serializer
  def self.options
    { :symbolize_keys => true, :pretty => false, :adapter => :oj }
  end

  def self.dump(obj)
    MultiJson.dump obj, options
  end

  def self.load(obj)
    MultiJson.load obj, options
  end
end
