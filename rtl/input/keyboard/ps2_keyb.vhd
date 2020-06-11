
-- PS2 Keyboard
-- Copyright 2020 Fabio Belavenuto
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

library IEEE;
use IEEE.STD_LOGIC_1164.ALL;
use IEEE.NUMERIC_STD.ALL;

entity ps2_keyb is
   generic
   (
      CLK_KHZ        : integer
   );
   port 
   (
      enable_i       : in    std_logic;
      clock_i        : in    std_logic;
      clock_180o_i   : in    std_logic;
      clock_ps2_i    : in    std_logic;
      reset_i        : in    std_logic;
      
      -- PS/2 interface
      ps2_clk_i      : in std_logic;
      ps2_data_i     : in std_logic;
      ps2_clk_o      : out std_logic;
      ps2_data_o     : out std_logic;
      ps2_data_out   : out std_logic;
      ps2_clk_out    : out std_logic;
         
      -- CPU address bus (row)
      rows_i         : in    std_logic_vector( 7 downto 0);
      
      -- Column outputs
      cols_o         : out   std_logic_vector( 4 downto 0);
      functionkeys_o : out   std_logic_vector(12 downto 1);
      
      --
      core_reload_o  : out   std_logic;
      keymap_addr_i  : in    std_logic_vector(8 downto 0);
      keymap_data_i  : in    std_logic_vector(8 downto 0);
      keymap_we_i    : in    std_logic
   );
end entity;

architecture rtl of ps2_keyb is

   type key_matrix_t is array (7 downto 0) of std_logic_vector(4 downto 0);
   signal matrix_q         : key_matrix_t;

   signal ps2_data_s       : std_logic_vector(7 downto 0);
   signal ps2_valid_s      : std_logic;
   signal keymap_clock_s   : std_logic;
   signal keymap_addr_s    : std_logic_vector(8 downto 0);
   signal keymap_data_s    : std_logic_vector(8 downto 0);
   signal release_s        : std_logic;
   signal extended_s       : std_logic;
   signal k1_s, k2_s, k3_s, k4_s,
          k5_s, k6_s, k7_s, k8_s : std_logic_vector(4 downto 0);

   signal data_send_s      : std_logic_vector(7 downto 0);
   signal data_send_rdy_s  : std_logic                      := '0';
   signal ctrl_s           : std_logic                      := '1';
   signal alt_s            : std_logic                      := '1';

   -- Function keys
   signal fnkeys_s         : std_logic_vector(12 downto 1)  := (others => '0');
   
   --
   signal ps2_alt0_clk_io  : std_logic;
   signal ps2_alt0_data_io : std_logic;
   signal ps2_alt0_valid_s : std_logic;
   signal ps2_alt0_data_s  : std_logic_vector(7 downto 0);
   signal ps2_alt1_clk_io  : std_logic;
   signal ps2_alt1_data_io : std_logic;
   signal ps2_alt1_valid_s : std_logic;
   signal ps2_alt1_data_s  : std_logic_vector(7 downto 0);
