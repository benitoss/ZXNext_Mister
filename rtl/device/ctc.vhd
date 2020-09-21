-- Z80 CTC
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

-- Reference:
-- http://www.zilog.com/docs/z80/ps0181.pdf
--
-- The im2 vector and im2 interrupt are not implemented here.  Instead
-- relevant signals are exported so that im2 mode can be optionally
-- implemented by the instantiating module.
--
-- Clarifications per CTC channel:
--
-- 1. Hard reset requires a control word and then a time constant to be
--    written even if bit 2 = 0 in the control word.
--
-- 2. Soft reset with bit 2 = 0 causes the entire control register to
--    be modified.  Soft reset with bit 2 = 1 does not change the control
--    register contents.  In both cases a time constant must follow
--    to resume operation.
--
-- 3. Changing the trigger edge selection in bit 4 while the channel
--    is in operation counts as a clock edge.  A pending timer trigger
--    will be fired and, in counter mode, an edge will be received.
--
-- 4. ZC/TO is asserted for one clock cycle and not for the entire
--    duration that the count is at zero.

library ieee;
use ieee.std_logic_1164.all;
use ieee.numeric_std.all;
use ieee.std_logic_unsigned.all;

entity ctc is
   port (
     
      i_CLK          : in std_logic;
      i_reset        : in std_logic;
      
      i_port_ctc_wr  : in std_logic;                      -- one of the ctc channel ports is being written
      i_port_ctc_sel : in std_logic_vector(2 downto 0);   -- which one 0-7

      i_int_en_wr    : in std_logic;                      -- separately write interrupt enable bits
      i_int_en       : in std_logic_vector(7 downto 0);   -- interrupt enable bits
      
      i_cpu_d        : in std_logic_vector(7 downto 0);
      o_cpu_d        : out std_logic_vector(7 downto 0);  -- data read from ctc port
      
      i_clk_trg      : in std_logic_vector(7 downto 0);   -- clock/trigger signals for each ctc channel, must be synchronized
      
      o_im2_vector_wr  : out std_logic;                   -- im2 vector is being written (not handled in this module)
      
      o_zc_to        : out std_logic_vector(7 downto 0);  -- zc/to for each ctc channel, asserted for one i_CLK cycle
      o_int_en       : out std_logic_vector(7 downto 0)   -- interrupt enable for each channel
   
   );
end entity;

architecture rtl of ctc is

   signal iowr       : std_logic_vector(7 downto 0);
   signal iowr_tc    : std_logic;
   
   signal iowr_tc_0  : std_logic;
   signal cpu_do_0   : std_logic_vector(7 downto 0);

   signal iowr_tc_1  : std_logic;
   signal cpu_do_1   : std_logic_vector(7 downto 0);

   signal iowr_tc_2  : std_logic;
   signal cpu_do_2   : std_logic_vector(7 downto 0);

   signal iowr_tc_3  : std_logic;
   signal cpu_do_3   : std_logic_vector(7 downto 0);

   signal iowr_tc_4  : std_logic;
   signal cpu_do_4   : std_logic_vector(7 downto 0);

   signal iowr_tc_5  : std_logic;
   signal cpu_do_5   : std_logic_vector(7 downto 0);

   signal iowr_tc_6  : std_logic;
   signal cpu_do_6   : std_logic_vector(7 downto 0);

   signal iowr_tc_7  : std_logic;
   signal cpu_do_7   : std_logic_vector(7 downto 0);

