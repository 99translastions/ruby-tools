namespace :trans do  

   require 'yaml'      
   require 'net/http'

   desc "Uploads translation files to the server."
   task :upload do
     config = load_config
     abort("Unable to open config") unless config

     api_key = config['api_key']
     abort( "99translations.com requires configuration. Please configure 99translations in file #{config_file}") if api_key == 'YOUR_API_KEY'
  
     config.keys.each do |f|
       next if f == 'api_key'
       puts "Processing file #{f}"
       puts "... uploading #{config[f]['path']}"
       upload_file('99translations.com', '/upload_master/#{api_key}/#{f}', File.join(RAILS_ROOT, config[f]['path']))
     end  
      
   end
   
   desc "Downloads translation files from the server."
   task :download do
     config = load_config
     abort("Unable to open config") unless config

     api_key = config['api_key']
     abort( "99translations.com requires configuration. Please configure 99translations in file #{config_file}") if api_key == 'YOUR_API_KEY'
  
     config.keys.each do |f|
       next if f == 'api_key'
       puts "Processing file #{f}"
       tr = config[f]['translations']
       tr.keys.each do |t|
         puts "... downloading #{t} to #{tr[t]}" 
         download_file('99translations.com', "/download/#{api_key}/#{f}/#{t}", File.join(RAILS_ROOT, tr[t]))
       end 
     end
   end
   
  def upload_file(host, path, filename)
    begin 
      params = Hash.new
      file = File.open(filename, 'rb')
      params['upload'] = file

      mp = Multipart::MultipartPost.new
      query, headers = mp.prepare_query(params)

      Net::HTTP.start(host) do |http|
        http.read_timeout = TIMEOUT_SECONDS
        begin
          resp http.post(path, query, headers)
        rescue => e
          puts "ERROR: POST failed #{e}... #{Time.now}"
          return
        end
      end

      case resp
      when Net::HTTPSuccess
      when Net::HTTPInternalServerError
        puts "ERROR: Internal Server Error"
      else
        puts "ERROR: Unknown error #{res}: #{res.inspect}"
      end
    ensure
      file.close if file
    end
  end

   def download_file(host, url, file)
     begin 
       Net::HTTP.start(host) do |http|
         resp = http.get(url)
         case resp
         when Net::HTTPSuccess
         when Net::HTTPInternalServerError
           raise "Internal Server Error"
         else
           raise "Unknown error #{res}: #{res.inspect}"
         end
         File.open(file, "wb") do |f|
           f.write(resp.body)
         end 
       end
     rescue => e
       puts "ERROR: download failed #{e}"
     end
   end

   def load_config
      file = config_file
      puts "Unable to read 99translations configuration file #{file}" and return unless File.file?(file)
      YAML.load(File.read(file))
   end

   def config_file
      File.join(RAILS_ROOT, 'config', 'trans.yml')
   end
         
end
