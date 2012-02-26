# A binary tree is a fundamental data structure. Countless variations of it has
# been formulated, the version here is the simplest.

require 'minitest/autorun'

# To demonstrate the algorithm, three set operations are implemented: insert,
# delete, and include.
class BinaryTreeTest < MiniTest::Unit::TestCase
  def test_operations
    50.times do
      set   = BinaryTree.new
      range = (0..50).to_a
      range.sort_by { rand }.each {|x| set.insert(x) }

      keep   = range[0..range.length/2]
      remove = range[range.length/2+1..-1]

      remove.sort_by { rand }.each {|x| set.delete(x) }

      keep  .each { |x| assert  set.include?(x), "Did not include #{x}" }
      remove.each { |x| assert !set.include?(x), "Did include #{x}" }
    end
  end
end

class BinaryTree
  class Node < Struct.new(:value, :left, :right)
    EMPTY = Class.new

    def empty?; self.value == EMPTY; end

    def self.empty
      new(EMPTY)
    end

    def insert(x)
      return if x == value

      if empty?
        self.value = x
        self.left  = Node.empty
        self.right = Node.empty
      else
        if x < value
          left.insert(x)
        else
          right.insert(x)
        end
      end
    end

    def include?(x)
      return false if empty?
      return true  if x == value

      if x < value
        left.include?(x)
      else
        right.include?(x)
      end
    end

    def delete(x)
      return if empty?

      if x == value
        raise "Traversed too far"
      elsif right.value == x
        self.right = right.promote(x)
      elsif left.value == x
        self.left = left.promote(x)
      elsif x < value
        left.delete(x)
      else
        right.delete(x)
      end
    end

    def promote(x)
      if left.empty? && right.empty?
        Node.empty
      elsif right.empty?
        left
      elsif left.empty?
        right
      else
        leaf = right.minimum
        self.value = leaf.value
        leaf.value = EMPTY
        self
      end
    end

    def inspect
      return '-' if empty?

      buffer = "<#{value} #{left.inspect} #{right.inspect}>"
    end

    def minimum
      if left.empty?
        self
      else
        left.minimum
      end
    end

    def leaf?
      left.empty? && right.empty?
    end
  end

  def initialize
    @root = Node.empty
  end

  def insert(x)
    root.insert(x)
  end

  def delete(x)
    if root.value == x
      @root = root.promote(x)
    else
      root.delete(x)
    end
  end

  def include?(x)
    root.include?(x)
  end

private
  attr_accessor :root
end
