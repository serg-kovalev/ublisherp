require 'rubygems'
require 'bundler/setup'
Bundler.require

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

#   def publisher
#     begin
#       cls = "#{self.class.name}Publisher".constantize
#     rescue NameError
#       cls = Publisher
#     end
#     cls.new self
#   end

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


