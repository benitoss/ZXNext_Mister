
-- HDMI Frame
-- Copyright 2020 Victor Trucco
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
use IEEE.std_logic_unsigned.ALL;

entity hdmi_frame is
   port
   (
      clock_i     : in std_logic;
      clock2X_i   : in std_logic;
      reset_i     : in std_logic;
      scanlines_i : in std_logic_vector(1 downto 0);  
      
      rgb_i       : in std_logic_vector(8 downto 0);
      hsync_i     : in std_logic;
      vsync_i     : in std_logic;
      hblank_n_i  : in std_logic;
      vblank_n_i  : in std_logic;
      timing_i    : in std_logic_vector(2 downto 0);
      
      rgb_o       : out std_logic_vector(8 downto 0);
      hsync_o     : out std_logic;
      vsync_o     : out std_logic;
      
      blank_o  : out std_logic;

      -- config values
      h_visible         : in integer := 720 - 1;
      hsync_start       : in integer := 732 - 1;
      hsync_end         : in integer := 796 - 1;
      hcnt_end          : in integer := 864 - 1;
      --
      v_visible         : in integer := 576 - 1;
      vsync_start       : in integer := 581 - 1;
      vsync_end         : in integer := 586 - 1;
      vcnt_end          : in integer := 625 - 2
   );
end entity;

architecture rtl of hdmi_frame is   
   
   signal input_addr_s  : std_logic_vector(10 downto 0) := (others=>'0');
   signal output_addr_s: std_logic_vector(10 downto 0) := (others=>'0');
   
   signal rgb_s      : std_logic_vector(8 downto 0);
   signal rgb_r_25      : std_logic_vector(3 downto 0);
   signal rgb_g_25      : std_logic_vector(3 downto 0);
   signal rgb_b_25      : std_logic_vector(3 downto 0);
   signal rgb_r_12      : std_logic_vector(3 downto 0);
   signal rgb_g_12      : std_logic_vector(3 downto 0);
   signal rgb_b_12      : std_logic_vector(3 downto 0);
   signal pixel_out     : std_logic_vector(8 downto 0);
   signal max_scanline     : std_logic_vector(9 downto 0):= (others=>'0');
   
   signal hsync_s    : std_logic := '1';
   signal vsync_s    : std_logic := '1';
   signal odd_line_s : std_logic := '0';

   signal locked_s   : std_logic := '0';
   signal locked_x   : std_logic := '0';
   signal locked_y   : std_logic := '0';
   
   signal vs_counter_s  : std_logic_vector(15 downto 0):= (others=>'0');
   
   

   --ModeLine "720x480@60"       27.00    720   736   798   858      480   489   495   525 
   -- Horizontal Timing constants  
-- constant h_visible   : integer := 720 - 1;
-- constant hsync_start       : integer := 736 - 1;
-- constant hsync_end         : integer := 798 - 1;
-- constant hcnt_end       : integer := 858 - 1;
-- -- Vertical Timing constants
-- constant v_visible      : integer := 480 - 1;
-- constant vsync_start       : integer := 489 - 1;
-- constant vsync_end         : integer := 495 - 1;
-- constant vcnt_end       : integer := 525 - 2;

   
   
-- ----Modeline "720x576x50hz"   27    720   732   796   864      576   581   586   625 
-- -- Horizontal Timing constants  
-- constant h_visible   : integer := 720 - 1;
-- constant hsync_start       : integer := 732 - 1;
-- constant hsync_end         : integer := 796 - 1;
-- constant hcnt_end       : integer := 864 - 1;
-- -- Vertical Timing constants
-- constant v_visible      : integer := 576 - 1;
-- constant vsync_start       : integer := 581 - 1;
-- constant vsync_end         : integer := 586 - 1;
-- constant vcnt_end       : integer := 625 - 2;

   
   --
   signal hcnt          : std_logic_vector(9 downto 0) := (others => '0');
   signal h             : std_logic_vector(9 downto 0) := (others => '0');
-- signal vcnt          : std_logic_vector(9 downto 0) := (others => '0');
-- signal vcnt          : std_logic_vector(9 downto 0) := "0000110010"; --50 (initial vertical adjust) 60hz
-- signal vcnt          : std_logic_vector(9 downto 0) := "0001011010"; --90 (initial vertical adjust)
-- signal vcnt          : std_logic_vector(9 downto 0) := "0001100100"; --100 (initial vertical adjust)
-- signal vcnt          : std_logic_vector(9 downto 0) := "0010010110"; --150 (initial vertical adjust)

   signal vcnt          : std_logic_vector(9 downto 0) := (others => '0');--std_logic_vector(to_unsigned(ver_adj,10));


   signal blank         : std_logic;
   signal picture       : std_logic;
   
   signal line_bank     : std_logic := '0';
   


   signal timing_selected_s : std_logic_vector (2 downto 0) := "000";
   

   signal egde_vb : std_logic_vector(1 downto 0) := "11";
   signal egde_hb : std_logic_vector(1 downto 0) := "11";


begin

   --ModeLine "720x480@60"       27.00    720   736   798   858      480   489   495   525 
   -- Horizontal Timing constants  
-- constant h_visible   : integer := 720 - 1;
-- constant hsync_start       : integer := 736 - 1;
-- constant hsync_end         : integer := 798 - 1;
-- constant hcnt_end       : integer := 858 - 1;
-- -- Vertical Timing constants
-- constant v_visible      : integer := 480 - 1;
-- constant vsync_start       : integer := 489 - 1;
-- constant vsync_end         : integer := 495 - 1;
-- constant vcnt_end       : integer := 525 - 2;

   
   
   ----Modeline "720x576x50hz"   27    720   732   796   864      576   581   586   625 
   -- Horizontal Timing constants  
