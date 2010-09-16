namespace :trans do  

   require 'yaml'      
   require 'ftools'
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
       upload_file('99translations.com', "/upload_master/#{api_key}/#{f}", File.join(RAILS_ROOT, config[f]['path']))
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
     files = project_info[:files]
     if files
       files.each_key do |file|
         puts "... updating #{file} (#{files[file].size} locales)"
         files[file].each_pair do |locale, status|
           puts "... downloading #{locale} - #{status} complete"
           trans = download_yml('99translations.com', "/download/#{api_key}/#{file}/#{locale}")
           merge_translations(locale, trans)
         end
       end
     end
   end
   
   ## 
   # Merges translations.
   ##
   def merge_translations(locale, hash)
     file = File.join(RAILS_ROOT, 'config', 'locales')
     File.makedirs(file)
     loc = File.join(file, "#{locale}.yml")
     if File.exists?(loc)
       cur = YAML.load(File.read(loc))
     else 
       cur = { locale => Hash.new }
     end
     cur[locale].merge!(hash[locale])
     File.open(loc, 'w') do |f| 
        f << cur.to_yaml # we may use ya2yaml later to produce real UTF-8 .yml files
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

      resp = nil
      Net::HTTP.start(host) do |http|
        http.read_timeout = 20 
        begin
          resp = http.post(path, query, headers)
        rescue => e
          puts "ERROR: POST failed #{e}... #{Time.now}"
          return
        end
      end

      case resp
      when Net::HTTPSuccess
      when Net::HTTPInternalServerError
        puts "ERROR: Internal Server Error:  #{resp.body}"
      else
        puts "ERROR: Unknown error #{res}: #{resp.inspect}"
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
module Multipart
  # From: http://deftcode.com/code/flickr_upload/multipartpost.rb
  ## Helper class to prepare an HTTP POST request with a file upload
  ## Mostly taken from
  #http://blade.nagaokaut.ac.jp/cgi-bin/scat.rb/ruby/ruby-talk/113774
  ### WAS:
  ## Anything that's broken and wrong probably the fault of Bill Stilwell
  ##(bill@marginalia.org)
  ### NOW:
  ## Everything wrong is due to keith@oreilly.com
  require 'rubygems'
  require 'net/http'
  require 'cgi'

  class Param
    attr_accessor :k, :v
    def initialize( k, v )
      @k = k
      @v = v
    end

    def to_multipart
      #return "Content-Disposition: form-data; name=\"#{CGI::escape(k)}\"\r\n\r\n#{v}\r\n"
      # Don't escape mine...
      return "Content-Disposition: form-data; name=\"#{k}\"\r\n\r\n#{v}\r\n"
    end
  end

  class FileParam
    attr_accessor :k, :filename, :content
    def initialize( k, filename, content )
      @k = k
      @filename = filename
      @content = content
    end

    def to_multipart
      #return "Content-Disposition: form-data; name=\"#{CGI::escape(k)}\"; filename=\"#{filename}\"\r\n" + "Content-Transfer-Encoding: binary\r\n" + "\r\n\r\n" + content + "\r\n "
      # Don't escape mine
      return "Content-Disposition: form-data; name=\"#{k}\"; filename=\"#{filename}\"\r\n" + "Content-Transfer-Encoding: binary\r\n" + "\r\n\r\n" + content + "\r\n"
    end
  end
  class MultipartPost
    BOUNDARY = 'tarsiers-rule0000'
    HEADER = {"Content-type" => "multipart/form-data, boundary=" + BOUNDARY + " "}

    def prepare_query (params)
      fp = []
      params.each {|k,v|
        if v.respond_to?(:read)
          fp.push(FileParam.new(k, v.path, v.read))
        else
          fp.push(Param.new(k,v))
        end
      }
      query = fp.collect {|p| "--" + BOUNDARY + "\r\n" + p.to_multipart }.join("") + "--" + BOUNDARY + "--"
      return query, HEADER
    end
  end  
end
