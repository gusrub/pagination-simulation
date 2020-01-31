require "rspec/autorun"
require "byebug"

class APIClient
    def self.get_next_orders(start=0, length=10, **filters)
      """
          Fetch the next set of orders from the queue.
          Optionally you can filter for specific types of orders.
      """
    end
end

class OrderCollection
  include Enumerable

  def initialize(offset=0, limit=-1, page_size=10, **filters)
    @offset = offset
    @limit = limit
    @page_size = page_size
    @filters = filters
  end

  def each
    records_fetched = 0
    records_total = -1
    records_filtered = -1
    data = []
    index = 0

    loop do
      if (index += 1) < data.length
        yield data[index]
      else
        break if records_fetched == records_total || records_fetched == @limit

        index = 0
        result = APIClient.get_next_orders records_fetched + @offset, @page_size, **@filters
        data = result[:data]
        records_fetched += result[:data].length
        records_total = result[:records_total]
        records_filtered = result[:records_filtered]
        break if data.count.zero?
        yield data[index]
      end
    end
  end
end

describe OrderCollection do
    it "should return 100 orders" do
      allow(APIClient).to receive(:get_next_orders) do |start, length|
          {
              data: (1..100).to_a[start,length],
              records_total: 100,
              records_filtered: 100
          }
      end

      items = OrderCollection.new()

      expect(items.to_a).to eq((1..100).to_a)
    end

    it "should return 50 orders" do
      allow(APIClient).to receive(:get_next_orders) do |start, length|
          {
              data: (1..50).to_a[start,length],
              records_total: 100,
              records_filtered: 50
          }
      end

      items = OrderCollection.new(0, 50)
      expect(items.to_a).to eq((1..50).to_a)
    end
end
