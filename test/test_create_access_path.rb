require 'test/unit'
require File.dirname(__FILE__) + '/test_helper'
require File.dirname(__FILE__) + '/../lib/oracle_schema_builder'

class TestCreateAccessPath < Test::Unit::TestCase

    def test_create_access_path_on_other_user

        builder = OracleSchemaBuilder.new

        builder.expects(:connect).with(){|params| params[:username]=='foo'}
        
        builder.expects(:grant_privs).with(){|params| params[:username]=='bar' and params[:privs]==['select on table_a']}
        builder.expects(:connect).with(){|params| params[:username]=='bar'}
        
        builder.expects(:execute).with() {|sql,options| sql=="drop  synonym table_a"}

        builder.expects(:execute).with() {|sql,options| sql=="create  synonym table_a for foo.table_a"}

        builder.create_access_path(:from_user=>'foo',:to_user=>'bar',:objects=>['table_a'],
        :privilege=>'select')

    end
    
    def test_create_access_path_on_the_same_user_and_tab
        builder = OracleSchemaBuilder.new

        builder.expects(:connect).with(){|params| params[:username]=='foo'}
        builder.expects(:connect).with(){|params| params[:username]=='foo'}
        
        builder.expects(:execute).with(){|sql,options| sql=="drop  synonym table_a"}
        
        builder.create_access_path(:from_user=>'foo',:to_user=>'foo',:objects=>['table_a'],
        :privilege=>'select')
    end

end