require 'minitest/autorun'

class AvlTreeTest < MiniTest::Unit::TestCase
  def test_operations
#     1.times do
#       set   = AvlTree.new
#       range = (0..5).to_a
#       range.sort_by { rand }.each {|x| set.insert(x) }
# 
#       keep   = range[0..range.length/2]
#       remove = range[range.length/2+1..-1]
# 
# #       remove.sort_by { rand }.each {|x| set.delete(x) }
# 
#       keep  .each { |x| assert  set.include?(x), "Did not include #{x}" }
# #       remove.each { |x| assert !set.include?(x), "Did include #{x}" }
# 
#       draw(set, 'tree.png')
#     end
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

    draw(ds, 'tree.png')

    assert_correct_balance_factors ds
    assert_balanced ds
  end

  def assert_correct_balance_factors(ds)
    ds.each do |node|
      assert_equal node.left.each.to_a.length - node.right.each.to_a.length,
        node.balance,
        "Node #{node.inspect} balance factor incorrect"
    end
  end

  def assert_balanced(ds)
    ds.each do |node|
      balance = node.left.each.to_a.length - node.right.each.to_a.length
      assert balance.abs <= 1, "Node #{node.inspect} is not balanced"
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
            rebalance(left, 1)
          end
        else
          if right.insert(x)
            rebalance(right, 1)
          end
        end
      end
    end

    def rebalance(child, d)
      parent = self.parent

      self.balance += if child == right
        -d
      else
        d
      end

      if balance == 2
        if left.balance == 1
          # Rotate right
          old_head  = self
          new_head  = left
          transfer  = new_head.right

          old_head.left   = transfer
          transfer.parent = old_head

          new_head.right  = old_head
          old_head.parent = new_head

          # This probably isn't right...
          new_head.balance = 0
          old_head.balance = 0

          parent.replace(old_head, new_head)
        elsif left.balance == -1
          # Rotate left
          old_head  = left
          new_head  = left.right
          transfer  = new_head.left

          old_head.right  = transfer
          transfer.parent = old_head

          new_head.left   = old_head
          old_head.parent = new_head

          new_head.balance = 0
          old_head.balance = 0

          # Replace
          self.left = new_head
          new_head.parent = self

          # Rotate right
          old_head  = self
          new_head  = left
          transfer  = new_head.right

          old_head.left   = transfer
          transfer.parent = old_head

          new_head.right  = old_head
          old_head.parent = new_head

          new_head.balance = 0
          old_head.balance = 0

          parent.replace(old_head, new_head)
        end
      end

      if balance == -2
        if right.balance == -1
          old_head  = self
          new_head  = right
          transfer  = new_head.left

          old_head.right  = transfer
          transfer.parent = old_head

          new_head.left   = old_head
          old_head.parent = new_head

          # This probably isn't right...
          new_head.balance = 0
          old_head.balance = 0

          parent.replace(old_head, new_head)
        elsif right.balance == 1
          # Rotate left
          old_head  = right
          new_head  = right.left
          transfer  = new_head.right

          old_head.left  = transfer
          transfer.parent = old_head

          new_head.right   = old_head
          old_head.parent = new_head

          new_head.balance = 0
          old_head.balance = 0

          # Replace
          self.right = new_head
          new_head.parent = self

          # Rotate left
          old_head  = self
          new_head  = right
          transfer  = new_head.left

          old_head.right   = transfer
          transfer.parent = old_head

          new_head.left  = old_head
          old_head.parent = new_head

          new_head.balance = 0
          old_head.balance = 0

          parent.replace(old_head, new_head)
        end
      end

      parent.rebalance(self, d)
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
      if block
        return if empty?

        yield self
        left.each(&block)
        right.each(&block)
      else
        Enumerator.new do |yielder|
          unless empty?
            yielder.yield self
            left.each  {|x| yielder.yield x }
            right.each {|x| yielder.yield x }
          end
        end
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
