require 'test/unit'

require File.dirname(__FILE__) + '/../lib/java_file_timestamp_checker'
require File.dirname(__FILE__) + '/test_helper'

class TestJavaFileTimestampChecker < Test::Unit::TestCase
    include TestHelper

    def setup
        @checker = JavaFileTimestampChecker.new :verbose=>true

        @module_dir = 'java/sq-text'
        
        Dir.stubs(:[]).with(@module_dir + '/src/**/*.java').returns([
            'java/sq-text/src/net/csetech/sq/text/ByteArrayUtil.java',
            'java/sq-text/src/net/csetech/sq/text/InputValidator.java'
        ])
    end

    def test_java_class_has_no_ref
        stubs_file_exist('java/sq-text/src/net/csetech/sq/text/ByteArrayUtil.java',Time.local(2007,12,31,20,12,01))
        stubs_file_exist('java/sq-text/src/net/csetech/sq/text/InputValidator.java',Time.local(2007,12,31,20,17,06))

        stubs_file_exist('java/sq-text/classes/net/csetech/sq/text/ByteArrayUtil.class',Time.local(2007,12,31,20,12,02))

        stubs_file_not_exist('java/sq-text/classes/net/csetech/sq/text/InputValidator.class')

        JavaClassInfo.expects(:read).with('java/sq-text/classes/net/csetech/sq/text/ByteArrayUtil.class').returns(JavaClassInfo.new)
        JavaClassInfo.any_instance.stubs(:class_names_ref).returns([])
        
        assert_equal ['java/sq-text/src/net/csetech/sq/text/InputValidator.java'],
            @checker.get_out_of_date_java_files(@module_dir+'/src',@module_dir +'/classes',[])
    end

    def test_java_class_has_ref
        JavaClassInfo.stubs(:read).with('java/sq-text/classes/net/csetech/sq/text/InputValidator.class').returns(JavaClassInfo.new)
        JavaClassInfo.any_instance.stubs(:class_names_ref).returns(['net/csetech/sq/text/ByteArrayUtil'])

        stubs_file_exist('java/sq-text/src/net/csetech/sq/text/InputValidator.java',Time.local(2007,12,31,20,17,06))
        stubs_file_exist('java/sq-text/src/net/csetech/sq/text/ByteArrayUtil.java',Time.local(2007,12,31,20,18,01))

        stubs_file_exist('java/sq-text/classes/net/csetech/sq/text/ByteArrayUtil.class',Time.local(2007,12,31,20,17,02))
        stubs_file_exist('java/sq-text/classes/net/csetech/sq/text/InputValidator.class',Time.local(2007,12,31,20,17,07))

        assert_equal ['java/sq-text/src/net/csetech/sq/text/ByteArrayUtil.java', 'java/sq-text/src/net/csetech/sq/text/InputValidator.java'],
            @checker.get_out_of_date_java_files(@module_dir+'/src',@module_dir +'/classes',[])
    end


end