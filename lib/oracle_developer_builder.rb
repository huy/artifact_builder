$LOAD_PATH.unshift File.expand_path(File.dirname(__FILE__)) unless $LOAD_PATH.first == File.expand_path(File.dirname(__FILE__))

require 'core_ext'
require 'fileutils'

class OracleDeveloperBuilder
    include FileUtils
    include Shell
    
    attr_accessor :userid, :runtime_dir, :form_compiler_path, :report_compiler_path

    def initialize (params={})
        @userid = params[:userid]
        @runtime_dir = params[:runtime_dir]
        @form_compiler_path = params[:form_compiler_path]
        @report_compiler_path = params[:report_compiler_path]
    end

    MODULE_TYPE = {".fmb"=>"FORM", ".mmb"=>"MENU", ".pll"=>"LIBRARY"}
    RUNTIME_EXT = {".fmb"=>".fmx", ".mmb"=>".mmx", ".pll"=>".plx"}

    def home
        File.dirname(@form_compiler_path).sub(/\/bin$/,'')
    end
    
    def compile_form filename, ignore_error, verbose

        extname = File.extname(filename).downcase
        basename = File.basename(filename,extname).downcase

        type = MODULE_TYPE[extname]
        temp = "#{@runtime_dir}/#{basename}#{extname}"
        output = "#{@runtime_dir}/#{basename}#{RUNTIME_EXT[extname]}"
        log = "#{@runtime_dir}/#{basename}.err"

        mkdir_p @runtime_dir 

        rm temp, :force => true
        cp filename, temp

        rm [output,log], :force => true
        
        if type
          cmd = if win32?
             "#{@form_compiler_path.gsub('/','\\')} module_type=#{type} module=#{temp.gsub('/','\\')} userid=#{@userid} output_file=#{output.gsub('/','\\')} logon=yes batch=yes compile_all=yes window_state=minimize"
          else
             "#{@form_compiler_path} module_type=#{type} module=#{temp} userid=#{@userid} output_file=#{output} logon=yes batch=yes compile_all=yes window_state=minimize"          
          end
          
          puts cmd if verbose

          system cmd,:ignore_exitstatus=>true

          handle_error(cmd,output,log,ignore_error)
        
          rm log, :force => true if File.exists?(output)
          rm temp, :force => true unless type==="LIBRARY"
        else
          puts "unknown extension of #{filename}"
        end
    end
    
    def handle_error(cmd,output,log,ignore_error)
        unless File.exists?(output)
           msg = "#{cmd}\nfailed:#{read_file(log)}".highlight(:error) 
           unless ignore_error
              raise msg
           else
              puts msg
           end           
        end    
    end
    
    def read_file file_name
        File.read(file_name) if File.exists?(file_name)
    end
      
    def compile_report filename, ignore_error, verbose
        
        extname = File.extname(filename).downcase
        basename = File.basename(filename,extname).downcase

        temp = "#{@runtime_dir}/#{basename}#{extname}"
        output = "#{@runtime_dir}/#{basename}.rep"        
        log = "#{@runtime_dir}/#{basename}.log"
        

        mkdir_p @runtime_dir 

        rm temp, :force => true
        cp filename, temp

        rm [output,log], :force => true

        if win32?
           cmd = "#{@report_compiler_path.gsub('/','\\')} userid=#{@userid} stype=rdffile dtype=repfile source=#{temp.gsub('/','\\')} dest=#{output.gsub('/','\\')} logfile=#{log} overwrite=yes batch=yes"
        else
           cmd = "#{@report_compiler_path} userid=#{@userid} stype=rdffile dtype=repfile source=#{temp} dest=#{output} logfile=#{log} overwrite=yes batch=yes"        
        end
        
        puts cmd if verbose

        system cmd,:ignore_exitstatus=>true

        handle_error(cmd,output,log,ignore_error)

        rm [log,temp], :force => true if File.exists?(output)
    end

    def compile_form_dir(params)
        dir = params[:dir]
        extname = params[:extname] || ''
        exclude = params[:exclude]
        ignore_error = params[:ignore_error] || false
        verbose = params[:verbose] || false
        
        Dir["#{dir}/*#{extname}"].each do |filename|        
    
            output = "#{@runtime_dir}/#{File.basename(filename,'.*').downcase}#{RUNTIME_EXT[File.extname(filename).downcase]}"

            if !File.exist?(output) || File.atime(filename) > File.atime(output)
               compile_form(filename,ignore_error, verbose) unless [exclude].flatten.member?(File.basename(filename))
            end   
        end
    end

    def compile_report_dir(params)
        dir = params[:dir]
        exclude = params[:exclude]
        ignore_error = params[:ignore_error] || false
        verbose = params[:verbose] || false

        Dir["#{dir}/*.rdf"].each do |filename|
            output = @runtime_dir + '/' + File.basename(filename.downcase,'.rdf') + '.rep'

            if !File.exist?(output) || File.atime(filename) > File.atime(output)
               compile_report(filename,ignore_error, verbose) unless [exclude].flatten.member?(File.basename(filename))
            end    
        end
    end

    def run &block
        instance_eval &block if block_given?
    end
end