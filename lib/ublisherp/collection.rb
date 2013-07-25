class Ublisherp::Collection < Array
  attr_accessor :has_more

  def has_more?
    !!has_more
  end

  def insert_not_past_end(i, *objs)
    if i > size
      concat objs
    else
      insert i, *objs
    end
  end
end
