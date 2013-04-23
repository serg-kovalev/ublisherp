require 'spec_helper'

describe Ublisherp::Model do

  it 'finds a single entity via ID' do
    SimpleContentItem.find(1)
  end

end
