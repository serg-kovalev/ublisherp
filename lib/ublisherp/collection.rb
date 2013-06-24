class Ublisherp::Collection < Array
  attr_accessor :has_more

  def has_more?
    !!has_more
  end
end
