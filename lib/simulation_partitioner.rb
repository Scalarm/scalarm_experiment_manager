class SimulationPartition
  attr_accessor :begin, :end, :step

  def initialize(b, e, s)
    @begin = b
    @end = e
    @step = s
  end

  def size
    ((@end - @begin) / @step).floor + 1
  end

  def elements
    elements=[]
    (@begin..@end).step(@step) do |x|
      elements << x
    end
    elements
  end
end

class SimulationArray
  attr_accessor :partitions

  def initialize(parts)
    @partitions=parts
  end

  def size
    sum=1
    @partitions.each do |partition|
      sum*=partition.values.size
    end
    sum
  end

  def elements
    result = @partitions[0].values
    @partitions[1..-1].each do |p|
      result = result.product(p.values)
    end
    result.each_with_index do |t, i|
      result[i] = t.flatten
    end
    result
  end
end

#part1 = SimulationPartition.new(1, 10, 1)
#puts part1.size
#part2 = SimulationPartition.new(1.0, 2.5, 0.2)
#puts part2.size
#part3 = SimulationPartition.new(5, 8, 1)
#puts part3.size
#sim1 = Simulation.new(part1, part2, part3)
#puts sim1.size
#puts sim1.elements.size
