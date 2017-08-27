create or replace type bigInt as object
(
	--DEPENDS ON: Largest possible collection size is 2G.
	--create or replace type digits_type is varray(2147483647) of integer;


	--Special thanks to paxdiablo: https://stackoverflow.com/questions/1218149/arbitrary-precision-arithmetic-explanation
	--The API is based on BigInteger.js: http://peterolson.github.io/BigInteger.js/

	digits digits_type,
	sign varchar2(1),

	--Constructors
	constructor function bigint(p_number bigInt) return self as result,
	constructor function bigint(p_number number) return self as result,
	constructor function bigint(p_number varchar2) return self as result,
	constructor function bigint(p_number clob) return self as result,

	--Methods
	member function abs return bigInt,
	member function add_(p_number bigInt) return bigInt, --"ADD" is reserved word, use "_" to make it work.
	member function greater(p_number bigInt) return boolean,
	member function subtract(p_number bigInt) return bigInt,
	member function toString return clob,

	--Metadata
	member function getVersion return number,

	--Private functions.
	--(I would hide these but Oracle types do not allow private functions.)
	member procedure private_set_from_clob(p_number clob)
)
/
create or replace type body bigInt is

--------------------------------------------------------------------------------
--Create bigInt out of a bigInt.
--------------------------------------------------------------------------------
constructor function bigint(p_number bigInt) return self as result is
begin
	self.digits := p_number.digits;
	self.sign := p_number.sign;
	return;
end;


--------------------------------------------------------------------------------
--Create bigInt out of a number.
--------------------------------------------------------------------------------
constructor function bigInt(p_number number) return self as result is
	v_original_to_char varchar2(32767);
	v_digit_string varchar2(32767);
	v_e_notation varchar2(5);
	v_exponent number;
begin
	--Special case for null
	if p_number is null then
		return;
	end if;

	--Initialize.
	self.digits := digits_type();

	--Convert using the maximum number of digits in format.
	v_original_to_char := to_char(p_number, 'FM9.99999999999999999999999999999999999999999999999999999999EEEE');

	--Get the "E" part.
	v_e_notation := regexp_substr(v_original_to_char, 'E.*');

	--Set the sign.
	if substr(v_original_to_char, 1, 1) = '-' then
		self.sign := '-';
	else
		self.sign := '+';
	end if;

	--Numbers between less than 1 are not an integer and raise an error.
	if substr(v_e_notation, 2, 1) = '-' then
		raise_application_error(-20000, 'The input is not an integer.');
	--Numbers greater than 1.
	else
		--Get the exponent.
		v_exponent := to_number(replace(v_e_notation, 'E+', null));

		--Remove the sign.
		v_digit_string := replace(v_original_to_char, '-');
		--Remove the "E" part.
		v_digit_string := regexp_replace(v_digit_string, 'E.*');
		--Remove the period.
		v_digit_string := replace(v_digit_string, '.');
		--Add a lot of zeroes to the end, they might be necessary alter.
		v_digit_string := rpad(v_digit_string, 4000, '0');

		--Throw an error if there are non-zero numbers.  That implies the number was not an integer.
		if replace(substr(v_digit_string, v_exponent+2), '0') is not null then
			raise_application_error(-20000, 'The input is not an integer.');
		end if;

		--Get only the first Exponent+1 digits.
		v_digit_string := substr(v_digit_string, 1, v_exponent+1);

		--Set the digits.
		self.digits.extend(length(v_digit_string));
		for i in 1 .. self.digits.count loop
			self.digits( (self.digits.count+1)-i) := substr(v_digit_string, i, 1);
		end loop;
	end if;

	return;
end;


--------------------------------------------------------------------------------
--Create bigInt out of a string.
--------------------------------------------------------------------------------
member procedure private_set_from_clob(p_number clob) is
	v_sign_offset number := 0;
begin
	--Special case for null
	if p_number is null then
		return;
	end if;

	--Initialize.
	self.digits := digits_type();

	--Set the sign.
	if dbms_lob.substr(p_number, 1, 1) = '-' then
		self.sign := '-';
		self.digits.extend(dbms_lob.getlength(p_number) - 1);
		v_sign_offset := 1;
	else
		self.digits.extend(dbms_lob.getlength(p_number));
	end if;

	--Set the digits.  Raise an exception if a non-digit is found.
	--TODO: Performance improvement.  Convert CLOB to VARCHAR2 before processing.
	for i in 1 .. dbms_lob.getlength(p_number) loop
		if i = 1 and dbms_lob.substr(p_number, 1, 1) = '-' then
			null;
		else
			if dbms_lob.substr(p_number, 1, i) in ('0','1','2','3','4','5','6','7','8','9') then
				self.digits( (self.digits.count - i + 1) + v_sign_offset) := dbms_lob.substr(p_number, 1, i);
			else
				raise_application_error(-20001, 'The input is not an integer.  The character '||
					dbms_lob.substr(p_number, 1, i)||' was found.');
			end if;
		end if;
	end loop;

