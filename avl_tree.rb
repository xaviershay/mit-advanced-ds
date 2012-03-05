require 'minitest/autorun'

class AvlTreeTest < MiniTest::Unit::TestCase
  def test_operations
    10.times do
      ds   = AvlTree.new
      range = (0..50).to_a
      range.sort_by { rand }.each {|x| ds.insert(x) }

      keep   = range[0..range.length/2]
      remove = range[range.length/2+1..-1]

#       remove.sort_by { rand }.each {|x| ds.delete(x) }

      keep  .each { |x| assert  ds.include?(x), "Did not include #{x}" }
#       remove.each { |x| assert !ds.include?(x), "Did include #{x}" }

#       draw(ds, 'tree.png')

      assert_correct_balance_factors ds
      assert_balanced ds
    end
  end

  def test_right_right_rebalance_from_root
    ds = AvlTree.new
    ds.insert(3)
    ds.insert(4)
    ds.insert(5)

    assert_correct_balance_factors ds
    assert_balanced ds
  end

  def test_left_left_rebalance_from_root
    ds = AvlTree.new
    ds.insert(5)
    ds.insert(4)
    ds.insert(3)

    assert_correct_balance_factors ds
    assert_balanced ds
  end

  def test_left_right_rebalance_from_root
    ds = AvlTree.new
    ds.insert(5)
    ds.insert(3)
    ds.insert(4)

    assert_correct_balance_factors ds
    assert_balanced ds
  end

  def test_right_left_rebalance_from_root
    ds = AvlTree.new
    ds.insert(3)
    ds.insert(5)
    ds.insert(4)

    assert_correct_balance_factors ds
    assert_balanced ds
  end

  def assert_correct_balance_factors(ds)
    ds.each do |node|
      assert_equal node.left.height - node.right.height,
        node.balance,
        "Node #{node.inspect} balance factor incorrect"
    end
  end

  def assert_balanced(ds)
    ds.each do |node|
      balance = node.left.height - node.right.height
      assert balance.abs <= 1, "Node #{node.inspect} is not balanced"
    end
  end
end

def draw(ds, filename)
  require 'graphviz'

  g = GraphViz::new("structs")

  ds.each do |node|
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
  class Node < Struct.new(:value, :parent, :left, :right)
    EMPTY = Class.new

    def self.empty(parent)
      new(EMPTY, parent)
    end

    def empty?
      value == EMPTY
    end

    def inspect
      return '-' if empty?

      buffer = "<#{value} #{left.inspect} #{right.inspect}>"
    end

    def insert(x)
      return if x == value

      if empty?
        self.value = x
        self.left  = Node.empty(self)
        self.right = Node.empty(self)

        rebalance(self.parent)
      else
        if x < value
          left.insert(x)
        else
          right.insert(x)
        end
      end
    end

    def height
      if empty?
        1
      else
        1 + [left.height, right.height].max
      end
    end

    def balance
      left.height - right.height
    end

    def rotate_right
      parent   = self.parent
      old_head = self
      new_head = left
      transfer = new_head.right

      old_head.left   = transfer
      transfer.parent = old_head

      new_head.right  = old_head
      old_head.parent = new_head

      parent.replace(old_head, new_head)
    end

    def rotate_left
      parent    = self.parent
      old_head  = self
      new_head  = right
      transfer  = new_head.left

      old_head.right   = transfer
      transfer.parent = old_head

      new_head.left  = old_head
      old_head.parent = new_head

      parent.replace(old_head, new_head)
    end

    def replace(old, new)
      if old == left
        self.left = new
      else
        self.right = new
      end
      new.parent = self
    end

    def rebalance(child)
      parent = self.parent

      if balance == 2
        if left.balance == 1
          rotate_right
        elsif left.balance == -1
          left.rotate_left
          rotate_right
        end
      end

      if balance == -2
        if right.balance == -1
          rotate_left
        elsif right.balance == 1
          right.rotate_right
          rotate_left
        end
      end

      parent.rebalance(self)
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

    def each(h = 0, &block)
      enum = Enumerator.new do |yielder|
        unless empty?
          yielder.yield self, h
          left.each(h+1)  {|x, h| yielder.yield x, h }
          right.each(h+1) {|x, h| yielder.yield x, h }
        end
      end

      if block
        enum.each(&block)
      else
        enum
      end
    end
  end

  class PseudoRoot < Struct.new(:node)
    def rebalance(*args)
    end

    def replace(old, new)
      self.node = new
      new.parent = self
    end
  end

  def initialize
    @pseudo_root = PseudoRoot.new
    @pseudo_root.node = Node.empty(@pseudo_root)
  end

  def insert(x)
    @pseudo_root.node.insert(x)
  end

  def include?(x)
    @pseudo_root.node.include?(x)
  end

  def each(&block)
    @pseudo_root.node.each(&block)
  end
end
