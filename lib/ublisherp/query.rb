module Ublisherp
  class Query
    delegate *(Array.instance_methods(false) - [:to_a, :to_ary, :frozen?]),
             to: :to_a

    attr_reader :klass

    def initialize(klass)
      @klass = klass
      @conditions = {}
    end

    def find(id, conditions = {})
      klass.find id, @conditions.merge(conditions)
    end

    def where(conditions)
      @result = nil
      @conditions.merge! conditions
      self
    end

    def to_a
      @result ||= klass.find_all(@conditions)
    end

    alias_method :to_ary, :to_a
  end
end
