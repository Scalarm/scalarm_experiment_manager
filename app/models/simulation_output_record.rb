# Attributes:
#_id: id
#experiment_id: ObjectId
#simulation_idx: ObjectId - when this record denotes binary results of a simulation run this is simulation_id
#output_file_id: ObjectId - id of a file stored in mongodb GridFS
#file_size: int - size in [B] of a stored file
#type: sting - either 'binary' or 'stdout'

require 'scalarm/database/core/mongo_active_record'

class SimulationOutputRecord < Scalarm::Database::MongoActiveRecord
  use_collection 'simulation_files'

  def set_file_object(tmpfile)
    file = Grid::File.new(tmpfile.tempfile.read, filename: tmpfile.original_filename, metadata: { size: tmpfile.tempfile.size })
    @attributes['output_file_id'] = @@binary_store.insert_one(file).to_s
    @attributes['file_size'] = tmpfile.tempfile.size
  end

  def file_object
    if self.output_file_id.nil?
      nil
    else
      file = @@binary_store.find_one(_id: self.output_file_id)
      if file.nil?
        nil
      else
        file.data
      end
    end
  end

  def file_object_name
    case self.type
      when 'binary'
        "simulation_#{self.simulation_idx}.tar.gz"
      when 'stdout'
        "simulation_#{self.simulation_idx}_stdout.txt"
      else
        nil
    end
  end

  def destroy
    begin
      @@binary_store.delete(self.output_file_id)
    rescue => e
      # if there is no file with this id then it is ok
    end

    super
  end
end
