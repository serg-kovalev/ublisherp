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

      if (self.if && !self.if.call(stream_obj)) ||
        (self.unless && self.unless.call(stream_obj))
        return false
      end

      return true
    end
  end
end
