require 'test/unit'
require File.dirname(__FILE__) + '/../lib/java_class_info'

class TestReadClasFile < Test::Unit::TestCase

    ICAO_HELPER = File.dirname(__FILE__)+ '/fixtures/IcaoHelper.class.jdk1.4'
    VN_STRING = File.dirname(__FILE__)+ '/fixtures/VnString.class.jdk1.4'

    def test_read_class
        assert JavaClassInfo.read(VN_STRING).size
    end

    def test_this_class_name
        assert_equal "net/csetech/sq/text/VnString",JavaClassInfo.read(VN_STRING).this_class_name
    end

    def test_class_size
        assert_equal 954, JavaClassInfo.read(ICAO_HELPER).size
    end

    def test_class_version
        class_info = JavaClassInfo.read(ICAO_HELPER)

        assert_equal 0, class_info.minor_version
        assert_equal 46, class_info.major_version
    end

    def test_contant_pool
        class_info = JavaClassInfo.read(ICAO_HELPER)
        assert_equal 41, class_info.constant_pool.size
        assert_equal "net/csetech/sq/mrz/IcaoHelper",class_info.this_class_name
        assert_equal ["net/csetech/sq/mrz/MrzEncoder", "java/lang/StringBuffer", "java/lang/Object"],class_info.class_names_ref
    end

end