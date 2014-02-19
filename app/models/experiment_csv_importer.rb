class ExperimentCsvImporter
  attr_accessor :parameters, :parameter_values

  def initialize(csv_content)
    @content = csv_content
    @parameters, @parameter_values = [], []
    parse
  end

  def parse
    i = 0

    CSV.parse(@content) do |row|
      if i == 0
        @parameters = row
      else
        row_values = []
        row.each do |cell|
          begin
            parsed_cell = JSON.parse(cell)
            row_values << parsed_cell.map(&:to_f)
          rescue Exception => e
            row_values << [ cell.to_f ]
          end
        end
        p = row_values[0]
        1.upto(row_values.size - 1).each do |i|
          p = p.product(row_values[i])
        end
        @parameter_values += p.map(&:flatten)
      end

      i += 1
    end
  end

end