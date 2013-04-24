class ActiveRecord::Base
  after_save do
    attributes.each do |k, v|
      if Time === attributes[k]
        write_attribute(k, attributes[k].round(0))
      end
    end
  end
end
