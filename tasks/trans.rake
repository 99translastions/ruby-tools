namespace :trans do  

   require 'yaml'      
   require 'net/http'
   
   RAILS_API_KEY = '72719952057'

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
   
   desc "Downloads translations for rails and all listed plugins and puts them in config/locales"
   task :update_all do
      plugins = File.join(RAILS_ROOT, 'vendor', 'plugins')
      Dir.entries(plugins).each do |plugin_name|
        next if plugin_name.match(/^\./)
        plugin_config = File.join(plugins, plugin_name, 'trans.yml')
        if File.exists?(plugin_config)
          conf = YAML.load(File.read(plugin_config))
          api = conf['api_key']
          next unless api && !api.empty?
          puts "Found config for #{plugin_name}"
          update_project(api)
        end
      end
      update_project(RAILS_API_KEY)
      my_conf = load_config
      unless my_conf && my_conf['api_key']
        puts "Your project isn't configured to use 99translations.com. You may want to signup at http://99translations.com/ to manage your own translations"
        return
      end
      update_project(my_conf['api_key'])
   end

   ##
   # Downloads translations for a Rails 2.2 project.
   ##   
   def update_project(api_key)
     project_info = download_yml('99translations.com', "/info/#{api_key}.yml")
     unless project_info
       puts "WARNING: unable find project information. Please check API key." 
       return 
     end
     project_info['files'].keys do |file|
       puts "... updating #{file} (#{project_info['files'][file].size} locales)"
       project_info['files'][file].each_pair do |locale, status|
         puts "... downloading #{locale} - #{status}"
         trans = download_yml('99translations.com', "download/#{api_key}/#{file}/#{locale}")
         merge_translations(locale, trans)
       end
     end
   end
   
   ## 
   # Merges translations.
   ##
   def merge_translations(locale, hash)
     file = File.join(RAILS_ROOT, 'config', 'locales')
     File.mkdir_p(file)
     loc = File.join(file, "#{locale}.yml")
     if File.exists?(loc)
       cur = YAML.load(loc)
     else 
       cur = { locale => Hash.new }
     end
     res = cur[locale].merge(hash[locale])
     File.copy(loc, "#{loc}.bak")
     File.open(loc, 'w') do |f| 
        f << res.to_yaml # we may use ya2yaml later to produce real UTF-8 .yml files
      end
   end
   
   ##
   # Generic upload file routine.
   ##
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

   ##
   # Generic file download.
   ##
   def download_file(host, url, file)
     begin 
       Net::HTTP.start(host) do |http|
         resp = http.get(url)
         case resp
         when Net::HTTPSuccess
         when Net::HTTPInternalServerError
           raise "Internal Server Error"
         else
           raise "Unknown error #{resp}: #{resp.inspect}"
         end
         File.open(file, "wb") do |f|
           f.write(resp.body)
         end 
       end
     rescue => e
       puts "ERROR: download failed #{e}"
     end
   end

   ##
   # Downloads YML configuration for a project.
   ##
   def download_yml(host, url)
     begin 
       Net::HTTP.start(host) do |http|
         resp = http.get(url)
         case resp
         when Net::HTTPSuccess
         when Net::HTTPInternalServerError
           raise "Internal Server Error"
         else
           raise "Unknown error: #{resp.message}"
         end
         YAML.load(resp.body)
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