end private_set_from_clob;


--------------------------------------------------------------------------------
--Create bigInt out of a string.
--------------------------------------------------------------------------------
constructor function bigInt(p_number varchar2) return self as result is
begin
	private_set_from_clob(p_number);
	return;
end;


--------------------------------------------------------------------------------
--Create bigInt out of a string.
--------------------------------------------------------------------------------
constructor function bigInt(p_number clob) return self as result is
begin
	private_set_from_clob(p_number);
	return;
end;


--------------------------------------------------------------------------------
--Absolute
--------------------------------------------------------------------------------
member function abs return bigInt is
	v_new_bigInt bigInt := self;
begin
	v_new_bigInt.sign := '+';
	return v_new_bigInt;
end abs;


--------------------------------------------------------------------------------
--Add
--------------------------------------------------------------------------------
member function add_(p_number bigInt) return bigInt is
	v_sum bigInt := bigInt(0);
	v_intermediate_sum number;
	v_carry number := 0;
begin
	--Special case when nulls.
	if self.digits is null or p_number.digits is null then
		v_sum.digits := null;
		v_sum.sign := null;
		return v_sum;
	end if;

	--Deal with negatives.
	if self.sign = '-' and p_number.sign = '-' then
		v_sum.sign := '-';
	elsif self.sign = '+' and p_number.sign = '+' then
		v_sum.sign := '+';
	elsif self.sign = '+' and p_number.sign = '-' then
		v_sum := p_number;
		v_sum.sign := '+';
		return self.subtract(v_sum);
	elsif self.sign = '-' and p_number.sign = '+' then
		v_sum := self;
		v_sum.sign := '+';
		return p_number.subtract(v_sum);
	end if;

	--Set size based on the maximum + 1.  We may need to shrink it later.
	v_sum.digits.trim;
	v_sum.digits.extend(greatest(self.digits.count, p_number.digits.count) + 1);

	--Loop through the digits.  Add them one-by-one and apply carry over to next digit.
	for i in 1 .. greatest(self.digits.count, p_number.digits.count) loop
		--Add numbers.
		if i > self.digits.count then
			v_intermediate_sum := p_number.digits(i) + v_carry;
		elsif i > p_number.digits.count then
			v_intermediate_sum := self.digits(i) + v_carry;
		else
			v_intermediate_sum := self.digits(i) + p_number.digits(i) + v_carry;
		end if;

		--Adjust intermediate result, set carry.
		if v_intermediate_sum >= 10 then
			v_intermediate_sum := v_intermediate_sum - 10;
			v_carry := 1;
		else
			v_carry := 0;
		end if;

		--Set final value.
		v_sum.digits(i) := v_intermediate_sum;
	end loop;

	--Apply final carry over or remove the extra digit.
	if v_carry = 1 then
		v_sum.digits(v_sum.digits.count) := 1;
	else
		v_sum.digits.trim(1);
	end if;

	return v_sum;
end add_;


--------------------------------------------------------------------------------
--Greater
--------------------------------------------------------------------------------
member function greater(p_number bigInt) return boolean is
begin
	--Special case for nulls.
	if self.digits is null or p_number.digits is null then
		return null;
	end if;

	if self.sign = '+' and p_number.sign = '-' then
		return true;
	elsif self.sign = '-' and p_number.sign = '+' then
		return false;
	elsif self.sign = '+' and p_number.sign = '+' then
		if self.digits.count > p_number.digits.count then
			return true;
		elsif self.digits.count < p_number.digits.count then
			return false;
		else
			for i in reverse 1 .. self.digits.count loop
				if self.digits(i) > p_number.digits(i) then
					return true;
				elsif self.digits(i) < p_number.digits(i) then
					return false;
				end if;
			end loop;
			--Must be equal.
			return false;
		end if;
	elsif self.sign = '-' and p_number.sign = '-' then
		if self.digits.count > p_number.digits.count then
			return false;
		elsif self.digits.count < p_number.digits.count then
			return true;
		else
			for i in reverse 1 .. self.digits.count loop
				if self.digits(i) < p_number.digits(i) then
					return true;
				elsif self.digits(i) > p_number.digits(i) then
					return false;
				end if;
			end loop;
			--Must be equal
			return false;
		end if;
	end if;

	return false;
