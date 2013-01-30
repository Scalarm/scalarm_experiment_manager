class Simulation < ActiveRecord::Base
  has_many :experiments
  
  PREFIX = File.join(Rails.public_path, "data")
  DIRS = {
      "scenario" => "scenarios",
      "other" => "others"
  }
  
  def save_files(upload)
    DIRS.each_key do |key|
      logger.info("DIR - #{key} - #{upload[key]} - #{self[key + "_file"]}")
      if upload[key] then
        file_name = upload[key].original_filename
        path = File.join(PREFIX + DIRS[key], file_name)
        if self[key + "_file"] and File.exist?(File.join(PREFIX + DIRS[key], self[key + "_file"])) then
          File.delete(File.join(PREFIX + DIRS[key], self[key + "_file"]))
        end
        File.open(path, "wb") { |f| f.write(upload[key].read) }
        self[key + "_file"] = file_name
      end
    end
    
    save
  end
  
  def delete_files
    DIRS.each_key do |key|
      if not self[key + "_file"].blank? then
        File.delete(File.join(PREFIX, DIRS[key], self[key + "_file"]))
      end
    end
  end
  
  def scenario_file_path
    File.join(self.data_folder_path, self.scenario_file)
      #File.join(PREFIX, DIRS["scenario"], self["scenario_file"])
  end

  def data_folder_path
    if self.scenario_file != nil then
      File.join(Rails.configuration.eusas_data_path, self.scenario_file.split('.')[0])
    else
      nil
    end
  end
end
