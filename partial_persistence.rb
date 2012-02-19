# encoding: utf-8
# Trying to implement partial persistence as described in
# http://courses.csail.mit.edu/6.851/spring12/lectures/L01.html
#
# Draft
$nodes = []
class PartiallyPersistentArray
  attr_reader :current_version

  def self.wrap(array)
    new(Node.new(array.map {|x|
      if x.is_a?(Array)
        Node.new(x)
      else
        x
      end
    }))
  end

  def inspect
    "<PartiallyPersistentArray #{@root.inspect}>"
  end

  def output(filename = 'output.png')
    require 'graphviz'

    g = GraphViz::new("structs")
    @root.to_graph(g)
    g.output( :png => filename)
  end

  def initialize(node)
    @root = Root.new(node)
    @current_version = 0
  end

  def unwrap(t)
    @root.unwrap(t) # Returns a node
  end

  def set(indexes, value)
    root = @root.get(current_version)
    indexes = [*indexes]

    index = indexes.last
    node = indexes[0..-2].inject(root) do |node, i|
      node.slots_at_time(current_version)[i] # Could be optimized because only need one element of node
    end

    @current_version += 1

    node.set(index, value, current_version)
  end

  def get(version = current_version)
    @root.get(version).to_a
  end

private

  class Root
    def initialize(node)
      @roots = {
        0 => node
      }
      node.add_backlink(self, 0)
    end

    def unwrap(t)
      get(t).slots_at_time(t).map {|x|
        if x.is_a?(Node)
          x.slots_at_time(t)
        else
          x
        end
      }
    end

    def set(index, value, version)
      raise unless index == 0
      @roots[version] = value
      self
    end

    def get(version)
      # TODO: optimize
      @roots.to_a.reverse.detect {|v, node|
        v <= version
      }.last
    end

    def inspect
      "<Root>" # #{@roots.inspect}>"
    end
    def number
      0
    end

    def to_graph(g)
      g.add_nodes(self.object_id.to_s,
        "shape" => "record",
        "label" => @roots.map.with_index {|(v, _), i|
          "<f#{v}> #{v}"
        }.join("|")
      )
      all_nodes = []
      @roots.each do |v, node|
        node.add_to_graph(g, all_nodes)

        # Add edges from t to nodes
        g.add_edges( {self.object_id.to_s => "v#{v}"}, "#{node.object_id}" )
      end

    end
  end

  class Node
    def add_to_graph(g, all_nodes)
      # Add self
      g.add_nodes(self.object_id.to_s,
        "shape" => "record",
        "label" => [
          @slots.map.with_index {|x, i| "<s#{i}> #{x.is_a?(Node) ? "Node" : x}"}.join("|"),
          @modifications.map {|(t, idx, value)| "<m#{t}> #{idx} @ T#{t} = #{value.is_a?(Node) ? "Node" : value}"}.join("|")
        ].map {|x| "{#{x}}" }.join("|").tap {|y| puts y })

      # Add node slots
      @slots.each.with_index do |node, s|
        next unless node.is_a?(Node)

        node.add_to_graph(g, all_nodes)

        # Add edges from slots to nodes
        g.add_edges( {self.object_id.to_s => "s#{s}"}, "#{node.object_id}" )
      end

      # Add edges from mods
      @modifications.each {|(t, idx, node)|
        next unless node.is_a?(Node)

        node.add_to_graph(g, all_nodes)

        # Add edges from mods to nodes
        g.add_edges( {self.object_id.to_s => "m#{t}"}, "#{node.object_id}" )
      }

      @backlinks.each {|(node, idx)|
        g.add_edges( self.object_id.to_s, "#{node.object_id}" )
      }
    end

    def initialize(slots, max_mods = 20)
      $nodes << self
      @number = $nodes.length
      @slots         = slots
      @modifications = []
      @max_mods      = max_mods
      @backlinks     = []

      @slots.each.with_index do |x, i|
        if x.is_a?(Node)
          x.add_backlink(self, i)
        end
      end
    end

    def add_backlink(node, index)
      @backlinks << [node, index]
    end

    def set(index, value, version)
      @modifications << [version, index, value]
      @modifications.uniq!

      if @modifications.length < @max_mods
        self
      else
        puts "REBALANCING @ #{version}: #{@modifications.map(&:first)}"
        new_node = rebalance(version)
        @backlinks.each do |(node, backlink_index)|
            back_node = node.set(backlink_index, new_node, version)
        puts "BACK: " + back_node.inspect
          new_node.add_backlink(
            back_node,
            backlink_index
          )
        end
        puts "NEW: " + new_node.inspect
        @modifications.pop
        new_node
      end
    end

    def slots_at_time(t)
      base = @slots.dup
      @modifications.each do |(v, i, x)|
        break if v > t
        base[i] = x
      end

      base
    end

    attr_reader :number
    def inspect
      "<Node:#{number} " +
      "#{@slots.map {|x| x.is_a?(Node) ? "N#{x.number}" : x }}" +
        " mods=#{@modifications.map {|(t, idx, value)| "#{idx}@#{t} #{value.is_a?(Node) ? "N#{value.number}" : value}" }} backlinks=#{@backlinks.map(&:first).map(&:number)}>"
    end

  private

    def rebalance(version)
      Node.new(slots_at_time(version))
    end
  end
end

describe 'partial persistence' do
  it 'round trips an array' do
    ds = PartiallyPersistentArray.wrap([1, 2])
    ds.unwrap(0).should == [1, 2]
  end

  it 'updates a value in the array' do
    ds = PartiallyPersistentArray.wrap([1, 2])
    ds.set([1], 3)
    ds.unwrap(0).should == [1, 2]
    ds.unwrap(1).should == [1, 3]
  end

  it 'supports nesting' do
    ds = PartiallyPersistentArray.wrap([1, [2, 3]])
    ds.set([1, 1], 4)
    ds.set([1, 0], 5)
    ds.set([0], 7)
    ds.set([1, 0], 8)
    ds.unwrap(0).should == [1, [2, 3]]
    ds.unwrap(1).should == [1, [2, 4]]
    ds.unwrap(2).should == [1, [5, 4]]
  end

  it 'supports cyclic arrays' do
    pending
    b = []
    a = [1, b]
    b << a
    ds = PartiallyPersistentArray.wrap(a)
    ds.set([1, 1, 1, 1, 1, 0], 2)
    ds.unwrap(0).should == a
    ds.unwrap(1).should == [2, b]
  end

  it 'rebalances the root' do
    ds = PartiallyPersistentArray.wrap([0])
    (1..100).each do |x|
      ds.set([0], x)
    end
    (0..100).each do |x|
      ds.unwrap(x).should == [x]
    end
  end

  it 'rebalances nested arrays' do
    ds = PartiallyPersistentArray.wrap([[0], "abc"])
    begin
    puts ds.inspect
    (1..100).each do |x|
      ds.set([0, 0], x)
    $nodes.each do |node|
      puts node.inspect
    end
    puts
    end
#     (0..25).each do |x|
#       ds.unwrap(x).should == [[x]]
#     end
    ensure
    $nodes.each do |node|
      puts node.inspect
    end
    ds.output
    end
  end
end
