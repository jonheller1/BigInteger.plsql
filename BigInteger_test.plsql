create or replace package bigInt_test authid current_user is
/*
== Purpose ==

Unit tests for bigInt.


== Example ==

--If the type was recompiled it may be necessary to clear the session state first.
begin
	dbms_session.reset_package;
end;

begin
	bigInt_test.run;
end;

*/

--Run the unit tests and display the results in dbms output.
procedure run;

end;
/
create or replace package body bigInt_test is

--Global counters and variables.
g_test_count number := 0;
g_passed_count number := 0;
g_failed_count number := 0;
type string_table is table of varchar2(32767);
g_report string_table;


--------------------------------------------------------------------------------
procedure assert_equals(p_test varchar2, p_expected varchar2, p_actual nvarchar2) is
begin
	g_test_count := g_test_count + 1;

	if p_expected = p_actual or p_expected is null and p_actual is null then
		g_passed_count := g_passed_count + 1;
	else
		g_failed_count := g_failed_count + 1;
		g_report.extend; g_report(g_report.count) := 'Failure with: '||p_test;
		g_report.extend; g_report(g_report.count) := 'Expected: '||p_expected;
		g_report.extend; g_report(g_report.count) := 'Actual  : '||p_actual;
	end if;
end assert_equals;


--------------------------------------------------------------------------------
procedure test_constructors is
begin
	assert_equals('Number constructor: NULL', null, bigInt(cast(null as number)).toString);
	assert_equals('Number constructor: Large number', '1234567890', bigInt(1234567890).toString);
	assert_equals('Number constructor: 0', '0', bigInt(0).toString);
	assert_equals('Number constructor: Huge E number', '-9000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000', bigInt(-9E120).toString);
	begin assert_equals('Number constructor: Error - not an integer 1', null, bigInt(123456.789).toString);
	exception when others then assert_equals('Number constructor: Error - not an integer 1', 'exception', 'exception');	end;
	begin assert_equals('Number constructor: Error - not an integer 1', null, bigInt(0.0000001234).toString);
	exception when others then assert_equals('Number constructor: Error - not an integer 1', 'exception', 'exception');	end;

	assert_equals('String constructor: NULL', null, bigInt(cast(null as varchar2)).toString);
	assert_equals('String constructor: Large String', '1234567890', bigInt('1234567890').toString);
	assert_equals('String constructor: 0', '0', bigInt('0').toString);
	assert_equals('String constructor: Huge E String', '-9000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000', bigInt('-9000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000').toString);
	begin assert_equals('String constructor: Error - not an integer 1', null, bigInt('123456.789').toString);
	exception when others then assert_equals('String constructor: Error - not an integer 1', 'exception', 'exception');	end;
	begin assert_equals('String constructor: Error - not an integer 1', null, bigInt('0.0000001234').toString);
	exception when others then assert_equals('String constructor: Error - not an integer 1', 'exception', 'exception');	end;
end test_constructors;


