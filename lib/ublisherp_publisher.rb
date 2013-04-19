class Ublisherp::Publisher

  attr_reader :publishable

  def initialize(publishable)
    @publishable = publishable
  end

#   def publish!(**options)
#     redis.set publishable_key, publishable.to_json

#     publishable_name = publishable.class.name.underscore.to_sym
#     publishable.class.publish_associations.each do |assoc|
#       Array(publishable.send(assoc)).each do |a|
#         a.publish!(publishable_name => publishable)
#       end
#     end

#     after_publish!(**options) if respond_to?(:after_publish!)
#   end

#   def publishable_key
#     "#{publishable.class.name}:#{publishable.id}"
#   end
  
end