-- signal ps2_sigsend_s : std_logic;
   
 begin

   keymap_clock_s <= clock_180o_i;

   -- The keymaps
   keymaps: entity work.keymaps
   port map (
      clock_i     => keymap_clock_s,
      addr_wr_i   => keymap_addr_i,
      data_i      => keymap_data_i,
      we_i        => keymap_we_i,
      addr_rd_i   => keymap_addr_s,
      data_o      => keymap_data_s
   );

   -- PS/2 interface


      ps2_alt0 : entity work.ps2_iobase
      generic map (
         clkfreq_g      => CLK_KHZ
      )
      port map (
         clock_i        => clock_ps2_i,
         reset_i        => reset_i,
         enable_i       => enable_i,
         ps2_clk_i      => ps2_clk_i, 
         ps2_data_i     => ps2_data_i, 
         ps2_clk_o      => ps2_clk_o, 
         ps2_data_o     => ps2_data_o, 
         ps2_data_out   => ps2_data_out, 
         ps2_clk_out    => ps2_clk_out, 
         data_rdy_i     => data_send_rdy_s,
         data_i         => data_send_s,
         send_rdy_o     => open,
         data_rdy_o     => ps2_valid_s, --ps2_alt0_valid_s
         data_o         => ps2_data_s, --ps2_alt0_data_s
         sigsending_o   => open   -- ps2_sigsend_s
      );

   -- Function Keys
   functionkeys_o <= fnkeys_s;

   -- Matrix
   k1_s <= matrix_q(0) when rows_i(0) = '0' else (others => '1');
   k2_s <= matrix_q(1) when rows_i(1) = '0' else (others => '1');
   k3_s <= matrix_q(2) when rows_i(2) = '0' else (others => '1');
   k4_s <= matrix_q(3) when rows_i(3) = '0' else (others => '1');
   k5_s <= matrix_q(4) when rows_i(4) = '0' else (others => '1');
   k6_s <= matrix_q(5) when rows_i(5) = '0' else (others => '1');
   k7_s <= matrix_q(6) when rows_i(6) = '0' else (others => '1');
   k8_s <= matrix_q(7) when rows_i(7) = '0' else (others => '1');
   cols_o <= k1_s and k2_s and k3_s and k4_s and k5_s and k6_s and k7_s and k8_s;

   -- Key decode
   process(reset_i, clock_i)
      type keymap_seq_t is (KM_IDLE, KM_READ, KM_SEND, KM_END);
      variable keymap_seq_s      : keymap_seq_t;
      variable keyb_valid_edge_v : std_logic_vector(1 downto 0)   := "00";
      variable row_v : integer range 0 to 7;
      variable col_v : integer range 0 to 7;
      variable caps_v : std_logic;
      variable symb_v : std_logic;
   begin
      if rising_edge(clock_i) then
         if reset_i = '1' then
            keymap_seq_s      := KM_IDLE;
            keyb_valid_edge_v := "00";
            release_s         <= '0';
            extended_s        <= '0';

            matrix_q(0) <= (others => '1');
            matrix_q(1) <= (others => '1');
            matrix_q(2) <= (others => '1');
            matrix_q(3) <= (others => '1');
            matrix_q(4) <= (others => '1');
            matrix_q(5) <= (others => '1');
            matrix_q(6) <= (others => '1');
            matrix_q(7) <= (others => '1');

            fnkeys_s <= (others => '0');
            alt_s    <= '1';
            ctrl_s   <= '1';

         else

            core_reload_o <= '0';
            data_send_rdy_s   <= '0';

            keyb_valid_edge_v := keyb_valid_edge_v(0) & ps2_valid_s;
         
            case keymap_seq_s is
               --
               when KM_IDLE =>
                  if keyb_valid_edge_v = "01" then
                     if ps2_data_s = X"AA" then
                        keymap_seq_s := KM_SEND;
                     elsif ps2_data_s = X"E0" then       -- Extended key code follows
                        extended_s <= '1';
                     elsif ps2_data_s = X"F0" then       -- Release code follows
                        release_s <= '1';
                     else
                        keymap_seq_s := KM_READ;
                     end if;
                  end if;
               --
               when KM_READ =>
                  keymap_addr_s <= extended_s & ps2_data_s;
                  if extended_s = '0' then
                     if ps2_data_s = X"11" then          -- LALT
                        alt_s <= release_s;
                     elsif ps2_data_s = X"14" then       -- LCTRL
                        ctrl_s <= release_s;
                     elsif ps2_data_s = X"66" then       -- Backspace
                        if alt_s = '0' and ctrl_s = '0' then
                           core_reload_o <= '1';
                        end if;
                     elsif ps2_data_s = X"05" then       -- F1
                        fnkeys_s(1) <= not release_s;
                     elsif ps2_data_s = X"06" then       -- F2
                        fnkeys_s(2) <= not release_s;
                     elsif ps2_data_s = X"04" then       -- F3
                        fnkeys_s(3) <= not release_s;
                     elsif ps2_data_s = X"0C" then       -- F4
                        fnkeys_s(4) <= not release_s;
                     elsif ps2_data_s = X"03" then       -- F5
                        fnkeys_s(5) <= not release_s;
                     elsif ps2_data_s = X"0B" then       -- F6
                        fnkeys_s(6) <= not release_s;
                     elsif ps2_data_s = X"83" then       -- F7
                        fnkeys_s(7) <= not release_s;
                     elsif ps2_data_s = X"0A" then       -- F8
                        fnkeys_s(8) <= not release_s;
                     elsif ps2_data_s = X"01" then       -- F9
                        fnkeys_s(9) <= not release_s;
                     elsif ps2_data_s = X"09" then       -- F10
                        fnkeys_s(10) <= not release_s;
                     elsif ps2_data_s = X"78" then       -- F11
                        fnkeys_s(11) <= not release_s;
                     elsif ps2_data_s = X"07" then       -- F12
                        fnkeys_s(12) <= not release_s;
                     end if;
                  else
                     -- Extended
                     if ps2_data_s = X"11" then          -- RALT
                        alt_s <= release_s;
                     elsif ps2_data_s = X"14" then       -- RCTRL
                        ctrl_s <= release_s;
                     end if;
                  end if;
                  keymap_seq_s := KM_END;
               --
               when KM_SEND =>
                  data_send_s       <= X"55";
                  data_send_rdy_s   <= '1';
                  keymap_seq_s := KM_IDLE;
               --
               when KM_END =>
                  -- Cancel extended/release flags for next time
                  release_s  <= '0';
                  extended_s <= '0';
                  col_v := to_integer(unsigned(keymap_data_s(2 downto 0)));
                  row_v := to_integer(unsigned(keymap_data_s(5 downto 3)));
                  caps_v := keymap_data_s(6);
                  symb_v := keymap_data_s(7);
                  if col_v < 5 then
                     matrix_q(row_v)(col_v) <= release_s;
                  end if;
                  if caps_v = '1' then
                     matrix_q(0)(0) <= release_s;
                  end if;
                  if symb_v = '1' then
                     matrix_q(7)(1) <= release_s;
                  end if;

                  keymap_seq_s := KM_IDLE;
            end case;
         end if;
      end if;
   end process;

end architecture;
