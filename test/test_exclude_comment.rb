require 'test/unit'
require File.dirname(__FILE__) + '/../lib/oracle_schema_builder'

class TestExcludeComment < Test::Unit::TestCase
    def test_exclude_comment_outside_code
        with_comment = %q{
-- this comment outside code

--
create or replace proc as
-- this comment within code
begin
end;
}
        with_no_comment = %q{create or replace proc as
-- this comment within code
begin
end;}
        assert_equal with_no_comment,OracleSchemaBuilder.new.exclude_comment_outside_code(with_comment)
    end
end