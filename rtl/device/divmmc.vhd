
-- Divmmc
-- Copyright 2020 Alvin Albrecht and Fabio Belavenuto
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

entity divmmc is
   port (
      reset_i              : in std_logic;
      clock_i              : in std_logic;
      
      enable_i             : in std_logic;
      
      cpu_a_i              : in std_logic_vector(15 downto 0);
      cpu_mreq_n_i         : in std_logic;
      cpu_m1_n_i           : in std_logic;
      
      divmmc_button_i      : in std_logic;
      
      disable_automap_i    : in std_logic;
      disable_nmi_o        : out std_logic;
      
      divmmc_reg_i         : in std_logic_vector(7 downto 0);
      
      divmmc_rom_en_o      : out std_logic;
      divmmc_ram_en_o      : out std_logic;
      divmmc_rdonly_o      : out std_logic;
      divmmc_ram_bank_o    : out std_logic_vector(3 downto 0)
   );
end entity;

architecture rtl of divmmc is

   signal conmem     : std_logic;
   signal mapram     : std_logic;
   signal page0      : std_logic;
   signal page1      : std_logic;
   signal rom_en     : std_logic;
   signal ram_en     : std_logic;
   signal rdonly     : std_logic;
   signal ram_bank   : std_logic_vector(3 downto 0);
   
   signal automap_en_instant  : std_logic;
   signal automap_en_delayed  : std_logic;
   signal automap_dis_delayed : std_logic;
   signal automap_reset       : std_logic;
   
   signal automap_hold  : std_logic;
   signal automap       : std_logic;

begin

   -- DIVMMC Paging
   
   conmem <= divmmc_reg_i(7);
   mapram <= divmmc_reg_i(6);
   
   page0 <= '1' when cpu_a_i(15 downto 13) = "000" else '0';
   page1 <= '1' when cpu_a_i(15 downto 13) = "001" else '0';
   
   rom_en <= '1' when (page0 = '1' and (conmem = '1' or (mapram = '0' and automap = '1'))) else '0';
   ram_en <= '1' when (page0 = '1' and conmem = '0' and mapram = '1' and automap = '1') or (page1 = '1' and (conmem = '1' or automap = '1')) else '0';
   rdonly <= page0;
   ram_bank <= X"3" when page0 = '1' else divmmc_reg_i(3 downto 0);
   
   divmmc_rom_en_o <= rom_en and enable_i;
   divmmc_ram_en_o <= ram_en and enable_i;
   divmmc_rdonly_o <= rdonly;
   divmmc_ram_bank_o <= ram_bank;

   -- Automap

   automap_en_instant <= '1' when cpu_a_i(15 downto 8) = X"3D" else '0';
   automap_en_delayed <= '1' when cpu_a_i = X"0000" or cpu_a_i = X"0008" or cpu_a_i = X"0038" or (cpu_a_i = X"0066" and divmmc_button_i = '1') or cpu_a_i = X"04C6" or cpu_a_i = X"0562" else '0';
   automap_dis_delayed <= '1' when cpu_a_i(15 downto 3) = "0001111111111" else '0';

   automap_reset <= reset_i or disable_automap_i or not enable_i;
   
   process (clock_i)
   begin
      if rising_edge(clock_i) then
         if automap_reset = '1' then
            automap_hold <= '0';
         elsif cpu_mreq_n_i = '0' and cpu_m1_n_i = '0' then
            automap_hold <= automap_en_delayed or automap_en_instant or (automap_hold and not automap_dis_delayed);
         end if;
      end if;
   end process;
   
   process (cpu_mreq_n_i, automap_reset)
   begin
      if automap_reset = '1' then
         automap <= '0';
      elsif falling_edge(cpu_mreq_n_i) then
         automap <= automap_hold or (automap_en_instant and not cpu_m1_n_i);
      end if;
   end process;
   
   disable_nmi_o <= automap or automap_hold;

end architecture;
