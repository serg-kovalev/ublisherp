require 'ostruct'

module Ublisherp
  class StreamSpec < OpenStruct

    def for_publishable(p)
      Stream.new(to_h.merge(publishable: p))
    end

    def classes
      Array(self[:class])
    end

    def add_to_stream?(stream_obj)
      if self.classes.present? && !self.classes.any? { |cls| cls === stream_obj }
        return false
      end

      if (self.if && !self.publishable.instance_exec(stream_obj, &self.if)) ||
        (self.unless && self.publishable.instance_exec(stream_obj, &self.unless))
        return false
      end

      return true
    end
  end
end
