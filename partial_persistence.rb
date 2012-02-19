# A persistent data structure is one where all versions of the structure are
# kept, so that old versions can be queried. Partial persistence is a form of
# this where updates are only permitted on the latest version.
#
# The structure implemented here was described in lecture one of the "Advanced
# Data Structures" class at MIT, [available
# online](http://courses.csail.mit.edu/6.851/spring12/lectures/L01.html).

# Minitest is used both to document and verify the behaviour of the structure.
require 'minitest/autorun'

class PartialPersistenceTest < MiniTest::Unit::TestCase
  # This code demonstrates partial persistence of a record-based data structure.
  # Each element in the record is either a value or a pointer to another record.
  # Updates are performed by specifiying a path to the record, an index into
  # that record, and the new value. Querying is done by inspecting the entire
  # structure at a point in time.
  def test_interface
    ds = PartialPersistence.wrap([1, 2, [3, 4]])
    ds.set([],  0, 8)
    ds.set([2], 1, 9)
    assert_equal [1, 2, [3, 4]], ds.unwrap(0)
    assert_equal [8, 2, [3, 4]], ds.unwrap(1)
    assert_equal [8, 2, [3, 9]], ds.unwrap(2)
  end

  # Both updates and queries can be performed in constant time using this
  # structure, which is pretty neat. This will be explained further below.
  def test_performance
    ds = PartialPersistence.wrap([1, 2, [3, -1]])
    (1..100).each do |x|
      ds.set([2], 1, x)
    end
    (1..100).each do |x|
      assert_equal [1, 2, [3, x]], ds.unwrap(x)
    end
  end
end

# ## Data Structures
#
# ### Record
#
# The core element in the data structure is a record, which is composed of
# three elements.
class Record
  # The first is an immutable list of initial values. Each value is either a
  # piece of data being stored, or a link to another record.
  attr_reader :values

  # Alongside the values, a list of deltas (modifications) is stored. The value
  # of the record at time *t* is `values` with `deltas` applied up until *t*.
  #
  # This is sufficient to achieve partial persistence, but requires `O(m)` time
  # to query the current version since all modifications need to be applied
  # from the beginning.
  class Delta < Struct.new(:t, :index, :new_value)
    def inspect
      "%s@T%i = %s" % [index, t, new_value]
    end
  end
  attr_reader :deltas

  # To achieve amortized constant (i.e. average `O(1)`) time the structure
  # needs to be rebalanced periodically, which may involve creating new
  # records. For this to work, all links between records are stored
  # bi-directionally so that they can be easily updated when a new record is
  # created. The forward link is already stored in `values`, here a separate
  # list of the back links is stored.  If record `A` has record `B` as a value
  # at `values[1]`, then `B` will store a back link `(A, 1)`.
  #
  # The utility of this will be further explained later.
  class Backlink < Struct.new(:record, :index); end

  def add_backlink(record, index)
    @backlinks << Backlink.new(record, index)
  end
  attr_reader :backlinks

  # Initially `deltas` and `backlinks` are empty, though the latter will always
  # be added to immediately at least once since a record cannot exist without
  # being referenced from somewhere.
  def initialize(values)
    @values    = values
    @deltas    = []
    @backlinks = []
    @values.each.with_index do |x, i|
      if x.is_a?(Record)
        x.add_backlink(self, i)
      end
    end
  end
end

# ### Root
#
# A special root node is required to act as a constant entry point for the
# structure. Since records can normally be rebalanced and new records created,
# without this entry point there is no way to know which record to start with
# for a given version! Comparatively, it has a naive implementation.
class Root
  attr_reader :records

  def initialize(record)
    @records = { 0 => record }
    record.add_backlink(self, 0)
  end

end

# ### PartialPersistence
#
# An overall wrapper class is provided to act as the public interface for the
# structure.
class PartialPersistence
  attr_reader :now
  attr_reader :root

protected

  def initialize(record)
    @root = Root.new(record)
    @now  = 0
  end
end

# ## Algorithms



