require 'securerandom'

module Ublisherp::Publishable
  extend ActiveSupport::Concern

  module ClassMethods
    def publish_associations(assocs = [])
      (@publish_associations ||= []
        ).concat assocs
    end
  end

  def publisher
    @publisher ||=
      begin
        "#{self.class.name}Publisher".constantize.new self
      rescue NameError
        Ublisherp::Publisher.new self
      end
  end

  def publish!(**options)
    publisher.publish!(**options)
  end
end