--------------------------------------------------------------------------------
procedure test_add is
begin
	--Static tests with specific numbers.
	assert_equals('ADD: NULL 1', null, bigInt(1).add_(bigInt(cast(null as number))).toString);
	assert_equals('ADD: NULL 2', null, bigInt(1).add_(bigInt(cast(null as varchar2))).toString);
	assert_equals('ADD: NULL 3', null, bigInt(cast(null as number)).add_(bigInt(1)).toString);
	assert_equals('ADD: NULL 4', null, bigInt(cast(null as varchar2)).add_(bigInt(1)).toString);
	assert_equals('ADD: 0', '0', bigInt(0).add_(bigInt(0)).toString);
	assert_equals('ADD: 2 positives', '2', bigInt(1).add_(bigInt(1)).toString);
	assert_equals('ADD: 2 negatives', '-2', bigInt(-1).add_(bigInt(-1)).toString);
	assert_equals('ADD: positive and negative', '0', bigInt(-1).add_(bigInt(1)).toString);
	assert_equals('ADD: positive and negative 2', '0', bigInt(1).add_(bigInt(-1)).toString);
	assert_equals('ADD: carry over', '10', bigInt(9).add_(bigInt(1)).toString);
	assert_equals('ADD: large adds', lpad('2', 4000, '2'), bigInt(lpad('1', 4000, '1')).add_(bigInt(lpad('1', 4000, '1'))).toString);
	assert_equals('ADD: large adds with carry', '1'||lpad('0', 3999, '0'), bigInt(lpad('9', 3999, '9')).add_(bigInt('1')).toString);

	--Dynamic tests with random numbers.
	declare
		v_random1 integer;
		v_random2 integer;
		v_result number;
		v_bigInt_result bigInt;
	begin
		for i in 1 .. 100 loop
			v_random1 := trunc(dbms_random.value(-999999999999999999999999999999999999, 999999999999999999999999999999999999));
			v_random2 := trunc(dbms_random.value(-999999999999999999999999999999999999, 999999999999999999999999999999999999));
			v_result := v_random1 + v_random2;
			v_bigInt_result := bigInt(v_random1).add_(bigInt(v_random2));

			assert_equals('ADD: Random '||i, to_char(v_result, 'FM999999999999999999999999999999999999999999999999999999999999999'), v_bigInt_result.toString);
		end loop;
	end;

end test_add;


--------------------------------------------------------------------------------
procedure test_subtract is
begin
	--Static tests with specific numbers.
	assert_equals('SUBTRACT: NULL 1', null, bigInt(1).subtract(bigInt(cast(null as number))).toString);
	assert_equals('SUBTRACT: NULL 2', null, bigInt(1).subtract(bigInt(cast(null as varchar2))).toString);
	assert_equals('SUBTRACT: NULL 3', null, bigInt(cast(null as number)).subtract(bigInt(1)).toString);
	assert_equals('SUBTRACT: NULL 4', null, bigInt(cast(null as varchar2)).subtract(bigInt(1)).toString);

	assert_equals('SUBTRACT: 0', '0', bigInt(0).subtract(bigInt(0)).toString);
	assert_equals('SUBTRACT: 2 positives', '1', bigInt(2).subtract(bigInt(1)).toString);
	assert_equals('SUBTRACT: 2 negatives', '0', bigInt(-1).subtract(bigInt(-1)).toString);
	assert_equals('SUBTRACT: positive and negative', '-2', bigInt(-1).subtract(bigInt(1)).toString);
	assert_equals('SUBTRACT: positive and negative 2', '2', bigInt(1).subtract(bigInt(-1)).toString);
	assert_equals('SUBTRACT: carry over 1', '2', bigInt(11).subtract(bigInt(9)).toString);
	assert_equals('SUBTRACT: carry over 2', '-1', bigInt(9).subtract(bigInt(10)).toString);
	assert_equals('SUBTRACT: large', lpad('1', 4000, '1'), bigInt(lpad('2', 4000, '2')).subtract(bigInt(lpad('1', 4000, '1'))).toString);
	assert_equals('SUBTRACT: large with carry', lpad('9', 3999, '9'), bigInt('1'||lpad('0', 3999, '0')).subtract(bigInt('1')).toString);

	--Dynamic tests with random numbers.
	declare
		v_random1 integer;
		v_random2 integer;
		v_result number;
		v_bigInt_result bigInt;
	begin
		for i in 1 .. 100 loop
			v_random1 := trunc(dbms_random.value(-999999999999999999999999999999999999, 999999999999999999999999999999999999));
			v_random2 := trunc(dbms_random.value(-999999999999999999999999999999999999, 999999999999999999999999999999999999));
			v_result := v_random1 - v_random2;
			v_bigInt_result := bigInt(v_random1).subtract(bigInt(v_random2));

			assert_equals('SUBTRACT: Random '||i, to_char(v_result, 'FM999999999999999999999999999999999999999999999999999999999999999'), v_bigInt_result.toString);
		end loop;
	end;
end test_subtract;


