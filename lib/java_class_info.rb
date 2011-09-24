require File.dirname(__FILE__) + '/core_ext'

class JavaClassInfo
    CLASS_MAGIC= 0xCAFEBABE

    CONSTANT_Class=7
    CONSTANT_Fieldref=9
    CONSTANT_Methodref=10
    CONSTANT_InterfaceMethodref=11
    CONSTANT_String=8
    CONSTANT_Integer=3
    CONSTANT_Float=4
    CONSTANT_Long=5
    CONSTANT_Double=6
    CONSTANT_NameAndType=12
    CONSTANT_Utf8=1

    CONSTANT_Class_info=[[:name_index,2]]

    CONSTANT_Fieldref_info=[[:class_index,2],[:name_and_type_index,2]]

    CONSTANT_Methodref_info=[[:class_index,2],[:name_and_type_index,2]]

    CONSTANT_InterfaceMethodref_info=[[:class_index,2],[:name_and_type_index,2]]

    CONSTANT_String_info=[[:string_index,2]]

    CONSTANT_Integer_info=[[:bytes,4]]

    CONSTANT_Float_info=[[:bytes,4]]

    CONSTANT_Long_info=[[:high_bytes,4],[:low_bytes,4]]

    CONSTANT_Double_info=[[:high_bytes,4],[:low_bytes,4]]

    CONSTANT_NameAndType_info=[[:name_index,2],[:descriptor_index,2]]

    CONSTANT_Utf8_info=[[:length,2],[:bytes,:length]]

    CLASS_FILE_DESC = {
    7=>CONSTANT_Class_info,
    9=>CONSTANT_Fieldref_info,
    10=>CONSTANT_Methodref_info,
    11=>CONSTANT_InterfaceMethodref_info,
    8=>CONSTANT_String_info,
    3=>CONSTANT_Integer_info,
    4=>CONSTANT_Float_info,
    5=>CONSTANT_Long_info,
    6=>CONSTANT_Double_info,
    12=>CONSTANT_NameAndType_info,
    1=>CONSTANT_Utf8_info
    }

    attr_reader :size, :minor_version, :major_version, :constant_pool

    def initialize(params={})
        @size = params[:size]
        @minor_version = params[:minor_version]
        @major_version = params[:major_version]
        @constant_pool = params[:constant_pool]
        @this_class_index= params[:this_class_index]
    end

    def this_class
        @constant_pool[@this_class_index]
    end

    def class_names_ref
        @constant_pool.collect do |entry|
            if !entry.nil? && entry[:tag]==CONSTANT_Class &&
               !(@constant_pool[entry[:name_index]][:bytes] =~ /^#{this_class_name}/)
               
                @constant_pool[entry[:name_index]][:bytes]
            end
        end.compact
    end

    def this_class_name
        @constant_pool[this_class[:name_index]][:bytes]
    end

    def self.read class_file_name
        class_file = File.read(class_file_name)

        @file_name = class_file_name

        size = class_file.size

        if CLASS_MAGIC!=class_file[0..3].big_endian
            raise "not java class"
        end

        minor_version = class_file[4..5].big_endian
        major_version = class_file[6..7].big_endian

        constant_pool_count = class_file[8..9].big_endian

        constant_pool = [nil] #first entry is alway nil

        position = 10
        numslot = 1

=begin
        puts "constant_pool_count=#{constant_pool_count}"

=end

        while numslot < constant_pool_count
            tag = class_file[position]
            position=position+1
            entry = {:tag=>tag}

            CLASS_FILE_DESC[tag].each {|pair|
                len = pair[1].is_a?(Symbol) ? entry[pair[1]] : pair[1]
                entry[pair[0]] =
                if pair[0].to_s =~ /byte/
                    class_file[position..position+len-1]
                else
                    class_file[position..position+len-1].big_endian
                end
                position = position + len
            }

=begin
                require 'pp'
                pp entry

=end
            constant_pool << entry
            numslot = numslot + 1
            if tag==CONSTANT_Long || tag==CONSTANT_Double
                constant_pool << nil
                numslot = numslot + 1
            end
        end

        access_flags = class_file[position..position+2-1]
        position = position + 2
        this_class_index = class_file[position..position+2-1].big_endian
        position = position + 2

        return JavaClassInfo.new(:size=>size,
           :minor_version=>minor_version,
           :major_version=>major_version,
           :constant_pool=>constant_pool,
           :this_class_index=>this_class_index)
    end
end