end greater;


--------------------------------------------------------------------------------
--Subtract
--------------------------------------------------------------------------------
member function subtract(p_number bigInt) return bigInt is
	v_temp bigInt;
	v_difference bigInt := bigInt(0);
	v_intermediate_difference number;
	v_carry number := 0;
	v_big bigInt := self;
	v_small bigInt := p_number;
begin
	--Special case when nulls.
	if self.digits is null or p_number.digits is null then
		v_difference.digits := null;
		v_difference.sign := null;
		return v_difference;
	end if;

	--Convert some subtractions into additions to simplify signs.
	if self.sign = '+' and p_number.sign = '-' then
		v_temp := p_number;
		v_temp.sign := '+';
		v_difference := self.add_(v_temp);
		return v_difference;
	elsif self.sign = '-' and p_number.sign = '+' then
		v_temp := self;
		v_temp.sign := '+';
		v_difference := v_temp.add_(p_number);
		v_difference.sign := '-';
		return v_difference;
	elsif self.sign = '-' and p_number.sign = '-' then
		v_temp := p_number;
		v_temp.sign := '+';
		v_difference := self.add_(v_temp);
		return v_difference;
	end if;

	--Always subtract small from big.
	if p_number.greater(self) then
		v_big := p_number;
		v_small := self;

		--Negate results
		if v_difference.sign = '+' then
			v_difference.sign := '-';
		else
			v_difference.sign := '+';
		end if;
	end if;

	--Set size based on the maximum.  We may need to shrink it later.
	v_difference.digits.trim;
	v_difference.digits.extend(greatest(self.digits.count, p_number.digits.count));

	--Loop through the digits.  Subtract them one-by-one and apply carry over to next digit.
	for i in 1 .. greatest(v_big.digits.count, v_small.digits.count) loop

		if i > v_big.digits.count then
			if v_carry > v_small.digits(i) then
				v_intermediate_difference := v_small.digits(i) - v_carry + 10;
				v_carry := 1;
			else
				v_intermediate_difference := v_small.digits(i) - v_carry;
				v_carry := 0;
			end if;
		elsif i > v_small.digits.count then
			if v_carry > v_big.digits(i) then
				v_intermediate_difference := v_big.digits(i) - v_carry + 10;
				v_carry := 1;
			else
				v_intermediate_difference := v_big.digits(i) - v_carry;
				v_carry := 0;
			end if;
		else
			if v_big.digits(i) - v_carry < v_small.digits(i) then
				v_intermediate_difference := v_big.digits(i) - v_carry + 10 - v_small.digits(i);
				v_carry := 1;
			else
				v_intermediate_difference := v_big.digits(i) - v_carry - v_small.digits(i);
				v_carry := 0;
			end if;
		end if;

		v_difference.digits(i) := v_intermediate_difference;
	end loop;

	--Remove any leading zeroes, except for the first one.
	for i in reverse 2 .. v_difference.digits.count loop
		if v_difference.digits(i) = 0 then
			v_difference.digits.trim(1);
		else
			exit;
		end if;
	end loop;

	return v_difference;

end subtract;


--------------------------------------------------------------------------------
--Convert digits to a string.
--------------------------------------------------------------------------------
member function toString return clob is
	v_temp varchar2(32767);
	v_clob clob;
begin
	--Special case when null.
	if self.digits is null then
		return null;
	end if;

	--Create the CLOB.  Do not cache it to save resources.
	dbms_lob.createtemporary(lob_loc => v_clob, cache => false);

	--Add sign if negative.
	if self.sign = '-' then
		v_clob := self.sign;
	end if;

	--Add digits.
	--For performance, add them first to a VARCHAR2 and then a CLOB, since CLOBs are slower.
	--Also, use LENGTHB instead of normal length.
	--All the characters will be single-byte, adn LENGTHB is much faster.
	for i in reverse 1 .. self.digits.count loop
		v_temp := v_temp || self.digits(i);
		if lengthb(v_temp) = 32767 then
			dbms_lob.append(v_clob, v_temp);
			v_temp := null;
		end if;
	end loop;

	--Add remaining digits.
	dbms_lob.append(v_clob, v_temp);

	return v_clob;
end toString;


--------------------------------------------------------------------------------
member function getVersion return number is
begin
	return '0.0.0';
end getVersion;


end;
/