-- constant h_visible   : integer := 720 - 1;
-- constant hsync_start       : integer := 732 - 1;
-- constant hsync_end         : integer := 796 - 1;
-- constant hcnt_end       : integer := 864 - 1;
-- -- Vertical Timing constants
-- constant v_visible      : integer := 576 - 1;
-- constant vsync_start       : integer := 581 - 1;
-- constant vsync_end         : integer := 586 - 1;
-- constant vcnt_end       : integer := 625 - 2;

   locked_s <= locked_x and locked_y;
      
   process (clock2X_i)
   begin
   
      if rising_edge(clock2X_i) then

         if reset_i = '1' then
         
            locked_x <= '0';
            locked_y <= '0';
            
            hcnt <= (others => '0');
            vcnt <= (others => '0');
            
            odd_line_s <= '0';
            
            egde_hb <= "11";
            egde_vb <= "11";
            
         elsif (timing_i /= "111") or (timing_i /= timing_selected_s) then
         
            timing_selected_s <= timing_i;
            
            locked_x <= '0';
            locked_y <= '0';
            
            hcnt <= (others => '0');
            vcnt <= (others => '0');
            
            odd_line_s <= '0';

            egde_hb <= "11";
            egde_vb <= "11";
         
         else
         
            egde_hb <= egde_hb(0) & hblank_n_i;    
            
            if locked_x = '0' and egde_hb = "01" then
            
               locked_x <= '1';
               hcnt <= (others => '0');

            elsif hcnt = hcnt_end then
            
               hcnt <= (others => '0');
            
            else
            
               hcnt <= hcnt + 1;

            end if;
            
            if locked_x = '1' and (hcnt = hsync_start) then
            
               egde_vb <= egde_vb(0) & vblank_n_i;
               
               if egde_vb = "01" then
               
                  locked_y <= '1';
                  
                  vcnt <= (others => '0');
                  odd_line_s <= '0';
               
               else
               
                  vcnt <= vcnt + 1;
                  odd_line_s <= not odd_line_s;
               
               end if;
            
            end if;

         end if;
      
      end if;
   
   end process;

   scandoubler_ram : entity work.dpram2
   generic map (
      addr_width_g   => 11,
      data_width_g   => 9
   )
   port map (
      clk_a_i     => clock_i,
      we_i        => '1',
      addr_a_i    => input_addr_s,
      data_a_i    => rgb_i,
      data_a_o    => open,
      --
      clk_b_i     => clock2X_i,
      addr_b_i    => output_addr_s,
      data_b_o    => rgb_s
   );
      
   process (clock_i)
   variable egde_hb_2 : std_logic_vector(1 downto 0);
   begin
   
      if rising_edge(clock_i) then
         
         egde_hb_2 := egde_hb_2(0) & hblank_n_i;   
         
         if egde_hb_2 = "01" then -- rising edge of hblank
            input_addr_s <= (not line_bank) & "0000000000";
            line_bank <= not line_bank;
         else
            input_addr_s <= input_addr_s + 1;
         end if;
            
      end if;
      
   end process;
   
   process (clock2X_i)
   begin
   
      if rising_edge(clock2X_i) then
         output_addr_s <= ((not line_bank) & hcnt);-- + hcnt_adj;
      end if;
      
   end process;
   
   rgb_r_25 <= std_logic_vector(unsigned('0' & rgb_s(8 downto 6)) + unsigned("00" & rgb_s(8 downto 7)));
   rgb_g_25 <= std_logic_vector(unsigned('0' & rgb_s(5 downto 3)) + unsigned("00" & rgb_s(5 downto 4)));
   rgb_b_25 <= std_logic_vector(unsigned('0' & rgb_s(2 downto 0)) + unsigned("00" & rgb_s(2 downto 1)));
   
   rgb_r_12 <= std_logic_vector(unsigned(rgb_r_25) + unsigned("000" & rgb_s(8 downto 8)));
   rgb_g_12 <= std_logic_vector(unsigned(rgb_g_25) + unsigned("000" & rgb_s(5 downto 5)));
   rgb_b_12 <= std_logic_vector(unsigned(rgb_b_25) + unsigned("000" & rgb_s(2 downto 2)));
   
   pixel_out <=   ('0' & rgb_s(8 downto 7) & '0' & rgb_s(5 downto 4) & '0' & rgb_s(2 downto 1)) when odd_line_s = '1' and scanlines_i = "01" else -- 50%
                  (rgb_r_25(3 downto 1) & rgb_g_25(3 downto 1) & rgb_b_25(3 downto 1)) when odd_line_s = '1' and scanlines_i = "10" else -- 25%
                  (rgb_r_12(3 downto 1) & rgb_g_12(3 downto 1) & rgb_b_12(3 downto 1)) when odd_line_s = '1' and scanlines_i = "11" else -- 12.5%
                  rgb_s;

   process (clock2X_i)
   begin
      if rising_edge(clock2X_i) then
         if locked_s = '0' then
         
            blank_o <= '1';
            hsync_o <= '1';
            vsync_o <= '1';
            rgb_o <= (others => '0');
            
         else
         
            if (hcnt > h_visible) or (vcnt > v_visible) then
               blank_o <= '1';
               rgb_o <= (others => '0');
            else
               blank_o <= '0';
               rgb_o <= pixel_out;
            end if;
            
            if (hcnt <= hsync_start) or (hcnt > hsync_end) then
               hsync_o <= '1';
            else
               hsync_o <= '0';
            end if;
            
            if (vcnt <= vsync_start) or (vcnt > vsync_end) then
               vsync_o <= '1';
            else
               vsync_o <= '0';
            end if;

         end if;
      end if;
   end process;

end architecture;
