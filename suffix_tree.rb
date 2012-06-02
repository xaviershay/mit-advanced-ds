class SuffixTree
  EOS = '$'

  class Node
    attr_reader :edges

    def initialize
      @edges = {}
    end

    def add(c)
      @edges[c] ||= Node.new
    end
  end

  # O(N!) Space, not good
  def initialize(document)
    @root = Node.new

    document.length.times do |i|
      substring = document[i..-1]
      substring.chars.inject(root) do |node, c|
        node.add(c)
      end.add(EOS)
    end
  end

  # O(k), k is length of query
  def include?(query)
    query.chars.inject(root) do |node, c|
      node.edges[c] || break
    end
  end

  attr_reader :root
end

require 'rspec'

describe SuffixTree do
  it 'works' do
    ds = SuffixTree.new('banana')
    ds.include?('').should be
    ds.include?('a').should be
    ds.include?('b').should be
    ds.include?('c').should_not be
    ds.include?('an').should be
    ds.include?('anx').should_not be
    ds.include?('ana').should be
    Visualizer.output(ds)
  end
end

class Visualizer
  def self.output(ds, filename = 'output.png')
    require 'graphviz'

    g = GraphViz::new("G")
    add_node(g, ds.root)
    g.output(png: filename)
  end

  def self.add_node(g, node)
    g.add_nodes(node.object_id.to_s, label: "")
    node.edges.each do |edge, subnode|
      add_node(g, subnode)
      g.add_edges(node.object_id.to_s, subnode.object_id.to_s, label: edge.to_s)
    end
  end
end
