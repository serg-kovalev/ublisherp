require 'securerandom'

module Ublisherp::Publishable
  extend ActiveSupport::Concern

#   module ClassMethods
#     def publish_associations(*assocs)
#       @publish_associations ||= []
#       if assocs.present?
#         @publish_associations.concat assocs
#       else
#         @publish_associations
#       end
#     end
#   end
  attr_accessor :publisher

  def publisher
    @publisher ||=
      begin
        "#{self.class.name}Publisher".constantize.new self
      rescue NameError
        Ublisherp::Publisher.new self
      end
  end

#   def publish!(**options)
#     publisher.publish!(**options)
#   end


#   def save_with_publish
#     save_without_publish
#     publisher.publish!
#   end

#   included do
#     alias_method_chain :save, :publish
#   end
end
