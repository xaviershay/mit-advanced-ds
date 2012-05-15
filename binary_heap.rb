# A heap is a common implementation of a priority queue. It stores a list of
# elements, and enables the "highest priority" element to be pulled off the
# list.

# A binary heap is a priority queue implemented using a binary tree. Each node
# of the tree satifies the *heap property*, namely that the value of each node
# is greater than all of its children. In this implementation, "greater" is
# abstract and can be any comparison function. For a min-heap, the "greatest"
# value in this terminology will actually be the smallest number.
class BinaryHeap

  # ## Overview
  #
  # Internally, the heap is able to efficiently store the binary tree as an
  # array since the tree will conform to the "shape property", meaning it will
  # be fully filled and not unbalanced. The top of the heap is the first
  # element in the heap, the bottom is the last. This format is explained
  # further below.
  def initialize(comparator)
    @comparator = comparator
    @data       = []
  end

  # Adding a value to the heap begins by placing the value at the bottom of the
  # heap. At this point, it is possible that the data structure violates the
  # *heap property*, since the new value may be greater than some of its
  # parents.  To fix this, the value is "bubbled" up to the correct location by
  # recursively swapping it with its immediate parent for as long as it is
  # greater than that parent.
  #
  # In the worst case of adding a value that is to be the new greatest value,
  # this will take _log n_ time, since one swap is required for every level of
  # the tree to get the value from the bottom to the top (the height of a
  # binary tree is by definition _log n_).
  def <<(x)
    i        = length
    @data[i] = x

    bubble_up(i)

    self
  end

  # Removing the top element from the heap is mostly symmetric to insertion.
  # The trick to rebalance the tree is to fill the hole left by removing the
  # top element with the bottom element in the heap.  As with insertion, the
  # structure is now in a state where the *heap property* may be violated, so
  # this new value is recursively bubbled _down_ so long as any immediate child
  # is greater than it.
  #
  # Once again, the worst case bound for this operation is `log n`, since if
  # the bottom element in the heap indeed belongs there it will need to swap
  # places with every level in the tree to get back down after it is promoted
  # to the top.
  def pop
    value    = top
    @data[0] = @data.pop

    bubble_down(0)

    value
  end

  # Both `length` and `top` are trivial constant time operations.
  def length
    @data.length
  end

  def top
    @data[0]
  end

  private

  # ## Details
  #
  # A complete binary tree can be stored in an array by flattening it level by
  # level, left to right. Each level contains twice as many values, so the
  # distribution of levels will look like:
  #
  #     [0 1 1 2 2 2 2 3 3 3 3 3 3 3 3]
  #
  # The root of the tree is at index 0, its left child at 1, right at 2, then
  # the left most child of the second level is stored at index 3.
  #
  # Given a value at index _i_, the left child can be found at _2i+1_ and the
  # right at _2i+2_. This can be intuited since the children for _i_ will be
  # found *after* all the children for its predecessors, and each predecessor
  # has two children. Try the calculations on the above array to prove to
  # yourself that it works.
  #
  # The algorithm to bubble down a value from the top of the heap to its
  # appropriate level falls out nicely. Starting at the top, if the value is
  # *not* greater than both children it is swapped with the larger of those
  # children, therefore satisfying the heap property for this level of the
  # tree. This process is repeated, following the value down the tree, until
  # either it is greater than both children or it reaches the bottom.
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

  # Bubbling a value up from the bottom of the heap is simpler than bubbling
  # down since only a single comparison against the parent is required. If the
  # parent is greater, the algorithm terminates. Otherwise, the two are
  # switched and the process continues up the tree.
  #
  # Calculating the parent index is a single equation for both left and right
  # children, since integer division will floor both results.
  def bubble_up(i)
    while i != 0
      parent = (i-1)/2

      if compare(i, parent)
        swap!(i, parent)
      end
      i = parent
    end
  end

  # Comparing elements returns `true` if `lhs` is greater than `rhs`. At the
  # bottom of the heap where `rhs` would fall beyond the end of the data
  # structure, `true` is returned to indicate that the `lhs` is by default the
  # greater value.
  def compare(lhs, rhs)
    return true if rhs >= @data.length

    @data[lhs].send(@comparator, @data[rhs])
  end

  def swap!(a, b)
    @data[a], @data[b] = @data[b], @data[a]
  end

end

# ## Usage
#
# These subclasses show that the above algorithm supports arbitrary comparison
# operations, in this case both a min-heap and a max-heap.
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

# Quick-check style specs that ensure the heap property invariant is
# upheld regardless of the sequence of input. Enough elements to fill at least
# four levels of the tree are used to ensure that the `bubble_up` and
# `bubble_down` methods are tested sufficiently.
require 'rspec'

elements = (1..2 ** 4).to_a

describe MaxHeap do
  15.times.map {elements.sort_by{rand}}.each do |example|
    it "always pops maximum value for #{example}" do
      heap = MaxHeap.new
      example.each {|x| heap << x }
      elements.reverse.each do |x|
        heap.top.should == x
        heap.pop.should == x
      end
    end
  end

  it 'allows duplicate values' do
    heap = MaxHeap.new
    heap << 1 << 1
    heap.pop.should == 1
    heap.pop.should == 1
  end
end

describe MinHeap do
  15.times.map {elements.sort_by{rand}}.each do |example|
    it "always pops minimum value for #{example}" do
      heap = MinHeap.new
      example.each {|x| heap << x }
      elements.each do |x|
        heap.top.should == x
        heap.pop.should == x
      end
    end
  end

  it 'allows duplicate values' do
    heap = MinHeap.new
    heap << 1 << 1
    heap.pop.should == 1
    heap.pop.should == 1
  end
end
