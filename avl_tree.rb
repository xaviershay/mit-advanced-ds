require 'minitest/autorun'

class AvlTreeTest < MiniTest::Unit::TestCase
  def test_operations
    1.times do
      set   = AvlTree.new
      range = (0..5).to_a
      range.sort_by { rand }.each {|x| set.insert(x) }

      keep   = range[0..range.length/2]
      remove = range[range.length/2+1..-1]

#       remove.sort_by { rand }.each {|x| set.delete(x) }

      keep  .each { |x| assert  set.include?(x), "Did not include #{x}" }
#       remove.each { |x| assert !set.include?(x), "Did include #{x}" }

      draw(set, 'tree.png')
    end
  end
end

def draw(ds, filename)
  require 'graphviz'

  g = GraphViz::new("structs")

  ds.each do |node|
    p node
    g.add_nodes(node.object_id.to_s,
      "label" => "%i (%i)" % [node.value.to_s, node.balance]
    )

    edge = lambda do |subtree|
      g.add_edges(node.object_id.to_s, subtree.object_id.to_s)

      if subtree.empty?
        g.add_nodes(subtree.object_id.to_s,
                    "label" => "Empty")
      end
    end

    unless node.leaf?
      edge[node.left]
      edge[node.right]
    end
  end

  g.output(:png => filename)
end

class AvlTree
  class Node < Struct.new(:value, :parent, :left, :right, :balance)
    EMPTY = Class.new

    def self.empty(parent)
      new(EMPTY, parent)
    end

    def empty?
      value == EMPTY
    end

    def inspect
      return '-' if empty?

      buffer = "<#{value} #{balance} #{left.inspect} #{right.inspect}>"
    end

    def insert(x)
      return if x == value

      if empty?
        self.value   = x
        self.left    = Node.empty(self)
        self.right   = Node.empty(self)
        self.balance = 0
      else
        if x < value
          if left.insert(x)
            self.balance -= 1
            parent.rebalance(self, 1)
          end
        else
          if right.insert(x)
            self.balance += 1
            parent.rebalance(self, 1)
          end
        end
      end
    end

    def rebalance(child, d)
      self.balance += if child == right
        d
      else
        -d
      end
      self.parent.rebalance(self, d)
    end

    def include?(x)
      return false if empty?
      return true  if x == value

      subtree = if x < value
               left
             else
               right
             end
      subtree.include?(x)
    end

    def leaf?
      left.empty? && right.empty?
    end

    def each(&block)
      return if empty?

      yield self
      left.each(&block)
      right.each(&block)
    end
  end

  class PseudoRoot
    def rebalance(*args)
    end
  end

  def initialize
    @root = Node.empty(PseudoRoot.new)
  end

  def insert(x)
    @root.insert(x)
  end

  def include?(x)
    @root.include?(x)
  end

  def each(&block)
    @root.each(&block)
  end
end
