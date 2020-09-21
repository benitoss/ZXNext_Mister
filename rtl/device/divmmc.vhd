
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
      
      cpu_a_15_13_i        : in std_logic_vector(2 downto 0);
      cpu_mreq_n_i         : in std_logic;
      cpu_m1_n_i           : in std_logic;
      
      divmmc_button_i      : in std_logic;
      
      reset_automap_i      : in std_logic;
      hide_automap_i       : in std_logic;
      obscure_automap_i    : in std_logic;   -- subset of hide_automap_i
      
      automap_en_instant_i             : in std_logic;
      automap_en_delayed_i             : in std_logic;
      automap_en_delayed_nohide_i      : in std_logic;
      automap_en_delayed_nohide_nmi_i  : in std_logic;
      automap_dis_delayed_i            : in std_logic;
      
      disable_nmi_o        : out std_logic;
      automap_held_o       : out std_logic;
      
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
   signal ram_bank   : std_logic_vector(3 downto 0);
   
   signal button_nmi : std_logic;

   signal automap_en_delayed_nohide  : std_logic;
   signal automap_reset       : std_logic;
   
   signal automap_hold  : std_logic;
   signal automap_held  : std_logic;
   signal automap       : std_logic;

begin

   -- DIVMMC Paging
   
   conmem <= divmmc_reg_i(7);
   mapram <= divmmc_reg_i(6);
   
   page0 <= '1' when cpu_a_15_13_i = "000" else '0';
   page1 <= '1' when cpu_a_15_13_i = "001" else '0';
   
   rom_en <= '1' when (page0 = '1' and (conmem = '1' or (mapram = '0' and automap = '1'))) else '0';
   ram_en <= '1' when (page0 = '1' and conmem = '0' and mapram = '1' and automap = '1') or (page1 = '1' and (conmem = '1' or automap = '1')) else '0';
   ram_bank <= X"3" when page0 = '1' else divmmc_reg_i(3 downto 0);
   
   divmmc_rom_en_o <= rom_en and enable_i;
   divmmc_ram_en_o <= ram_en and enable_i;
   divmmc_rdonly_o <= page0;
   divmmc_ram_bank_o <= ram_bank;

   -- NMI
   
   process (clock_i)
   begin
      if rising_edge(clock_i) then
         if automap_reset = '1' then
            button_nmi <= '0';
         elsif divmmc_button_i = '1' then
            button_nmi<= '1';
         elsif automap_held = '1' then
            button_nmi <= '0';
         end if;
      end if;
   end process;

   -- Automap

   automap_reset <= reset_i or reset_automap_i or not enable_i;
   automap_en_delayed_nohide <= (automap_en_delayed_nohide_nmi_i and button_nmi) or automap_en_delayed_nohide_i;
   
   process (clock_i)
   begin
      if rising_edge(clock_i) then
         if automap_reset = '1' then
            automap_hold <= '0';
         elsif cpu_mreq_n_i = '0' and cpu_m1_n_i = '0' then
            automap_hold <= (automap_en_delayed_nohide and not obscure_automap_i) or ((automap_en_delayed_i or automap_en_instant_i) and not hide_automap_i) or (automap_held and (hide_automap_i or not automap_dis_delayed_i));
         end if;
      end if;
   end process;

   process (clock_i)
   begin
      if rising_edge(clock_i) then
         if automap_reset = '1' then
            automap_held <= '0';
         elsif cpu_mreq_n_i = '1' then
            automap_held <= automap_hold;
         end if;
      end if;
   end process;
   
   automap <= automap_held or (automap_en_instant_i and (not cpu_m1_n_i) and (not hide_automap_i) and not automap_reset);
   
   disable_nmi_o <= automap or button_nmi;
   automap_held_o <= automap_held;

end architecture;
