# Trying to implement partial persistence as described in
# http://courses.csail.mit.edu/6.851/spring12/lectures/L01.html
#
# First draft, probably not constant and does not support nesting.
class PartiallyPersistentArray
  attr_reader :current_version

  def initialize(array)
    @current_version = 0
    @roots           = [Node.new(array)]
  end

  def set(index, value)
    root = @roots[@current_version]

    @current_version += 1

    @roots[@current_version] = root.set(index, value, @current_version)
  end

  def get(version = current_version)
    @roots[version].get(version)
  end

private

  class Node
    def initialize(slots, max_mods = 20)
      @slots         = slots
      @modifications = []
      @max_mods      = max_mods
    end

    def set(index, value, version)
      @modifications << [version, index, value]

      if @modifications.length < @max_mods
        self
      else
        rebalance(version)
      end
    end

    def get(version)
      base = @slots.dup
      @modifications.each do |(v, i, x)|
        break if v > version
        base[i] = x
      end
      base
    end

  private

    def rebalance(version)
      Node.new(get(version))
    end
  end
end

describe 'partial persistence' do
  it 'round trips an array' do
    ds = PartiallyPersistentArray.new([1, 2])
    ds.get(0).should == [1, 2]
  end

  it 'updates a value in the array' do
    ds = PartiallyPersistentArray.new([1, 2])
    ds.set(1, 3)
    ds.get(0).should == [1, 2]
    ds.get(1).should == [1, 3]
  end

  it 'rebalances the array' do
    ds = PartiallyPersistentArray.new([0])
    (1..100).each do |x|
      ds.set(0, x)
    end
    (0..100).each do |x|
      ds.get(x).should == [x]
    end
  end
end
