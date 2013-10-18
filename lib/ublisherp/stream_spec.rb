require 'ostruct'

module Ublisherp
  class StreamSpec < OpenStruct
    class_attribute :stream_class_name
    self.stream_class_name = "Ublisherp::Stream"

    def for_publishable(p)
      stream_class_name.constantize.new(to_h.merge(publishable: p))
    end

    def add_to_stream?(stream_obj)
      classes = Array(self[:class]).map { |c|
        c.is_a?(Class) ? c : c.to_s.constantize
      }
      if classes.present? && !classes.any? { |cls| cls === stream_obj }
        return false
      end

      if (self.if && !self.publishable.instance_exec(stream_obj, &self.if)) ||
        (self.unless && self.publishable.instance_exec(stream_obj, &self.unless))
        return false
      end

      return true
    end
  end

  class TypeStreamSpec < StreamSpec
    self.stream_class_name = "Ublisherp::TypeStream"
  end
end
