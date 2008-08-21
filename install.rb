File.cp File.join(File.dirname(__FILE__), 'sample.yml') File.join(RAILS_ROOT, 'config', 'trans.yml')
puts IO.read(File.join(File.dirname(__FILE__), 'README'))

