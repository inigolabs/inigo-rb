module DataLoader
  def self.load_data
    path = Rails.root.join('starwars_data.yaml')
    @data = YAML.load_file(path)
  end

  def self.data
    @data
  end
end

DataLoader.load_data
