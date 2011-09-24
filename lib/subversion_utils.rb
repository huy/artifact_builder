module SubversionUtils
    
   def revision(module_dir)
      command = "|svn info #{module_dir}"
      revision=''
      open(command) do |f|
           revision_label = "Revision:"
           f.each { |line|
               revision = line.gsub(revision_label,'').strip if line =~ /#{revision_label}/
           }
      end
      revision
   end

   def top_level_dir(url)
     result=[]
     open("|svn ls #{url}") do |f|
       f.each do |line|
         result << File.basename(line.strip)
       end
     end
     result  
   end


   def diff(params)
     root_url = params[:root_url] || params[:url]

     old_url = params[:old_url] || "#{root_url}/#{params[:old]}"
     new_url = params[:new_url] || "#{root_url}/#{params[:new]}"

     puts "--- old_url=#{old_url}"
     puts "--- new_url=#{new_url}"

     (top_level_dir(old_url) & top_level_dir(new_url)).each do |dir|
        cmd = "svn diff --old=#{old_url}/#{dir} --new=#{new_url}/#{dir} > #{dir}.diff"

        puts "-> run #{cmd}"
        
        run_program(:cmd=>cmd,:wait_seconds=>10,:retries=>3)        
     end
   end

   def run_program(params)
        wait_seconds = params[:wait_seconds] || 10
        retries = params[:retries] || 5
        actual = 0
        loop do
          system params[:cmd]
          break if $?.exitstatus==0 || actual > retries
          puts "-> wait #{wait_seconds} seconds and try again"
          sleep wait_seconds
          wait_seconds = wait_seconds*2
          actual = actual + 1
        end
   end
   
   def commit(params)
     dir = params[:dir]
     Dir["#{dir}/*"].each do |f|
        cmd="svn commit \"#{f}\" -m \"upload\" "
        puts "-> run #{cmd}"
        run_program(:cmd=>cmd,:wait_seconds=>10,:retries=>3)        
     end
   end

   module_function :revision,:diff,:top_level_dir,:run_program,:commit
end
