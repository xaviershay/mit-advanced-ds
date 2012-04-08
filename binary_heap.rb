class BinaryHeap
  def initialize(comparator)
    @comparator = comparator
    @data       = []
  end

  def below?(x)
    @data.empty? || top.send(@comparator, x)
  end

  def pop
    i        = 0
    value    = @data[i]
    @data[i] = @data.pop

    bubble_down(i)

    value
  end

  def <<(x)
    i        = length
    @data[i] = x

    bubble_up(i)

    self
  end

  def length
    @data.length
  end

  def top
    if @comparator == :>
      @data.max
    else
      @data.min
    end
  end

  private

  def swap!(a, b)
    @data[a], @data[b] = @data[b], @data[a]
  end

  def compare(lhs, rhs)
    return true unless rhs < @data.length

    @data[lhs].send(@comparator, @data[rhs])
  end

  def bubble_up(i)
    while i != 0
      parent = i/2
      if compare(i, parent)
        swap!(i, parent)
      end
      i = parent
    end
  end

  def bubble_down(i)
    while true
      left  = 2*i + 1
      right = 2*i + 2

      child = compare(left, right) ? left : right

      if !compare(i, child)
        swap!(i, child)
        i = child
      else
        break
      end
    end
  end
end

class MaxHeap < BinaryHeap
  def initialize
    super(:>)
  end
end

class MinHeap < BinaryHeap
  def initialize
    super(:<)
  end
end

require 'rspec'

describe MaxHeap do
  15.times.map {(1..9).to_a.sort_by{rand}}.each do |example|
    it "always pops maximum value for #{example}" do
      heap = MaxHeap.new
      example.each {|x| heap << x }
      heap.top.should == 9
      heap.pop.should == 9
      heap.top.should == 8
    end
  end

  it 'allows duplicate values' do
    heap = MaxHeap.new
    heap << 1
    heap << 1
    heap.pop.should == 1
    heap.pop.should == 1
  end
end

describe MinHeap do
  15.times.map {(1..9).to_a.sort_by{rand}}.each do |example|
    it "always pops minimum value for #{example}" do
      heap = MinHeap.new
      example.each {|x| heap << x }
      heap.top.should == 1
      heap.pop.should == 1
      heap.top.should == 2
    end
  end

  it 'allows duplicate values' do
    heap = MinHeap.new
    heap << 1 << 1
    heap.pop.should == 1
    heap.pop.should == 1
  end
end
