namespace :trans do  

   require 'yaml'      

   desc "Uploads translation files to the server."
   task :upload do
     config = load_config
     puts "Unable to open config" and return unless config
   end
   
   desc "Downloads translation files from the server."
   task :upload do
     config = load_config
     puts "Unable to open config" and return unless config

     api_key = config['api_key']
     puts 'Please configure 99translations in file #{config_file}" and return if api_key == 'YOUR_API_KEY'

     
   end

   def load_config
      file = config_file
      puts "Unable to read 99translations configuration file #{file.path}" and return unless File.file?(file)
      YAML.load(file)
   end

   def config_file
      File.join(RAILS_ROOT, 'config', 'trans.yml')
   end
         
end