--------------------------------------------------------------------------------
procedure test_multiply is
begin
	--Static tests with specific numbers.
	assert_equals('MULTIPLY: NULL 1', null, bigInt(1).multiply(bigInt(cast(null as number))).toString);
	assert_equals('MULTIPLY: NULL 2', null, bigInt(1).multiply(bigInt(cast(null as varchar2))).toString);
	assert_equals('MULTIPLY: NULL 3', null, bigInt(cast(null as number)).multiply(bigInt(1)).toString);
	assert_equals('MULTIPLY: NULL 4', null, bigInt(cast(null as varchar2)).multiply(bigInt(1)).toString);

	assert_equals('MULTIPLY: 0 1', '0', bigInt(0).multiply(bigInt(0)).toString);
	assert_equals('MULTIPLY: 0 2', '0', bigInt(0).multiply(bigInt(999999999999999)).toString);
	assert_equals('MULTIPLY: 2 positives', '4', bigInt(2).multiply(bigInt(2)).toString);
	assert_equals('MULTIPLY: 2 negatives', '4', bigInt(-2).multiply(bigInt(-2)).toString);
	assert_equals('MULTIPLY: positive and negative', '-1', bigInt(-1).multiply(bigInt(1)).toString);
	assert_equals('MULTIPLY: positive and negative 2', '-1', bigInt(1).multiply(bigInt(-1)).toString);
	assert_equals('MULTIPLY: uneven digit lengths 1', '1000', bigInt(10).multiply(bigInt(100)).toString);
	assert_equals('MULTIPLY: uneven digit lengths 2', '1000', bigInt(100).multiply(bigInt(10)).toString);
	assert_equals('MULTIPLY: large', lpad('4', 4000, '1'), bigInt(lpad('2', 4000, '2')).multiply(bigInt(2)).toString);

	--Dynamic tests with random numbers.
	declare
		v_random1 integer;
		v_random2 integer;
		v_result number;
		v_bigInt_result bigInt;
	begin
		for i in 1 .. 100 loop
			v_random1 := trunc(dbms_random.value(-9999999999999999, 999999999999999999));
			v_random2 := trunc(dbms_random.value(-9999999999999999, 999999999999999999));
			v_result := v_random1 * v_random2;
			v_bigInt_result := bigInt(v_random1).multiply(bigInt(v_random2));

			assert_equals('SUBTRACT: Random '||i, to_char(v_result, 'FM999999999999999999999999999999999999999999999999999999999999999'), v_bigInt_result.toString);
		end loop;
	end;
end test_multiply;


--------------------------------------------------------------------------------
procedure run
is
begin
	--Reset globals.
	g_test_count := 0;
	g_passed_count := 0;
	g_failed_count := 0;
	g_report := string_table();

	--Print header.
	g_report.extend; g_report(g_report.count) := null;
	g_report.extend; g_report(g_report.count) := '----------------------------------------';
	g_report.extend; g_report(g_report.count) := 'Method5 Test Summary';
	g_report.extend; g_report(g_report.count) := '----------------------------------------';

	--Run the tests.
	test_constructors;
	test_add;
	test_subtract;
	test_multiply;

	for i in 1 .. g_report.count loop
		dbms_output.put_line(g_report(i));
	end loop;

	--Print summary of results.
	dbms_output.put_line(null);
	dbms_output.put_line('Total : '||g_test_count);
	dbms_output.put_line('Passed: '||g_passed_count);
	dbms_output.put_line('Failed: '||g_failed_count);

	--Print easy to read pass or fail message.
	if g_failed_count = 0 then
		dbms_output.put_line('
  _____         _____ _____
 |  __ \ /\    / ____/ ____|
 | |__) /  \  | (___| (___
 |  ___/ /\ \  \___ \\___ \
 | |  / ____ \ ____) |___) |
 |_| /_/    \_\_____/_____/');
	else
		dbms_output.put_line('
  ______      _____ _
 |  ____/\   |_   _| |
 | |__ /  \    | | | |
 |  __/ /\ \   | | | |
 | | / ____ \ _| |_| |____
 |_|/_/    \_\_____|______|');
	end if;
end run;

end;
/
