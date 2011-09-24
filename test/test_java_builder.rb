require 'test/unit'

require File.dirname(__FILE__) + '/../lib/java_builder'
require File.dirname(__FILE__) + '/test_helper'

class TestJavaBuilder < Test::Unit::TestCase
    include TestHelper

    def setup
        @builder = JavaBuilder.new 'java'
    end

    def test_get_phantom_class_files
        module_dir = @builder.java_src_dir + '/sq-text'

        Dir.stubs(:[]).with(module_dir + '/classes/**/*.class').returns([
            'java/sq-text/classes/net/csetech/sq/text/ByteArrayUtil.class',
            'java/sq-text/classes/net/csetech/sq/text/InputValidator.class'
        ])

        stubs_file_exist('java/sq-text/src/net/csetech/sq/text/ByteArrayUtil.java',Time.local(2007,12,31,20,12,01))
        stubs_file_not_exist('java/sq-text/src/net/csetech/sq/text/InputValidator.java')

        assert_equal ['java/sq-text/classes/net/csetech/sq/text/InputValidator.class'],
            @builder.get_phantom_class_files(module_dir+'/src',module_dir +'/classes')
    end

    def test_get_out_of_date_resource_files
        module_dir = @builder.java_src_dir + '/sq-text'

        Dir.stubs(:[]).with(module_dir + '/src/**/*.properties').returns([
            'java/sq-text/src/config.properties',
        ])

        Dir.stubs(:[]).with(module_dir + '/src/**/*.xml').returns([
            'java/sq-text/src/rules.xml',
        ])

        stubs_file_exist('java/sq-text/src/config.properties',Time.local(2007,12,31,20,12,01))
        stubs_file_exist('java/sq-text/src/rules.xml',Time.local(2007,12,31,20,12,01))

        stubs_file_exist('java/sq-text/classes/config.properties',Time.local(2007,12,31,20,12,02))
        stubs_file_not_exist('java/sq-text/classes/rules.xml')

        assert_equal ['java/sq-text/src/rules.xml'],
            @builder.get_out_of_date_resource_files(module_dir+'/src',module_dir +'/classes',['.properties','.xml'])
    end
    
    def test_copy_resource_files
        module_dir = @builder.java_src_dir + '/sq-text'

        @builder.expects(:get_out_of_date_resource_files).
            with(module_dir+'/src',module_dir +'/classes', '*.properties').
            returns(['java/sq-text/src/config.properties'])

        @builder.expects(:mkdir_p).with('java/sq-text/classes')
        @builder.expects(:cp).with('java/sq-text/src/config.properties','java/sq-text/classes')

        @builder.copy_resource_files(module_dir +'/src', module_dir+'/classes','*.properties')
    end

    def test_get_phantom_resource_files
        module_dir = @builder.java_src_dir + '/sq-text'

        Dir.stubs(:[]).with(module_dir + '/classes/**/*.xml').returns([
            'java/sq-text/classes/rules.xml',
        ])

        stubs_file_not_exist('java/sq-text/src/rules.xml')

        assert_equal ['java/sq-text/classes/rules.xml'],
            @builder.get_phantom_resource_files(module_dir+'/src',module_dir +'/classes','.xml')
    end

    def test_compile_module
        module_dir = @builder.java_src_dir + '/sq-text'

        @builder.expects(:get_out_of_date_java_files).with(module_dir+'/src',module_dir +'/classes',[]).returns(
        [module_dir+'/src/net/csetech/sq/text/ByteArrayUtil.java',
         module_dir+'/src/net/csetech/sq/text/InputValidator.java'])

        @builder.expects(:get_phantom_class_files).with(module_dir+'/src',module_dir +'/classes').returns(
        [module_dir+'/class/net/csetech/sq/text/ByteUtil.class',
         module_dir+'/class/net/csetech/sq/text/Validator.class'])

        @builder.expects(:get_out_of_date_java_files).with(module_dir+'/test',module_dir +'/testclasses',
        ['java/sq-text/classes']).returns([])

        @builder.expects(:get_phantom_class_files).with(module_dir+'/test',module_dir +'/testclasses').returns(
        [])

        @builder.expects(:rm).with([module_dir+'/class/net/csetech/sq/text/ByteUtil.class',
         module_dir+'/class/net/csetech/sq/text/Validator.class'])

        @builder.expects(:mkdir_p).with('java/sq-text/classes')

        @builder.expects(:system).with('javac -encoding utf8 -sourcepath java/sq-text/src -d java/sq-text/classes java/sq-text/src/net/csetech/sq/text/ByteArrayUtil.java java/sq-text/src/net/csetech/sq/text/InputValidator.java')

        @builder.javac(:module=>'sq-text')
    end


    def test_compile_module_using_lib
        module_dir = @builder.java_src_dir + '/sq-image'
        lib_dir = @builder.java_src_dir + '/lib/jai'

        @builder.expects(:get_out_of_date_java_files).with(module_dir+'/src',module_dir +'/classes',
        ['java/lib/jai/jai_codec.jar','java/lib/jai/jai_core.jar']).returns(
            [module_dir+'/src/net/csetech/sq/util/ImageHelper.java'])

        @builder.expects(:get_out_of_date_java_files).with(module_dir+'/test',module_dir +'/testclasses',
        ['java/lib/jai/jai_codec.jar','java/lib/jai/jai_core.jar','java/sq-image/classes']).returns([])

        Dir.expects(:[]).with(module_dir + '/classes/**/*.class').returns([])
        Dir.expects(:[]).with(module_dir + '/testclasses/**/*.class').returns([])

        Dir.expects(:[]).with(lib_dir + '/**/*.jar').returns(
            [lib_dir+'/jai_codec.jar', lib_dir+'/jai_core.jar'])

        JavaBuilder::RESOURCE_PATTERN.each do |p|
            Dir.stubs(:[]).with(module_dir + "/src/**/*#{p}").returns([])
            Dir.stubs(:[]).with(module_dir + "/classes/**/*#{p}").returns([])            
            Dir.stubs(:[]).with(module_dir + "/test/**/*#{p}").returns([])
            Dir.stubs(:[]).with(module_dir + "/testclasses/**/*#{p}").returns([])            
        end

        ENV.expects(:[]=).with('CLASSPATH','java/lib/jai/jai_codec.jar;java/lib/jai/jai_core.jar')

        @builder.expects(:mkdir_p).with('java/sq-image/classes')

        @builder.expects(:system).with('javac -encoding utf8 -sourcepath java/sq-image/src -d java/sq-image/classes java/sq-image/src/net/csetech/sq/util/ImageHelper.java')

        @builder.javac(:module=>'sq-image', :lib=>'lib/jai')
    end

    def test_compile_module_depend_on_others
        puts "\ntest_compile_module_depend_on_others begin"
        module_dir = @builder.java_src_dir + '/sq-image'

        @builder.expects(:get_out_of_date_java_files).with(module_dir+'/src',module_dir +'/classes',
        ['java/sq-text/classes']).returns([module_dir+'/src/net/csetech/sq/util/ImageHelper.java'])

        @builder.expects(:get_out_of_date_java_files).with(module_dir+'/test',module_dir +'/testclasses',
        ['java/sq-text/classes','java/sq-image/classes']).returns([])

        ENV.expects(:[]=).with('CLASSPATH','java/sq-text/classes')

        @builder.expects(:mkdir_p).with('java/sq-image/classes')

        @builder.expects(:system).with('javac -encoding utf8 -sourcepath java/sq-image/src -d java/sq-image/classes java/sq-image/src/net/csetech/sq/util/ImageHelper.java')

        @builder.javac(:module=>'sq-image', :dependent_module=>'sq-text')
        puts "\ntest_compile_module_depend_on_others end"
    end


    def test_jar_no_manifiest
        @builder.expects(:system).with('jar -cf java/sq-text/sq-text.jar -C java/sq-text/classes .')
        @builder.jar(:module=>'sq-text',
           :src_dir=> "java/sq-text/classes"
        )
    end

    def test_jar_with_manifest
        @builder.expects(:system).with('jar -cfm java/tracuudoituong/tracuudoituong.jar java/tracuudoituong/MANIFEST.MF -C java/tracuudoituong/classes .')
        @builder.jar(:module=>'tracuudoituong',
                :src_dir=> "java/tracuudoituong/classes",
                :manifest=>'java/tracuudoituong/MANIFEST.MF')
    end


    def test_transitive_dependencies
        assert_equal [], @builder.get_transitive_dependencies('a', {})
        assert_equal [], @builder.get_transitive_dependencies('a', {'a'=>[]})
        assert_equal ['b'], @builder.get_transitive_dependencies('a', {'a'=>['b']})
        assert_equal ['b','c'], @builder.get_transitive_dependencies('a', {'a'=>['b'],'b'=>['c']})
        assert_equal ['b','c','d'], @builder.get_transitive_dependencies('a', {'a'=>['b','c'],'b'=>['d'],'c'=>['d']})
    end

end