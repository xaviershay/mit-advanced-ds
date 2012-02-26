require 'minitest/autorun'
require 'minitest/benchmark'

class TreeTest < MiniTest::Unit::TestCase
  def test_simple
    set = BinaryTree.new
    set.insert(7)
    set.insert(3)
    set.insert(9)
    assert  set.include?(3)
    assert !set.include?(8)
  end

  def test_quickcheck
    set = BinaryTree.new
    range = (0..100).to_a
    range.sort_by { rand }.each do |x|
      set.insert(x)
    end

    range.each do |x|
      assert set.include?(x), "Did not include #{x}"
    end
    assert !set.include?(-1)
    assert !set.include?(101)
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

    def inspect
      return '-' if empty?

      buffer = "<#{value} #{left.inspect} #{right.inspect}>"
    end
  end

  def initialize
    @root = Node.empty
  end

  def insert(x)
    root.insert(x)
  end

  def include?(x)
    root.include?(x)
  end

private
  attr_accessor :root
end
