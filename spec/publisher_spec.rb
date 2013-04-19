require 'spec_helper'
require 'ublisherp'

describe Publisher do

  let :card do
    Card.new('title', 'body')
  end

  it 'does things' do
    expect(card).to be_true
    expect(Publisher.new(card)).to be_true
  end
end
