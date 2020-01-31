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
        break if index >= @limit && @limit.positive?
        yield data[index]
      else
        break if records_fetched == records_total || records_fetched == @limit

        index = 0
        @page_size = if (records_fetched + @page_size) > @limit && @limit.positive?
                       @limit - records_fetched
                     else
                       @page_size
                     end
        result = pull_data(records_fetched + @offset, @page_size, **@filters)
        data = result[:data]
        records_fetched += result[:data].length
        records_total = result[:records_total]
        records_filtered = result[:records_filtered]
        break if data.count.zero?
        yield data[index]
      end
    end
  end

  def pull_data(offset, page_size, **filters)
    retries = ENV['MAX_RETRIES'] || 3

    retries.to_i.times do |t|
      begin
        result = APIClient.get_next_orders(offset, page_size, filters)
        result[:data] ||= []
      rescue Errno::ECONNREFUSED => e
        next unless t < retries
        raise e
      end

      return result unless result.nil?
    end
  end
end

describe OrderCollection do
  let(:offset) { 0 }
  let(:offset_index) { offset + 1 }
  let(:limit) { -1 }
  let(:page_size) { 10 }
  let(:filters) { {} }

  let(:records_total) { 100 }
  let(:records_filtered) { 100 }
  let(:data) { (1..records_filtered).to_a }
  let(:items) { OrderCollection.new(offset, limit, page_size, **filters) }

  before(:each) do
    allow(APIClient).to receive(:get_next_orders) do |start, length|
        {
            data: data.to_a[start,length],
            records_total: records_total,
            records_filtered: records_filtered
        }
    end
  end

  context "when not using filters" do
    it "should return all orders" do
      expect(items.to_a).to eq((1..records_total).to_a)
    end

    context "when using a position (offset)" do
      let(:offset) { 85 }

      it "only returns records after the offset" do
        expect(items.to_a).to eq((offset_index..records_total).to_a)
      end
    end

    context "when using a position and a limit" do
      let(:offset) { 25 }
      let(:limit) { 50 }

      it "only returns records after the offset and before the limit" do
        expect(items.to_a).to eq((offset_index..(offset+limit)).to_a)
      end
    end

    context "when using a page size" do
      let(:page_size) { 20 }
      let(:request_count) { records_total / page_size }

      it "calls n times only based on batch size" do
        expect(APIClient).to receive(:get_next_orders).exactly(request_count).times
        items.to_a
      end
    end

    context "when using a limit and page size" do
      let(:limit) { 50 }
      let(:page_size) { 20 }
      let(:request_count) { (limit.to_f / page_size.to_f).ceil }

      it "calls n times only based on batch size" do
        expect(APIClient).to receive(:get_next_orders).exactly(request_count).times
        items.to_a
      end
    end
  end

  context "when a filter is being used" do
    let(:records_filtered) { 50 }
    let(:data) { (1..records_filtered).to_a }
    let(:filters) { { some_filter: "some_value" } }

    it "should return 50 orders" do
      expect(items.to_a).to eq((1..records_filtered).to_a)
    end

    context "when there are just a few records left" do
      let(:records_filtered) { 78 }
      let(:offset) { 75 }

      it "only pulls the remaining" do
        expect(items.to_a).to eq((offset_index..records_filtered).to_a)
      end
    end
  end

  context "when an external error happens" do
   before(:each) do
     allow(APIClient).to receive(:get_next_orders).and_raise(Errno::ECONNREFUSED)
   end

   it "raises expected error" do
     expect{ items.to_a }.to raise_error(Errno::ECONNREFUSED, "Connection refused")
   end
  end
end
