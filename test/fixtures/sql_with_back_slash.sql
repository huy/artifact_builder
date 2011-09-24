create or replace procedure test_sql_with_back_slash as

begin
  if instr('ABC','\') >0 then
     null;
  end if;
end;