# ### Queries
#
# For an individual record, the `values` at any *t* can be queried by applying
# all deltas against the base values. Since the maximum number of deltas is
# constant (rebalancing occurs if it is exceeded, see "updates" section), this
# operation completes in amortized constant time: it will not increase as
# overall number of updates increases.
class Record
  def values_at_time(t)
    base = values.dup

    deltas.each do |d|
      break if d.t > t
      base[d.index] = d.new_value
    end

    base
  end
end

# A special case for handling deltas is required for the root node, otherwise
# there is no way to get get a handle on an initial node for any given
# version.  This is not normally included in the constant amortized time
# calculation, I don't know how to to it better than `O(log n)` using a
# binary search tree. (Current implementation is naive, does not use tree.)
class Root
  def value_at_time(t)
    records.to_a.reverse.detect {|tn, _| # TODO: Optimize
      tn <= t
    }.last
  end

  # `unwrap`, the inverse of `wrap`, takes an optional time parameter that is
  # used to query historical versions. By default, the current version is
  # returned. It recursively unwraps all records in the structure.
  def unwrap(t)
    unwrapper = lambda do |x|
      case x
      when Record then x.values_at_time(t).map(&unwrapper)
      else x
      end
    end
    unwrapper[value_at_time(t)]
  end
end

class PartialPersistence
  def unwrap(t = now)
    @root.unwrap(t)
  end
end

# ### Updates
#
# Updating the structure first requires querying the current version of the
# structure to extract the record referenced by the given `indices`.
class PartialPersistence
  def set(path, index, value)
    current_root   = root.value_at_time(now)
    current_record = record_at_path(current_root, path, now)

    # Every update creates a new version, whether the structure actually
    # changed or not. This is not strictly space efficient, but has no impact
    # on time (since performance is amortized constant) and provides an easier
    # to use interface: clients can keep track of the current time without
    # having to check the return value of this method.
    @now += 1

    current_record.add_delta(now, index, value)
  end

private

  def record_at_path(initial, path, now)
    path.inject(initial) do |record, i|
      record.values_at_time(now)[i] # Could be optimized because only need one element of record
    end
  end
end

class Record
  MAX_DELTAS = 5 # TODO: MOve and document

  # We have now reached the heart of the algorithm. When the number of deltas
  # crosses a threshold, the structure is rebalanced by performing the
  # following operations:
  #
  # 1. Create a new record containing the current value of this record
  #    (`values_at_time(t)`). Note that this new record will not have any
  #    deltas.
  # 2. Copy all back links from the old record to the new.
  # 3. Add a delta to all back links, pointing them to the new record.
  #
  # Now, any queries for time *t* will bypass the old record completely and
  # instead use the new record, which responds quickly since it does not have
  # any deltas yet. This process of "resetting" the deltas of each node is the
  # key to the amortized constant performance of the algorithm.  All existing
  # modifications are left in place on the old record, so that queries for
  # historical versions can still find them.
  #
  # Note that adding a delta to a parent record may in turn trigger a rebalance
  # of that record as well!
  def add_delta(t, index, value)
    deltas << Delta.new(t, index, value)
    deltas.uniq! # TODO: Remove this

    if deltas.length < MAX_DELTAS
      self
    else
      new_record = rebalance(t)
      copy_backlinks(new_record, t)
      deltas.pop # TODO: Remove this
      new_record
    end
  end

private

  def rebalance(t)
    self.class.new(values_at_time(t))
  end

  def copy_backlinks(new_record, t)
    backlinks.each do |l|
      new_record.add_backlink(
        l.record.add_delta(t, l.index, new_record),
        l.index
      )
    end
  end
end

# The root stores deltas in a more traditional manner. See the "queries"
# section for details on performance.
class Root
  def add_delta(t, index, value)
    raise unless index == 0
    @records[t] = value
    self
  end
end

# ### Construction
#
# For convencience, a `wrap` method is provided to recursively convert a
# plain nested array into this partially persistent data structure.
def PartialPersistence.wrap(array)
  wrapper = lambda do |x|
    case x
    when Array then Record.new(x.map(&wrapper))
    else x
    end
  end
  new(wrapper[array])
end

# ## Old Code
if false
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

    def initialize(slots, max_mods = 4)
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
    (1..25).each do |x|
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
end
