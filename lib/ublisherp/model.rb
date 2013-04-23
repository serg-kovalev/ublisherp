class Ublisherp::Model < OpenStruct
  include Ublisherp
  
  def self.find(id)
    Ublisherp.redis.get RedisKeys.key_for(self, id: id) 
  end
end