begin

   -- ROUTE SIGNALS FOR SELECTED CHANNEL
   
   process (i_port_ctc_sel, iowr_tc_0, cpu_do_0, i_port_ctc_wr, iowr_tc_1, cpu_do_1, iowr_tc_2, cpu_do_2, 
            iowr_tc_3, cpu_do_3, iowr_tc_4, cpu_do_4, iowr_tc_5, cpu_do_5, iowr_tc_6, cpu_do_6, iowr_tc_7, cpu_do_7)
   begin
   
      iowr <= (others => '0');
      
      case i_port_ctc_sel is
         when "000" =>
            iowr_tc <= iowr_tc_0;
            o_cpu_d <= cpu_do_0;
            iowr(0) <= i_port_ctc_wr;
         when "001" =>
            iowr_tc <= iowr_tc_1;
            o_cpu_d <= cpu_do_1;
            iowr(1) <= i_port_ctc_wr;
         when "010" =>
            iowr_tc <= iowr_tc_2;
            o_cpu_d <= cpu_do_2;
            iowr(2) <= i_port_ctc_wr;
         when "011" => 
            iowr_tc <= iowr_tc_3;
            o_cpu_d <= cpu_do_3;
            iowr(3) <= i_port_ctc_wr;
         when "100" =>
            iowr_tc <= iowr_tc_4;
            o_cpu_d <= cpu_do_4;
            iowr(4) <= i_port_ctc_wr;
         when "101" =>
            iowr_tc <= iowr_tc_5;
            o_cpu_d <= cpu_do_5;
            iowr(5) <= i_port_ctc_wr;
         when "110" =>
            iowr_tc <= iowr_tc_6;
            o_cpu_d <= cpu_do_6;
            iowr(6) <= i_port_ctc_wr;
         when others =>
            iowr_tc <= iowr_tc_7;
            o_cpu_d <= cpu_do_7;
            iowr(7) <= i_port_ctc_wr;
      end case;
   
   end process;
   
   o_im2_vector_wr <= i_port_ctc_wr and (not i_cpu_d(0)) and (not iowr_tc);

   -- CTC CHANNELS x 8

   ctc0 : entity work.ctc_chan
   port map (
         i_CLK       => i_CLK,
         i_reset     => i_reset,

         i_iowr      => iowr(0),
         o_iowr_tc   => iowr_tc_0,

         i_int_en_wr => i_int_en_wr,
         i_int_en    => i_int_en(0),

         i_cpu_d     => i_cpu_d,
         o_cpu_d     => cpu_do_0,

         i_clk_trg   => i_clk_trg(0),

         o_zc_to     => o_zc_to(0),
         o_int_en    => o_int_en(0)
   );

   ctc1 : entity work.ctc_chan
   port map (
         i_CLK       => i_CLK,
         i_reset     => i_reset,
         
         i_iowr      => iowr(1),
         o_iowr_tc   => iowr_tc_1,

         i_int_en_wr => i_int_en_wr,
         i_int_en    => i_int_en(1),
         
         i_cpu_d     => i_cpu_d,
         o_cpu_d     => cpu_do_1,

         i_clk_trg   => i_clk_trg(1),

         o_zc_to     => o_zc_to(1),
         o_int_en    => o_int_en(1)
   );

   ctc2 : entity work.ctc_chan
   port map (
         i_CLK       => i_CLK,
         i_reset     => i_reset,
         
         i_iowr      => iowr(2),
         o_iowr_tc   => iowr_tc_2,

         i_int_en_wr => i_int_en_wr,
         i_int_en    => i_int_en(2),
         
         i_cpu_d     => i_cpu_d,
         o_cpu_d     => cpu_do_2,

         i_clk_trg   => i_clk_trg(2),

         o_zc_to     => o_zc_to(2),
         o_int_en    => o_int_en(2)
   );

   ctc3 : entity work.ctc_chan
   port map (
         i_CLK       => i_CLK,
         i_reset     => i_reset,
         
         i_iowr      => iowr(3),
         o_iowr_tc   => iowr_tc_3,

         i_int_en_wr => i_int_en_wr,
         i_int_en    => i_int_en(3),
         
         i_cpu_d     => i_cpu_d,
         o_cpu_d     => cpu_do_3,

         i_clk_trg   => i_clk_trg(3),

         o_zc_to     => o_zc_to(3),
         o_int_en    => o_int_en(3)
   );

   ctc4 : entity work.ctc_chan
   port map (
         i_CLK       => i_CLK,
         i_reset     => i_reset,
         
         i_iowr      => iowr(4),
         o_iowr_tc   => iowr_tc_4,

         i_int_en_wr => i_int_en_wr,
         i_int_en    => i_int_en(4),
         
         i_cpu_d     => i_cpu_d,
         o_cpu_d     => cpu_do_4,

         i_clk_trg   => i_clk_trg(4),

         o_zc_to     => o_zc_to(4),
         o_int_en    => o_int_en(4)
   );

   ctc5 : entity work.ctc_chan
   port map (
         i_CLK       => i_CLK,
         i_reset     => i_reset,
         
         i_iowr      => iowr(5),
         o_iowr_tc   => iowr_tc_5,

         i_int_en_wr => i_int_en_wr,
         i_int_en    => i_int_en(5),
         
         i_cpu_d     => i_cpu_d,
         o_cpu_d     => cpu_do_5,

         i_clk_trg   => i_clk_trg(5),

         o_zc_to     => o_zc_to(5),
         o_int_en    => o_int_en(5)
   );

   ctc6 : entity work.ctc_chan
   port map (
         i_CLK       => i_CLK,
         i_reset     => i_reset,
         
         i_iowr      => iowr(6),
         o_iowr_tc   => iowr_tc_6,

         i_int_en_wr => i_int_en_wr,
         i_int_en    => i_int_en(6),
         
         i_cpu_d     => i_cpu_d,
         o_cpu_d     => cpu_do_6,

         i_clk_trg   => i_clk_trg(6),

         o_zc_to     => o_zc_to(6),
         o_int_en    => o_int_en(6)
   );

   ctc7 : entity work.ctc_chan
   port map (
         i_CLK       => i_CLK,
         i_reset     => i_reset,
         
         i_iowr      => iowr(7),
         o_iowr_tc   => iowr_tc_7,

         i_int_en_wr => i_int_en_wr,
         i_int_en    => i_int_en(7),
         
         i_cpu_d     => i_cpu_d,
         o_cpu_d     => cpu_do_7,

         i_clk_trg   => i_clk_trg(7),

         o_zc_to     => o_zc_to(7),
         o_int_en    => o_int_en(7)
   );
   
end architecture;
