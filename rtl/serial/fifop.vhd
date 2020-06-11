
-- FIFO Manager
-- Copyright 2020 Alvin Albrecht
--
-- This file is part of the ZX Spectrum Next Project
-- <https://gitlab.com/SpectrumNext/ZX_Spectrum_Next_FPGA/tree/master/cores>
--
-- The ZX Spectrum Next FPGA source code is free software: you can 
-- redistribute it and/or modify it under the terms of the GNU General 
-- Public License as published by the Free Software Foundation, either 
-- version 3 of the License, or (at your option) any later version.
--
-- The ZX Spectrum Next FPGA source code is distributed in the hope 
-- that it will be useful, but WITHOUT ANY WARRANTY; without even the 
-- implied warranty of MERCHANTABILITY or FITNESS FOR A PARTICULAR 
-- PURPOSE.  See the GNU General Public License for more details.
--
-- You should have received a copy of the GNU General Public License
-- along with the ZX Spectrum Next FPGA source code.  If not, see 
-- <https://www.gnu.org/licenses/>.

library ieee;
use ieee.std_logic_1164.all;
use ieee.numeric_std.all;
use ieee.std_logic_unsigned.all;

entity fifop is
   generic (
      constant DEPTH_BITS     : positive := 9
   );
   port (
      clock_i        : in std_logic;
      reset_i        : in std_logic;
      
      empty_o        : out std_logic;
      full_o         : out std_logic;
      
      rd_i           : in std_logic;
      raddr_o        : out std_logic_vector(DEPTH_BITS-1 downto 0);
      
      wr_i           : in std_logic;
      waddr_o        : out std_logic_vector(DEPTH_BITS-1 downto 0)
   );
end entity;

architecture rtl of fifop is

   signal stored        : std_logic_vector(DEPTH_BITS downto 0);
   signal stored_delta  : std_logic_vector(DEPTH_BITS downto 0);
   
   signal empty      : std_logic;
   signal full       : std_logic;

   signal rd_dly     : std_logic;
   signal wr_dly     : std_logic;
   
   signal rd_advance : std_logic;
   signal wr_advance : std_logic;
   
   signal rd_addr    : std_logic_vector(DEPTH_BITS-1 downto 0);
   signal wr_addr    : std_logic_vector(DEPTH_BITS-1 downto 0);

begin

   -- read from fifo
   
   process (clock_i)
   begin
      if rising_edge(clock_i) then
         if reset_i = '1' then
            rd_dly <= '0';
         else
            rd_dly <= rd_i;
         end if;
      end if;
   end process;

   rd_advance <= rd_dly and (not rd_i) and (not empty);

   process (clock_i)
   begin
      if rising_edge(clock_i) then
         if reset_i = '1' then
            rd_addr <= (others => '0');
         elsif rd_advance = '1' then
            rd_addr <= rd_addr + 1;
         end if;
      end if;
   end process;
   
   -- write to fifo
   
   process (clock_i)
   begin
      if rising_edge(clock_i) then
         if reset_i = '1' then
            wr_dly <= '0';
         else
            wr_dly <= wr_i;
         end if;
      end if;
   end process;

   wr_advance <= wr_dly and (not wr_i) and (not full);
   
   process (clock_i)
   begin
      if rising_edge(clock_i) then
         if reset_i = '1' then
            wr_addr <= (others => '0');
         elsif wr_advance = '1' then
            wr_addr <= wr_addr + 1;
         end if;
      end if;
   end process;
   
   -- track number of stored bytes
   
   stored_delta <= std_logic_vector(to_unsigned(1,stored_delta'length)) when (rd_advance = '0' and wr_advance = '1') else 
                   std_logic_vector(to_unsigned(-1,stored_delta'length)) when (rd_advance = '1' and wr_advance = '0') else
                   std_logic_vector(to_unsigned(0,stored_delta'length));
   
   process (clock_i)
   begin
      if rising_edge(clock_i) then
         if reset_i = '1' then
            stored <= (others => '0');
         else
            stored <= stored + stored_delta;
         end if;
      end if;
   end process;
   
   -- flags
   
   empty <= '1' when stored = std_logic_vector(to_unsigned(0,stored'length)) else '0';
   full <= stored(DEPTH_BITS);
   
   -- output
   
   empty_o <= empty;
   full_o <= full;
   
   raddr_o <= rd_addr;
   waddr_o <= wr_addr;

end architecture;
