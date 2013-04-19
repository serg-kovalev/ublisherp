require 'rubygems'
require 'bundler/setup'
Bundler.require

require 'securerandom'

def redis
  $redis ||= Redis.new
  $redis_ns ||= Redis::Namespace.new(:ublisherp, $redis)
end

def redis_clean
  redis.keys.each do |k|
    redis.del k
  end
end

module Storable
  extend ActiveSupport::Concern

  included do
    attr_accessor :id
  end

  def new_id
    SecureRandom.urlsafe_base64(16)
  end

  def save
    self.class.store[id] = self
  end

  module ClassMethods
    def store
      @store ||= {}
    end

    alias :all :store

    def [](id)
      store[id.to_s]
    end
  end
end


module Publishable
  extend ActiveSupport::Concern

  include Storable

  module ClassMethods
    def publish_associations(*assocs)
      @publish_associations ||= []
      if assocs.present?
        @publish_associations.concat assocs
      else
        @publish_associations
      end
    end
  end

  def publisher
    begin
      cls = "#{self.class.name}Publisher".constantize
    rescue NameError
      cls = Publisher
    end
    cls.new self
  end

  def publish!(**options)
    publisher.publish!(**options)
  end


  def save_with_publish
    save_without_publish
    publisher.publish!
  end

  included do
    alias_method_chain :save, :publish
  end
end


class Card
  include Storable
  include Publishable

  attr_accessor :title, :body, :created_at
  attr_reader :tags

  publish_associations :tags

  def initialize(title, body)
    @id = new_id
    @title = title
    @body = body
    @created_at = Time.now
    @tags = []
  end

  def add_tag(tag, attributes: {})
    tag_name = tag
    tag = Tag[tag.to_s] unless Tag === tag
    if tag.nil?
      tag = Tag.new(tag_name, attributes)
    end

    @tags << tag
    tag.cards << self
    tag
  end

  def as_json(**options)
    {id: id, title: title, body: body, tags: tags.map { |t| t.id }, created_at: created_at}
  end

end


class Tag
  include Storable
  include Publishable

  attr_accessor :name, :attributes

  def initialize(name, attributes: {})
    @id = name
    @name = name
    @attributes = attributes
  end

  def cards
    @cards ||= []
  end

  def as_json(**options)
    {id: id, name: name, attributes: attributes}
  end
end


class Publisher

  attr_reader :publishable

  def initialize(publishable)
    @publishable = publishable
  end

  def publish!(**options)
    redis.set publishable_key, publishable.to_json

    publishable_name = publishable.class.name.underscore.to_sym
    publishable.class.publish_associations.each do |assoc|
      Array(publishable.send(assoc)).each do |a|
        a.publish!(publishable_name => publishable)
      end
    end

    after_publish!(**options) if respond_to?(:after_publish!)
  end

  def publishable_key
    "#{publishable.class.name}:#{publishable.id}"
  end
end


class TagPublisher < Publisher
  def after_publish!(card: nil)
    if card && @publishable.cards.include?(card)
      redis.zadd tag_stream_key, card.created_at.to_f,
                 card.publisher.publishable_key
    end
  end

  def tag_stream_key
    "streams:#{@publishable.id}"
  end
end

redis_clean

c = Card.new('Hello', 'there')
c.add_tag 'cheese'
c.add_tag 'region/north'
c.save

binding.pry

