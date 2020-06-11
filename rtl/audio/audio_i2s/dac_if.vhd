----------------------------------------------------------------------------------
-- Company: 
-- Engineer: 
-- 
-- Create Date:    23:18:31 08/04/2019 
-- Design Name: 
-- Module Name:    dac_if - Behavioral 
-- Project Name: 
-- Target Devices: 
-- Tool versions: 
-- Description: 
--
-- Dependencies: 
--
-- Revision: 
-- Revision 0.01 - File Created
-- Additional Comments: 
--
----------------------------------------------------------------------------------
library IEEE;
use IEEE.STD_LOGIC_1164.ALL;
use IEEE.NUMERIC_STD.ALL;

entity dac_if is
	Port ( 	
				SCLK : 		in STD_LOGIC; 					-- serial clock (1.56 MHz)
				L_start: 	in STD_LOGIC; 					-- strobe to load LEFT data
				R_start: 	in STD_LOGIC; 					-- strobe to load RIGHT data
				L_data : 	in std_logic_vector (15 downto 0); 	-- LEFT data (15-bit signed)
				R_data : 	in std_logic_vector (15 downto 0); 	-- RIGHT data (15-bit signed)
				SDATA : 		out STD_LOGIC); 				-- serial data stream to DAC
end dac_if;

architecture Behavioral of dac_if is

signal sreg: STD_LOGIC_VECTOR (15 downto 0); -- 16-bit shift register to do
															-- parallel to serial conversion
begin
	
	-- SREG is used to serially shift data out to DAC, MSBit first.
	-- Left data is loaded into SREG on falling edge of SCLK when L_start is active.
	-- Right data is loaded into SREG on falling edge of SCLK when R_start is active.
	-- At other times, falling edge of SCLK causes REG to logically shift one bit left
	-- Serial data to DAC is MSBit of SREG

	dac_proc: process
	begin
			wait until falling_edge(SCLK);
			if 	L_start = '1' then
						sreg <= std_logic_vector (L_data); 	-- load LEFT data into SREG
			elsif	R_start = '1' then
						sreg <= std_logic_vector (R_data); 	-- load RIGHT data into SREG
			else 	sreg <= sreg(14 downto 0) & '0'; 		-- logically shift SREG one bit left
			end if;
end process;

	SDATA <= sreg(15); 	-- serial data to DAC is MSBit of SREG

end Behavioral;

