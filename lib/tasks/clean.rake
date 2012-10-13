desc "Cleans output"
task :clean do
  raise "### There are no output files to delete." unless File.directory?('public/output')
  puts "## Deleting public/output"
  system "rm -r public/output/"
  raise "### There are no log files to delete." unless File.directory?('log')
  puts "## Deleting log/"
  system "rm -r log/"
  raise "### There is no latexchroot dir to delete." unless File.directory?('latexchroot')
  puts "## Deleting latexchroot/"
  system "rm -r latexchroot/"
end