
-- ZX Spectrum Next Implementation
-- Copyright 2020 Alvin Albrecht, Victor Trucco and Fabio Belavenuto
--
-- TBBlue - Victor Trucco & Fabio Belavenuto
-- ZXNext Refactor - Alvin Albrecht
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
use IEEE.NUMERIC_STD.ALL;
use IEEE.std_logic_unsigned.ALL;
use work.Z80N_pack.all;

entity zxnext is
   generic
   (
      g_machine_id         : unsigned(7 downto 0);
      g_version            : unsigned(7 downto 0);
      g_sub_version        : unsigned(7 downto 0)
   );
   port (
      -- CLOCK
      
      i_CLK_28             : in std_logic;      -- 28MHz for machine logic
      i_CLK_28_n           : in std_logic;      -- 28MHz inverted
      i_CLK_14             : in std_logic;      -- 14MHz hi-res pixel clock
      i_CLK_7              : in std_logic;      -- 7MHz pixel clock
      i_CLK_CPU            : in std_logic;      -- CPU clock adjusted for speed and contention
      i_CLK_PSG_EN         : in std_logic;      -- 28MHz clock enable for PSG

      o_CPU_SPEED          : out std_logic_vector(1 downto 0);    -- cpu speed selection 00 = 3.5, 01 = 7, 10 = 14, 11 = 28
      o_CPU_CONTEND        : out std_logic;     -- indicates cpu is contended
      o_CPU_CLK_LSB        : out std_logic;     -- the contended cpu clock is derived from the pixel counter lsb
      
      -- RESET

      i_RESET_HARD         : in std_logic;      -- reboot in config mode, duration counted in top module
      i_RESET_SOFT         : in std_logic;      -- reset current system, duration counted in top module
      
      o_RESET_SOFT         : out std_logic;     -- asserted for one cycle at 28MHz
      o_RESET_HARD         : out std_logic;     -- asserted for one cycle at 28MHz
      o_RESET_PERIPHERAL   : out std_logic;     -- asserted under sw control for esp / exp bus reset
      
      -- FLASH BOOT
      
      o_FLASH_BOOT         : out std_logic;                       -- load new core
      o_CORE_ID            : out std_logic_vector(4 downto 0);    -- core id 0-31
      
      -- SPECIAL KEYS

      i_SPKEY_FUNCTION     : in std_logic_vector(10 downto 1);    -- F10 through F1
      i_SPKEY_BUTTONS      : in std_logic_vector(1 downto 0);     -- raw state of nmi buttons m1(0) & drive(1)
      
      -- MEMBRANE KEYBOARD
      
      o_KBD_CANCEL         : out std_logic;                       -- cancel entering extended keys into standard 8x5 matrix
      
      o_KBD_ROW            : out std_logic_vector(7 downto 0);    -- A15:A8 in keyboard read
      i_KBD_COL            : in std_logic_vector(4 downto 0);     -- D4:D0 in keyboard read (D6:D5 are the new keys)
      
      i_KBD_EXTENDED_KEYS  : in std_logic_vector(15 downto 0);    -- state of extended keys independent of matrix
      
      -- PS/2 KEYBOARD SETUP
      
      o_KEYMAP_ADDR        : out std_logic_vector(8 downto 0);    -- keymap address
      o_KEYMAP_DATA        : out std_logic_vector(8 downto 0);    -- keymap data
      o_KEYMAP_WE          : out std_logic;                       -- write signal
      
      -- JOYSTICK
      
      i_JOY_LEFT           : in std_logic_vector(10 downto 0);    -- active high  X Z Y START A C B U D L R
      i_JOY_RIGHT          : in std_logic_vector(10 downto 0);    -- active high  X Z Y START A C B U D L R
      
      o_JOY_IO_MODE        : out std_logic_vector(1 downto 0);    -- x1 = io mode enabled, 1x = clock io mode selected
      o_JOY_IO_MODE_LR     : out std_logic;
      o_JOY_IO_MODE_PIN_7  : out std_logic;                       -- state of pin 7 if in io mode direct or clock speed if in io mode clock
      
      -- MOUSE
      
      i_MOUSE_X            : in std_logic_vector(7 downto 0);
      i_MOUSE_Y            : in std_logic_vector(7 downto 0);
      i_MOUSE_BUTTON       : in std_logic_vector(2 downto 0);     -- M, R, L
      i_MOUSE_WHEEL        : in std_logic_vector(3 downto 0);
      
      o_PS2_MODE           : out std_logic;
      o_MOUSE_CONTROL      : out std_logic_vector(2 downto 0);    -- Button reverse, DPI(1:0)
      
      -- I2C
      
      i_I2C_SCL_n          : in std_logic;
      i_I2C_SDA_n          : in std_logic;
      
      o_I2C_SCL_n          : out std_logic;     -- 0 = assert, 1 = tristate
      o_I2C_SDA_n          : out std_logic;     -- 0 = assert, 1 = tristate
      
      -- SPI

      o_SPI_SS_FLASH_n     : out std_logic;
      o_SPI_SS_SD1_n       : out std_logic;
      o_SPI_SS_SD0_n       : out std_logic;

      o_SPI_SCK            : out std_logic;
      o_SPI_MOSI           : out std_logic;
      
      i_SPI_SD_MISO        : in std_logic;
      i_SPI_FLASH_MISO     : in std_logic;
      
      -- UART
      
      i_UART0_RX           : in std_logic;
      o_UART0_TX           : out std_logic;
      
      -- VIDEO
      -- synchronized to i_CLK_14
      
      o_RGB                : out std_logic_vector(8 downto 0);    -- RGB333
      o_RGB_CS_n           : out std_logic;                       -- csync
      o_RGB_VS_n           : out std_logic;                       -- vsync
      o_RGB_HS_n           : out std_logic;                       -- hsync
      o_RGB_VB_n           : out std_logic;                       -- vblank
      o_RGB_HB_n           : out std_logic;                       -- hblank
      
      o_VIDEO_50_60        : out std_logic;                       -- 0 = 50Hz, 1 = 60Hz
      o_VIDEO_SCANLINES    : out std_logic_vector(1 downto 0);    -- 
      o_VIDEO_SCANDOUBLE   : out std_logic;                       -- 
      
      o_VIDEO_MODE         : out std_logic_vector(2 downto 0);    -- video mode: VGA 0-6, HDMI
      o_MACHINE_TIMING     : out std_logic_vector(2 downto 0);    -- machine timing: 00X = 48k, 010 = 128k, 011 = +3, 100 = pentagon
      
      o_HDMI_RESET         : out std_logic;
      
      -- AUDIO
      
      o_AUDIO_HDMI_AUDIO_EN : out std_logic;

      o_AUDIO_SPEAKER_EN   : out std_logic;     -- enable internal speaker
      o_AUDIO_SPEAKER_BEEP : out std_logic;     -- only beep to internal speaker
      
      i_AUDIO_EAR          : in std_logic;      -- tape in
      o_AUDIO_MIC          : out std_logic;     -- tape out
      
      o_AUDIO_SPEAKER_EAR  : out std_logic;
      o_AUDIO_SPEAKER_MIC  : out std_logic;

      o_AUDIO_L            : out std_logic_vector(12 downto 0);   -- pcm audio
      o_AUDIO_R            : out std_logic_vector(12 downto 0);   -- pcm audio

      -- EXTERNAL SRAM (synchronized to i_CLK_28)
      -- memory transactions complete after one cycle, data read is registered a cycle later but is available asap
      
      -- Port A is read/write and highest priority (CPU)
      
      o_RAM_A_ADDR         : out std_logic_vector(20 downto 0);   -- 2MB memory space
      o_RAM_A_REQ          : out std_logic;                       -- '1' indicates memory request on next rising edge
      o_RAM_A_RD           : out std_logic;                       -- '1' for read, '0' for write
      i_RAM_A_DI           : in std_logic_vector(7 downto 0);     -- data read from memory
      o_RAM_A_DO           : out std_logic_vector(7 downto 0);    -- data written to memory
      
      -- Port B is read only (LAYER 2)
      
      o_RAM_B_ADDR         : out std_logic_vector(20 downto 0);   -- 2MB memory space
      o_RAM_B_REQ_T        : out std_logic;                       -- toggle indicates memory request
      i_RAM_B_DI           : in std_logic_vector(7 downto 0);     -- data read from memory
      
      -- EXPANSION BUS
      
      o_BUS_ADDR           : out std_logic_vector(15 downto 0);   -- unidirectional address bus = no external DMA for now
      i_BUS_DI             : in std_logic_vector(7 downto 0);     -- data bus in from external connector
      o_BUS_DO             : out std_logic_vector(7 downto 0);    -- data bus out to external connector
      o_BUS_MREQ_n         : out std_logic;
      o_BUS_IORQ_n         : out std_logic;
      o_BUS_RD_n           : out std_logic;
      o_BUS_WR_n           : out std_logic;
      o_BUS_M1_n           : out std_logic;
      i_BUS_WAIT_n         : in std_logic;
      i_BUS_NMI_n          : in std_logic;
      i_BUS_INT_n          : in std_logic;
      o_BUS_INT_n          : out std_logic;
      i_BUS_BUSREQ_n       : in std_logic;
      o_BUS_BUSAK_n        : out std_logic;
      o_BUS_HALT_n         : out std_logic;
      o_BUS_RFSH_n         : out std_logic;
      
      i_BUS_ROMCS_n        : in std_logic;                        -- 1 disables internal rom
--    i_BUS_RAMCS_n        : in std_logic;
      i_BUS_IORQULA_n      : in std_logic;                        -- 1 disables port fe
      
      o_BUS_EN             : out std_logic;                       -- enable the expansion bus, changes on rising edge of cpu clock
      o_BUS_CLKEN          : out std_logic;                       -- 1 to keep 3.5MHz clock on the expansion bus even when off
      
      o_BUS_NMI_DEBOUNCE_DISABLE  : out std_logic;
      
      -- ESP GPIO
      
      i_ESP_GPIO_20        : in std_logic_vector(2 downto 0);
      
      o_ESP_GPIO_0         : out std_logic;
      o_ESP_GPIO_0_EN      : out std_logic;                       -- 0 = high Z
      
      -- PI GPIO
      
      i_GPIO               : in std_logic_vector(27 downto 0);
      
      o_GPIO               : out std_logic_vector(27 downto 0);
      o_GPIO_EN            : out std_logic_vector(27 downto 0)    -- 0 = high Z
   );
end entity;

architecture rtl of zxnext is

   -- RESET
   
   signal reset                  : std_logic;
   signal reset_soft             : std_logic;
   signal reset_hard             : std_logic;
   
   -- Z80 & DMA
   
   signal z80_wait_n             : std_logic;
   signal z80_int_n              : std_logic;
   signal z80_nmi_n              : std_logic;
   signal z80_busrq_n            : std_logic;
   signal z80_m1_n               : std_logic;
   signal z80_mreq_n             : std_logic;
   signal z80_iorq_n             : std_logic;
   signal z80_rd_n               : std_logic;
   signal z80_wr_n               : std_logic;
   signal z80_rfsh_n             : std_logic;
   signal z80_halt_n             : std_logic;
   signal z80_busak_n            : std_logic;
   signal z80_a                  : std_logic_vector(15 downto 0);
   signal z80_do                 : std_logic_vector(7 downto 0);
   signal Z80N_dout_s            : std_logic;
   signal Z80N_data_s            : std_logic_vector(15 downto 0);
   signal Z80N_command_s         : Z80N_seq;

   signal dma_wait_n             : std_logic;
   signal dma_busrq_n            : std_logic;
   signal dma_a                  : std_logic_vector(15 downto 0);
   signal dma_do                 : std_logic_vector(7 downto 0);
   signal dma_rd_n               : std_logic;
   signal dma_wr_n               : std_logic;
   signal dma_mreq_n             : std_logic;
   signal dma_iorq_n             : std_logic;
   
   signal port_dma_dat_0         : std_logic_vector(7 downto 0);
   signal port_dma_dat           : std_logic_vector(7 downto 0);
   signal dma_mode               : std_logic := '0';
   
   signal dma_holds_bus          : std_logic;
   signal cpu_m1_n               : std_logic;
   signal cpu_mreq_n             : std_logic;
   signal cpu_iorq_n             : std_logic;
   signal cpu_rd_n               : std_logic;
   signal cpu_wr_n               : std_logic;
   signal cpu_rfsh_n             : std_logic;
   signal cpu_halt_n             : std_logic;
   signal cpu_a                  : std_logic_vector(15 downto 0);
   signal cpu_di                 : std_logic_vector(7 downto 0);
   signal cpu_do                 : std_logic_vector(7 downto 0);
   
   signal cpu_di_mem             : std_logic_vector(7 downto 0);
   signal cpu_di_io              : std_logic_vector(7 downto 0);
   
   signal nmi_activated          : std_logic;
   signal nmi_expbus_en          : std_logic;
   signal nmi_assert_expbus      : std_logic;
   signal nmi_mf                 : std_logic := '0';
   signal nmi_divmmc             : std_logic := '0';
   signal nmi_expbus             : std_logic := '0';
   signal nmi_hold               : std_logic;
   
   type   nmi_state_t            is (S_NMI_IDLE, S_NMI_ASSERT, S_NMI_OPUS, S_NMI_HOLD, S_NMI_END);
   signal nmi_state              : nmi_state_t := S_NMI_IDLE;
   signal nmi_state_next         : nmi_state_t;
   signal nmi_holding            : std_logic;
   signal nmi_opus               : std_logic;
   signal nmi_generate_n         : std_logic;
   signal nmi_mf_button          : std_logic;
   signal nmi_divmmc_button      : std_logic;
   
   -- EXPANSION BUS
   
   signal nr_80_expbus           : std_logic_vector(7 downto 0) := X"00";

   signal expbus_en              : std_logic;
   signal expbus_romcs_replace   : std_logic;
   signal expbus_disable_io      : std_logic;
   signal expbus_disable_mem     : std_logic;
   signal expbus_clken           : std_logic;
   signal expbus_speed           : std_logic_vector(1 downto 0);
   
   signal expbus_eff_en          : std_logic := '0';
   signal expbus_eff_disable_io  : std_logic := '0';
   signal expbus_eff_disable_mem : std_logic := '0';
   signal expbus_eff_clken       : std_logic := '0';
   
   signal port_propagate_fe      : std_logic;
   signal port_propagate_7ffd    : std_logic;
   signal port_propagate_dffd    : std_logic;
   signal port_propagate_1ffd    : std_logic;
   signal port_propagate_ff      : std_logic;
   signal port_propagate_eff7    : std_logic;
   
   signal port_propagate         : std_logic;
   signal bus_iorq_n             : std_logic;
   signal bus_mreq_n             : std_logic;
   
   -- ALTERNATIVE ROM
   
   signal nr_8c_altrom           : std_logic_vector(7 downto 0) := X"00";
   
   signal nr_8c_altrom_en        : std_logic;
   signal nr_8c_altrom_rw        : std_logic;
   signal nr_8c_altrom_lock_rom1 : std_logic;
   signal nr_8c_altrom_lock_rom0 : std_logic;

   -- PI GPIO
   
   signal pi_gpio_en             : std_logic_vector(27 downto 0);
   signal pi_gpio_o              : std_logic_vector(27 downto 0);
   
   signal pi_uart_rxtx           : std_logic;
   signal pi_uart_en             : std_logic;
   signal pi_i2c1_en             : std_logic;
   signal pi_spi0_en             : std_logic;
   
   signal pi_i2s_en              : std_logic;
   signal pi_i2s_enL             : std_logic;
   signal pi_i2s_enR             : std_logic;
   signal pi_i2s_inout           : std_logic;
   signal pi_i2s_muteL           : std_logic;
   signal pi_i2s_muteR           : std_logic;
-- signal pi_i2s_slave           : std_logic;
   signal pi_i2s_ear             : std_logic;
   
   signal gpio_07_en             : std_logic;
   signal gpio_07                : std_logic;
   signal gpio_08_en             : std_logic;
   signal gpio_08                : std_logic;
   signal gpio_09_en             : std_logic;
   signal pi_spi0_miso           : std_logic;
   signal gpio_10_en             : std_logic;
   signal gpio_10                : std_logic;
   signal gpio_11_en             : std_logic;
   signal gpio_11                : std_logic;
   
   signal gpio_02_en             : std_logic;
   signal gpio_02                : std_logic;
   signal gpio_03_en             : std_logic;
   signal gpio_03                : std_logic;
   signal pi_i2c1_sda            : std_logic;
   signal pi_i2c1_scl            : std_logic;
   
   signal gpio_14_en             : std_logic;
   signal gpio_14                : std_logic;
   signal gpio_15_en             : std_logic;
   signal gpio_15                : std_logic;
   signal pi_uart_rx             : std_logic;
   
   signal gpio_18_en             : std_logic;
   signal gpio_18                : std_logic;
   signal gpio_19_en             : std_logic;
   signal gpio_19                : std_logic;
   signal gpio_20_en             : std_logic;
   signal gpio_20                : std_logic;
   signal gpio_21_en             : std_logic;
   signal gpio_21                : std_logic;
   
   signal pi_audio_L             : std_logic_vector(9 downto 0);
   signal pi_audio_R             : std_logic_vector(9 downto 0);
   signal pi_fe_threshold        : std_logic_vector(1 downto 0);
   signal pi_fe_ear              : std_logic;
   
   -- PORT DECODING
   
   signal internal_port_enable   : std_logic_vector(27 downto 0);
   
   signal port_ff_io_en          : std_logic;
   signal port_7ffd_io_en        : std_logic;
   signal port_dffd_io_en        : std_logic;
   signal port_1ffd_io_en        : std_logic;
   signal port_p3_floating_bus_io_en         : std_logic;
   signal port_dma_6b_io_en      : std_logic;
   signal port_1f_io_en          : std_logic;
   signal port_37_io_en          : std_logic;
   signal port_divmmc_io_en      : std_logic;
   signal port_divmmc_io_en_diff             : std_logic;
   signal port_multiface_io_en   : std_logic;
   signal port_multiface_io_en_diff          : std_logic;
   signal port_i2c_io_en         : std_logic;
   signal port_spi_io_en         : std_logic;
   signal port_uart_io_en        : std_logic;
   signal port_mouse_io_en       : std_logic;
   signal port_sprite_io_en      : std_logic;
   signal port_layer2_io_en      : std_logic;
   signal port_ay_io_en          : std_logic;
   signal port_dac_sd1_ABCD_1f0f4f5f_io_en   : std_logic;
   signal port_dac_sd2_ABCD_f1f3f9fb_io_en   : std_logic;
   signal port_dac_stereo_AD_3f5f_io_en      : std_logic;
   signal port_dac_stereo_BC_0f4f_io_en      : std_logic;
   signal port_dac_mono_AD_fb_io_en          : std_logic;
   signal port_dac_mono_BC_b3_io_en          : std_logic;
   signal port_dac_mono_AD_df_io_en          : std_logic;
   signal port_ulap_io_en        : std_logic;
   signal port_dma_0b_io_en      : std_logic;
   signal port_eff7_io_en        : std_logic;
   signal port_ctc_io_en         : std_logic;
   
   signal port_1f_hw_en          : std_logic;
   signal port_37_hw_en          : std_logic;
   signal p3_timing_hw_en        : std_logic;
   signal s128_timing_hw_en      : std_logic;
   signal dac_hw_en              : std_logic;
   
   signal bus_iorq_ula           : std_logic := '0';

   signal port_00xx_msb          : std_logic;
   signal port_04xx_msb          : std_logic;
   signal port_05xx_msb          : std_logic;
   signal port_10xx_msb          : std_logic;
   signal port_11xx_msb          : std_logic;
   signal port_12xx_msb          : std_logic;
   signal port_13xx_msb          : std_logic;
   signal port_14xx_msb          : std_logic;
   signal port_15xx_msb          : std_logic;
   signal port_1fxx_msb          : std_logic;
   signal port_24xx_msb          : std_logic;
   signal port_25xx_msb          : std_logic;
   signal port_30xx_msb          : std_logic;
   signal port_3dxx_msb          : std_logic;
   signal port_7fxx_msb          : std_logic;
   signal port_bfxx_msb          : std_logic;
   signal port_fexx_msb          : std_logic;
   signal port_ffxx_msb          : std_logic;

   signal port_00_lsb            : std_logic;
   signal port_08_lsb            : std_logic;
   signal port_0b_lsb            : std_logic;
   signal port_0f_lsb            : std_logic;
   signal port_1f_lsb            : std_logic;
   signal port_37_lsb            : std_logic;
   signal port_38_lsb            : std_logic;
   signal port_3f_lsb            : std_logic;
   signal port_3b_lsb            : std_logic;
   signal port_4f_lsb            : std_logic;
   signal port_57_lsb            : std_logic;
   signal port_5b_lsb            : std_logic;
   signal port_5f_lsb            : std_logic;
   signal port_62_lsb            : std_logic;
   signal port_66_lsb            : std_logic;
   signal port_6b_lsb            : std_logic;
   signal port_b3_lsb            : std_logic;
   signal port_c6_lsb            : std_logic;
   signal port_df_lsb            : std_logic;
   signal port_e3_lsb            : std_logic;
   signal port_e7_lsb            : std_logic;
   signal port_eb_lsb            : std_logic;
   signal port_f1_lsb            : std_logic;
   signal port_f3_lsb            : std_logic;
   signal port_f7_lsb            : std_logic;
   signal port_f9_lsb            : std_logic;
   signal port_fb_lsb            : std_logic;
   signal port_ff_lsb            : std_logic;
   
   signal port_fe                : std_logic;
   signal port_ff                : std_logic;
   signal port_fe_override       : std_logic;
   signal port_fd                : std_logic;
   signal port_p3_float          : std_logic;
-- signal port_p3_float_active   : std_logic;
   signal port_7ffd              : std_logic;
   signal port_7ffd_active       : std_logic;
   signal port_7ffd_assert       : std_logic;
   signal port_dffd              : std_logic;
   signal port_1ffd              : std_logic;
-- signal port_1ffd_active       : std_logic;
   signal port_1ffd_assert       : std_logic;
   signal port_eff7              : std_logic;
   signal port_e3                : std_logic;
   signal port_mf_enable_io_a    : std_logic_vector(7 downto 0);
   signal port_mf_disable_io_a   : std_logic_vector(7 downto 0);
   signal port_mf_enable         : std_logic;
   signal port_mf_disable        : std_logic;
   signal port_e7                : std_logic;
   signal port_eb                : std_logic;
   signal port_243b              : std_logic;
   signal port_253b              : std_logic;
   signal port_103b              : std_logic;
   signal port_113b              : std_logic;
   signal port_123b              : std_logic;
   signal port_133b              : std_logic;
   signal port_143b              : std_logic;
   signal port_153b              : std_logic;
   signal port_dma               : std_logic;
   signal port_fffd              : std_logic;
   signal port_bffd              : std_logic;
   signal port_dac_mono_AD       : std_logic;
   signal port_dac_mono_BC       : std_logic;
   signal port_dac_A             : std_logic;
   signal port_dac_B             : std_logic;
   signal port_dac_C             : std_logic;
   signal port_dac_D             : std_logic;
   signal port_fadf              : std_logic;
   signal port_fbdf              : std_logic;
   signal port_ffdf              : std_logic;
   signal port_1f                : std_logic;
   signal port_37                : std_logic;
   signal port_57                : std_logic;
   signal port_5b                : std_logic;
   signal port_303b              : std_logic;
   signal port_bf3b              : std_logic;
   signal port_ff3b              : std_logic;
   signal port_ctc               : std_logic;
   signal port_internal_response : std_logic;
   
   signal iord                   : std_logic;
   signal iowr                   : std_logic;
   
   signal port_fd_conflict_wr    : std_logic;
   
   signal port_fe_rd             : std_logic;
   signal port_fe_wr             : std_logic;
   signal port_ff_rd             : std_logic;
   signal port_ff_wr             : std_logic;
   signal port_p3_float_rd       : std_logic;
   signal port_7ffd_wr           : std_logic;
   signal port_dffd_wr           : std_logic;
   signal port_1ffd_wr           : std_logic;
   signal port_eff7_wr           : std_logic;
   signal port_e3_rd             : std_logic;
   signal port_e3_wr             : std_logic;
   signal port_mf_enable_rd      : std_logic;
   signal port_mf_enable_wr      : std_logic;
   signal port_mf_disable_rd     : std_logic;
   signal port_mf_disable_wr     : std_logic;
   signal port_e7_wr             : std_logic;
   signal port_eb_rd             : std_logic;
   signal port_eb_wr             : std_logic;
   signal port_243b_rd           : std_logic;
   signal port_243b_wr           : std_logic;
   signal port_253b_rd           : std_logic;
   signal port_253b_wr           : std_logic;
   signal port_103b_rd           : std_logic;
   signal port_103b_wr           : std_logic;
   signal port_113b_rd           : std_logic;
   signal port_113b_wr           : std_logic;
   signal port_123b_rd           : std_logic;
   signal port_123b_wr           : std_logic;
   signal port_133b_rd           : std_logic;
   signal port_133b_wr           : std_logic;
   signal port_143b_rd           : std_logic;
   signal port_143b_wr           : std_logic;
   signal port_153b_rd           : std_logic;
   signal port_153b_wr           : std_logic;
   signal port_dma_rd            : std_logic;
   signal port_dma_wr            : std_logic;
   signal port_fffd_rd           : std_logic;
   signal port_fffd_wr           : std_logic;
   signal port_bffd_wr           : std_logic;
   signal port_dac_A_wr          : std_logic;
   signal port_dac_B_wr          : std_logic;
   signal port_dac_C_wr          : std_logic;
   signal port_dac_D_wr          : std_logic;
   signal port_fadf_rd           : std_logic;
   signal port_fbdf_rd           : std_logic;
   signal port_ffdf_rd           : std_logic;
   signal port_1f_rd             : std_logic;
   signal port_37_rd             : std_logic;
   signal port_37_wr             : std_logic;
   signal port_57_wr             : std_logic;
   signal port_5b_wr             : std_logic;
   signal port_303b_rd           : std_logic;
   signal port_303b_wr           : std_logic;
   signal port_bf3b_wr           : std_logic;
   signal port_ff3b_rd           : std_logic;
   signal port_ff3b_wr           : std_logic;
   signal port_ctc_wr            : std_logic;
   signal port_ctc_rd            : std_logic;

   signal port_internal_rd_response          : std_logic;
   
   signal port_fe_rd_dat         : std_logic_vector(7 downto 0);
   signal port_ff_rd_dat         : std_logic_vector(7 downto 0);
   signal port_p3_float_rd_dat   : std_logic_vector(7 downto 0);
   signal port_e3_rd_dat         : std_logic_vector(7 downto 0);
   signal port_mf_rd_dat         : std_logic_vector(7 downto 0);
   signal port_eb_rd_dat         : std_logic_vector(7 downto 0);
   signal port_243b_rd_dat       : std_logic_vector(7 downto 0);
   signal port_253b_rd_dat       : std_logic_vector(7 downto 0);
   signal port_103b_rd_dat       : std_logic_vector(7 downto 0);
   signal port_113b_rd_dat       : std_logic_vector(7 downto 0);
   signal port_123b_rd_dat       : std_logic_vector(7 downto 0);
   signal port_133b_rd_dat       : std_logic_vector(7 downto 0);
   signal port_143b_rd_dat       : std_logic_vector(7 downto 0);
   signal port_153b_rd_dat       : std_logic_vector(7 downto 0);
   signal port_dma_rd_dat        : std_logic_vector(7 downto 0);
   signal port_fffd_rd_dat       : std_logic_vector(7 downto 0);
   signal port_fadf_rd_dat       : std_logic_vector(7 downto 0);
   signal port_fbdf_rd_dat       : std_logic_vector(7 downto 0);
   signal port_ffdf_rd_dat       : std_logic_vector(7 downto 0);
   signal port_1f_rd_dat         : std_logic_vector(7 downto 0);
   signal port_37_rd_dat         : std_logic_vector(7 downto 0);
   signal port_303b_rd_dat       : std_logic_vector(7 downto 0);
   signal port_ff3b_rd_dat       : std_logic_vector(7 downto 0);
   signal port_ctc_rd_dat        : std_logic_vector(7 downto 0);
   
   signal port_rd_dat            : std_logic_vector(7 downto 0);

   -- MEMORY ADDRESSES

   signal divmmc_automap_en_instant             : std_logic;
   signal divmmc_automap_en_delayed             : std_logic;
   signal divmmc_automap_en_delayed_nohide      : std_logic;
   signal divmmc_automap_en_delayed_nohide_nmi  : std_logic;
   signal divmmc_automap_dis_delayed            : std_logic;

   signal mf_a_0066              : std_logic;
   signal mf_a_1fxx              : std_logic;
   signal mf_a_7fxx              : std_logic;
   signal mf_a_fexx              : std_logic;

   -- MEMORY DECODING
   
   signal mem_active_page        : std_logic_vector(7 downto 0);
   
   signal layer2_active_bank_offset_pre      : std_logic_vector(1 downto 0);
   signal layer2_active_bank_offset          : std_logic_vector(3 downto 0);
   signal layer2_active_bank     : std_logic_vector(6 downto 0);
   signal layer2_active_page     : std_logic_vector(8 downto 0);
   
   signal sram_config_active     : std_logic;
   
   signal mmu_A21_A13            : std_logic_vector(8 downto 0);
   signal layer2_A21_A13         : std_logic_vector(8 downto 0);
   
   signal mem_active_bank5       : std_logic;
   signal mem_active_bank7       : std_logic;
   signal sram_active_rom        : std_logic_vector(1 downto 0);
   signal sram_rom3              : std_logic;
   signal sram_alt_128           : std_logic;
   signal eff_expbus_romcs_replace           : std_logic;
   
   signal layer2_pre_A21_A13     : std_logic_vector(8 downto 0);
   signal sram_pre_active        : std_logic;
   signal sram_pre_rom3          : std_logic;
   signal sram_pre_bank5         : std_logic;
   signal sram_pre_bank7         : std_logic;
   signal sram_pre_rdonly        : std_logic;
   signal sram_pre_romcs         : std_logic;
   signal sram_pre_alt_en        : std_logic;
   signal sram_pre_alt_128       : std_logic;
   signal port_123b_layer2_map_rd_pre        : std_logic;
   signal port_123b_layer2_map_wr_pre        : std_logic;
   signal port_123b_layer2_map_segment_pre   : std_logic_vector(1 downto 0);
   signal sram_pre_A20_A13       : std_logic_vector(7 downto 0);
   
   signal layer2_map_en          : std_logic;
   signal altrom_en              : std_logic;
   signal sram_A20_A13           : std_logic_vector(7 downto 0);
   signal sram_active            : std_logic;
   signal sram_bank5             : std_logic;
   signal sram_bank7             : std_logic;
   signal sram_rdonly            : std_logic;
   signal sram_romcs_en          : std_logic;
   signal sram_obscure_divmmc_automap        : std_logic;
   signal sram_disable_divmmc_automap        : std_logic;
   
   signal memcycle               : std_logic;
   signal memcycle_delay         : std_logic_vector(3 downto 0);
   signal memcycle_delay_end     : std_logic_vector(3 downto 0);
   signal memcycle_delay_complete            : std_logic;
   signal sram_romcs             : std_logic;
   signal cpu_bank5_rd           : std_logic;
   signal cpu_bank5_we           : std_logic;
   signal cpu_bank7_we           : std_logic;
   signal sram_addr              : std_logic_vector(20 downto 0);
   signal sram_rd                : std_logic;
   signal sram_req               : std_logic;
   signal sram_req_dly           : std_logic;
   signal sram_req_t             : std_logic;
   signal sram_wait_n            : std_logic := '1';
   
   signal bootrom_do             : std_logic_vector(7 downto 0);
   
   -- SERIAL COMMS
   
   signal i2c_scl_o              : std_logic;
   signal i2c_sda_o              : std_logic;
   signal port_103b_dat          : std_logic_vector(7 downto 0) := X"FF";
   signal port_113b_dat          : std_logic_vector(7 downto 0) := X"FF";

   signal spi_ss_flash_n         : std_logic;
   signal spi_ss_rpi1_n          : std_logic;
   signal spi_ss_rpi0_n          : std_logic;
   signal spi_ss_sd1_n           : std_logic;
   signal spi_ss_sd0_n           : std_logic;
   signal spi_sck                : std_logic;
   signal spi_mosi               : std_logic;
   signal spi_miso               : std_logic;
   signal spi_wait_n             : std_logic;
   signal port_eb_dat            : std_logic_vector(7 downto 0);
   signal port_e7_reg            : std_logic_vector(7 downto 0) := X"FF";
   
   signal uart0_tx_esp           : std_logic;
   signal uart1_tx_pi            : std_logic;
   
   signal uart0_tx_busy          : std_logic;
   signal uart0_tx               : std_logic;
   signal uart0_rx               : std_logic;
   signal uart0_rx_avail         : std_logic;
   signal uart0_rx_byte          : std_logic_vector(7 downto 0);
   
   signal uart0_fifo_empty       : std_logic;
   signal uart0_fifo_full        : std_logic;
   signal uart0_fifo_raddr       : std_logic_vector(8 downto 0);
   signal uart0_fifo_waddr       : std_logic_vector(8 downto 0);

   signal uart1_tx_busy          : std_logic;
   signal uart1_tx               : std_logic;
   signal uart1_rx               : std_logic;
   signal uart1_rx_avail         : std_logic;
   signal uart1_rx_byte          : std_logic_vector(7 downto 0);
   
   signal uart1_fifo_empty       : std_logic;
   signal uart1_fifo_full        : std_logic;
   signal uart1_fifo_raddr       : std_logic_vector(8 downto 0);
   signal uart1_fifo_waddr       : std_logic_vector(8 downto 0);
   
   signal uart0_143b_prescalar   : std_logic_vector(13 downto 0);
   signal uart1_143b_prescalar   : std_logic_vector(13 downto 0);
   signal uart_153b_select       : std_logic;
   signal uart0_153b_prescalar_msb           : std_logic_vector(2 downto 0);
   signal uart1_153b_prescalar_msb           : std_logic_vector(2 downto 0);

   signal port_153b_dat          : std_logic_vector(7 downto 0);
   signal port_133b_dat_20       : std_logic_vector(2 downto 0);
   signal port_133b_dat          : std_logic_vector(7 downto 0);
   
   signal uart0_rx_o             : std_logic_vector(7 downto 0);
   signal uart1_rx_o             : std_logic_vector(7 downto 0);
   
   signal uart0_rx_avail_dly     : std_logic;
   signal uart0_rx_byte_dly      : std_logic_vector(7 downto 0);
   signal uart0_fifo_addr        : std_logic_vector(8 downto 0);
   signal uart0_fifo_we          : std_logic;
   
   signal uart1_rx_avail_dly     : std_logic;
   signal uart1_rx_byte_dly      : std_logic_vector(7 downto 0);
   signal uart1_fifo_addr        : std_logic_vector(8 downto 0);
   signal uart1_fifo_we          : std_logic;
   
   signal port_143b_dat          : std_logic_vector(7 downto 0);
   
   -- KEYBOARD, JOYSTICKS & MOUSE
   
   signal keyrow                 : std_logic_vector(7 downto 0);
   
   signal joyL_up                : std_logic;
   signal joyR_up                : std_logic;
   
   signal joyL_sinc1             : std_logic_vector(4 downto 0);
   signal joyL_sinc2             : std_logic_vector(4 downto 0);
   signal joyL_cursA             : std_logic_vector(4 downto 0);
   signal joyL_cursB             : std_logic_vector(4 downto 0);
   
   signal joyR_sinc1             : std_logic_vector(4 downto 0);
   signal joyR_sinc2             : std_logic_vector(4 downto 0);
   signal joyR_cursA             : std_logic_vector(4 downto 0);
   signal joyR_cursB             : std_logic_vector(4 downto 0);
   
   signal joy_key                : std_logic_vector(4 downto 0);
   
   signal port_fe_bus            : std_logic_vector(7 downto 0);
   signal port_fe_dat_0          : std_logic_vector(7 downto 0);
   signal port_fe_dat            : std_logic_vector(7 downto 0);
   
   signal mdL_1f_en              : std_logic;
   signal mdL_37_en              : std_logic;
   signal joyL_1f_en             : std_logic;
   signal joyL_37_en             : std_logic;
   signal joyL_1f                : std_logic_vector(7 downto 0);
   signal joyL_37                : std_logic_vector(7 downto 0);
   
   signal mdR_1f_en              : std_logic;
   signal mdR_37_en              : std_logic;
   signal joyR_1f_en             : std_logic;
   signal joyR_37_en             : std_logic;
   signal joyR_1f                : std_logic_vector(7 downto 0);
   signal joyR_37                : std_logic_vector(7 downto 0);
   
   signal io_mode                : std_logic_vector(1 downto 0) := "00";
   signal io_mode_en             : std_logic := '0';
   signal io_mode_lr             : std_logic := '0';
   signal io_mode_bit_0          : std_logic := '1';
   signal io_mode_uart_en        : std_logic;
   signal io_mode_uart_rx        : std_logic;
   signal io_mode_uart_tx        : std_logic;
   signal io_mode_pin_7          : std_logic;
   
   signal port_1f_dat            : std_logic_vector(7 downto 0);
   signal port_37_dat            : std_logic_vector(7 downto 0);
   signal port_fbdf_dat          : std_logic_vector(7 downto 0);
   signal port_ffdf_dat          : std_logic_vector(7 downto 0);
   signal port_fadf_dat          : std_logic_vector(7 downto 0);
   
   -- DEVICES
   
   signal port_fe_reg            : std_logic_vector(4 downto 0);
   signal port_fe_ear            : std_logic;
   signal port_fe_mic            : std_logic;
   signal port_fe_border         : std_logic_vector(2 downto 0) := "000";
   
   signal port_ff_reg            : std_logic_vector(7 downto 0);
   signal port_ff_screen_mode    : std_logic_vector(5 downto 0);
   signal port_ff_interrupt_disable          : std_logic;
   
   signal port_7ffd_reg          : std_logic_vector(7 downto 0);
   signal port_7ffd_dat          : std_logic_vector(7 downto 0);
   signal port_7ffd_bank         : std_logic_vector(6 downto 0);
   signal port_7ffd_shadow       : std_logic;
   signal port_7ffd_locked       : std_logic;
   
   signal port_dffd_reg          : std_logic_vector(4 downto 0);
   signal port_dffd_reg_6        : std_logic;
   
   signal port_1ffd_reg          : std_logic_vector(7 downto 0);
   signal port_1ffd_dat          : std_logic_vector(7 downto 0);
   signal port_1ffd_special      : std_logic;
   signal port_1ffd_special_old  : std_logic;
   signal port_1ffd_rom          : std_logic_vector(1 downto 0);
   
   signal port_eff7_reg_2        : std_logic;
   signal port_eff7_reg_3        : std_logic;

   signal nr_8f_mapping_mode     : std_logic_vector(1 downto 0) := (others => '0');
   signal nr_8f_mapping_mode_profi           : std_logic;
   signal nr_8f_mapping_mode_pentagon        : std_logic;
   signal nr_8f_mapping_mode_pentagon_1024   : std_logic;
   signal nr_8f_mapping_mode_pentagon_1024_en: std_logic;

   signal port_memory_change_dly : std_logic := '0';
   signal port_memory_ram_change_dly         : std_logic := '0';
   signal nr_8f_we_dly           : std_logic := '0';
   
   signal port_123b_dat          : std_logic_vector(7 downto 0) := (others => '0');
   signal port_123b_layer2_en    : std_logic;
   signal port_123b_layer2_map_wr_en         : std_logic;
   signal port_123b_layer2_map_rd_en         : std_logic;
   signal port_123b_layer2_map_shadow        : std_logic;
   signal port_123b_layer2_map_segment       : std_logic_vector(1 downto 0);
   signal port_123b_layer2_offset            : std_logic_vector(2 downto 0);
   
   signal copper_instr_addr      : std_logic_vector(9 downto 0);
   signal copper_dout_en         : std_logic;
   signal copper_dout            : std_logic_vector(14 downto 0);
   signal copper_instr_data      : std_logic_vector(15 downto 0);
   signal copper_msb_we          : std_logic;
   signal copper_msb_dat         : std_logic_vector(7 downto 0);
   signal copper_lsb_we          : std_logic;
   signal copper_lsb_dat         : std_logic_vector(7 downto 0);
   
   signal ctc_do                 : std_logic_vector(7 downto 0);
   signal port_ctc_dat           : std_logic_vector(7 downto 0);
   signal ctc_zc_to              : std_logic_vector(7 downto 0);
   signal ctc_int_en             : std_logic_vector(7 downto 0);
   signal ctc_int                : std_logic_vector(7 downto 0);
   signal ctc_int_n              : std_logic;
   
   signal divmmc_rom_en          : std_logic;
   signal divmmc_ram_en          : std_logic;
   signal divmmc_rdonly          : std_logic;
   signal divmmc_bank            : std_logic_vector(3 downto 0);
   signal port_e3_reg            : std_logic_vector(7 downto 0);
   signal port_e3_dat            : std_logic_vector(7 downto 0);
   signal divmmc_nmi_hold        : std_logic;
   signal divmmc_automap_held    : std_logic;
   
   signal layer2_addr            : std_logic_vector(16 downto 0);
   signal layer2_pixel_en        : std_logic;
   signal layer2_addr_eff        : std_logic_vector(20 downto 0);
   signal layer2_req_t           : std_logic;
   signal layer2_pixel           : std_logic_vector(7 downto 0);
   
   signal lores_mode_0           : std_logic;
   signal lores_dfile_0          : std_logic;
   signal lores_palette_offset_0 : std_logic_vector(3 downto 0);
   signal lores_addr             : std_logic_vector(13 downto 0);
   signal lores_vram_di          : std_logic_vector(7 downto 0);
   signal lores_pixel            : std_logic_vector(7 downto 0);
   signal lores_pixel_en         : std_logic;
   signal lores_scroll_x_0       : std_logic_vector(7 downto 0);
   signal lores_scroll_y_0       : std_logic_vector(7 downto 0);
-- signal lores_clip_x1_0        : std_logic_vector(7 downto 0);
-- signal lores_clip_x2_0        : std_logic_vector(7 downto 0);
-- signal lores_clip_y1_0        : std_logic_vector(7 downto 0);
-- signal lores_clip_y2_0        : std_logic_vector(7 downto 0);
   
   signal mf_mem_en              : std_logic;
   signal mf_nmi_hold            : std_logic;
   signal mf_port_en             : std_logic;
   signal mf_port_dat            : std_logic_vector(7 downto 0);
   signal mf_is_active           : std_logic;
   
   signal port_303b_dat          : std_logic_vector(7 downto 0);
   signal sprite_mirror_id       : std_logic_vector(6 downto 0);
   signal sprite_pixel           : std_logic_vector(7 downto 0);
   signal sprite_pixel_en        : std_logic;
   
   signal sc                     : std_logic_vector(1 downto 0);
   signal tm_mem_bank7           : std_logic;
   signal tm_vram_a              : std_logic_vector(13 downto 0);
   signal tm_vram_rd             : std_logic;
   signal tm_vram_ack            : std_logic;
   signal tm_vram_di             : std_logic_vector(7 downto 0);
   signal tm_pixel               : std_logic_vector(7 downto 0);
   signal tm_pixel_en            : std_logic;
   signal tm_pixel_below         : std_logic;
   signal tm_pixel_textmode      : std_logic;
   
   signal ula_wait_n             : std_logic;
   signal ula_cpu_contend        : std_logic;
   signal ula_floating_bus       : std_logic_vector(7 downto 0);
   signal ula_vram_shadow        : std_logic;
   signal ula_vram_rd            : std_logic;
   signal ula_vram_a             : std_logic_vector(13 downto 0);
   signal ula_vram_di            : std_logic_vector(7 downto 0);
   signal ula_clip_x1_0          : std_logic_vector(7 downto 0);
   signal ula_clip_x2_0          : std_logic_vector(7 downto 0);
   signal ula_clip_y1_0          : std_logic_vector(7 downto 0);
   signal ula_clip_y2_0          : std_logic_vector(7 downto 0);
   signal ula_border             : std_logic;
   signal ula_pixel              : std_logic_vector(7 downto 0);
   signal ula_select_bgnd        : std_logic;
   signal ula_clipped            : std_logic;
   
   signal mem_contend            : std_logic;
   signal port_contend           : std_logic;
   signal p3_floating_bus_dat    : std_logic_vector(7 downto 0);
   signal port_ff_dat_ula        : std_logic_vector(7 downto 0);
   signal port_ff_dat_tmx        : std_logic_vector(7 downto 0);
   signal port_p3_floating_bus_dat           : std_logic_vector(7 downto 0);
   
   signal port_bf3b_ulap_mode    : std_logic_vector(1 downto 0);
   signal port_bf3b_ulap_index   : std_logic_vector(5 downto 0);
   signal port_ff3b_ulap_en      : std_logic;
   signal ulap_palette_rd        : std_logic;
   signal ulap_palette_rd_dly    : std_logic;
   signal ulap_palette_rd_done   : std_logic;
   signal ulap_wait_n            : std_logic;
   signal port_ff3b_dat          : std_logic_vector(7 downto 0);
   
   -- TBBLUE REGISTRY
   
   signal nr_register            : std_logic_vector(7 downto 0);
   signal port_243b_dat          : std_logic_vector(7 downto 0);
   
   signal MMU0                   : std_logic_vector(7 downto 0);
   signal MMU1                   : std_logic_vector(7 downto 0);
   signal MMU2                   : std_logic_vector(7 downto 0);
   signal MMU3                   : std_logic_vector(7 downto 0);
   signal MMU4                   : std_logic_vector(7 downto 0);
   signal MMU5                   : std_logic_vector(7 downto 0);
   signal MMU6                   : std_logic_vector(7 downto 0);
   signal MMU7                   : std_logic_vector(7 downto 0);
   
   signal copper_requester       : std_logic;
   signal copper_req_dly         : std_logic;
   signal copper_req             : std_logic;
   signal copper_nr_reg          : std_logic_vector(7 downto 0);
   signal copper_nr_dat          : std_logic_vector(7 downto 0);
   signal cpu_requester_0        : std_logic;
   signal cpu_requester_1        : std_logic;
   signal cpu_requester_2        : std_logic;
   signal cpu_req_dly            : std_logic;
   signal cpu_req                : std_logic;
   signal cpu_nr_reg             : std_logic_vector(7 downto 0);
   signal cpu_nr_dat             : std_logic_vector(7 downto 0);
   signal nr_wr_en               : std_logic;
   signal nr_wr_reg              : std_logic_vector(7 downto 0);
   signal nr_wr_dat              : std_logic_vector(7 downto 0);
   signal cpu_served             : std_logic;
   
   signal nr_02_we               : std_logic;
   signal nr_05_we               : std_logic;
   signal nr_07_we               : std_logic;
   signal nr_08_we               : std_logic;
   signal nr_09_we               : std_logic;
   signal nr_28_we               : std_logic;
   signal nr_29_we               : std_logic;
   signal nr_2a_we               : std_logic;
   signal nr_2b_we               : std_logic;
   signal nr_2c_we               : std_logic;
   signal nr_2d_we               : std_logic;
   signal nr_2e_we               : std_logic;
   signal nr_22_we               : std_logic;
   signal nr_41_we               : std_logic;
   signal nr_44_we               : std_logic;
   signal nr_sprite_mirror_we    : std_logic;
   signal nr_sprite_mirror_index : std_logic_vector(2 downto 0);
   signal nr_sprite_mirror_inc   : std_logic;
   signal nr_palette_we          : std_logic;
   signal nr_palette_value       : std_logic_vector(8 downto 0);
   signal nr_palette_priority    : std_logic_vector(1 downto 0);
   signal nr_mmu_we              : std_logic;
   signal nr_mmu                 : std_logic_vector(2 downto 0);
   signal nr_copper_we           : std_logic;
   signal nr_copper_write_8      : std_logic;
   signal nr_68_we               : std_logic;
   signal nr_69_we               : std_logic;
   signal nr_80_we               : std_logic;
   signal nr_8c_we               : std_logic;
   signal nr_8e_we               : std_logic;
   signal nr_8f_we               : std_logic;
   signal nr_c6_we               : std_logic;
   signal nr_ff_we               : std_logic;
   
   signal nr_02_bus_reset        : std_logic;
   signal nr_03_machine_timing   : std_logic_vector(2 downto 0) := "000";
   signal nr_03_user_dt_lock     : std_logic := '0';
   signal bootrom_en             : std_logic := '1';
   signal eff_bootrom_en         : std_logic := '1';
   signal nr_03_machine_type     : std_logic_vector(2 downto 0) := "000";
   signal nr_04_romram_bank      : std_logic_vector(6 downto 0);
   signal nr_05_joymode_0        : std_logic_vector(2 downto 0);
   signal nr_05_joymode_1        : std_logic_vector(2 downto 0);
   signal nr_05_io_mode          : std_logic;
   signal nr_05_joy0             : std_logic_vector(2 downto 0) := "001";
   signal nr_05_joy1             : std_logic_vector(2 downto 0) := "000";
   signal nr_06_hotkey_cpu_speed_en          : std_logic;
   signal nr_06_hotkey_5060_en   : std_logic;
   signal nr_06_divmmc_automap_en            : std_logic;
   signal nr_06_button_m1_nmi_en : std_logic;
   signal nr_06_ps2_mode         : std_logic := '1';
   signal nr_06_psg_mode         : std_logic_vector(1 downto 0) := "00";
   signal nr_06_internal_speaker_beep        : std_logic := '0';
   signal nr_08_contention_disable           : std_logic := '0';
   signal nr_08_psg_stereo_mode  : std_logic;
   signal nr_08_internal_speaker_en          : std_logic;
   signal nr_08_dac_en           : std_logic;
   signal nr_08_port_ff_rd_en    : std_logic;
   signal nr_08_psg_turbosound_en            : std_logic;
   signal nr_08_keyboard_issue2  : std_logic;
   signal nr_09_psg_mono         : std_logic_vector(2 downto 0);
   signal nr_09_hdmi_audio_disable  : std_logic := '0';
   signal nr_09_sprite_tie       : std_logic;
   signal nr_10_flashboot        : std_logic := '0';
   signal nr_10_coreid           : std_logic_vector(4 downto 0) := "00010";
   signal nr_11_video_timing     : std_logic_vector(2 downto 0) := "000";
   signal nr_12_layer2_active_bank           : std_logic_vector(6 downto 0);
   signal nr_13_layer2_shadow_bank           : std_logic_vector(6 downto 0);
   signal nr_14_global_transparent_rgb       : std_logic_vector(7 downto 0);
   signal nr_15_lores_en         : std_logic;
   signal nr_15_sprite_priority  : std_logic;
   signal nr_15_sprite_border_clip_en        : std_logic;
   signal nr_15_layer_priority   : std_logic_vector(2 downto 0);
   signal nr_15_sprite_over_border_en        : std_logic;
   signal nr_15_sprite_en        : std_logic;
   signal nr_16_layer2_scrollx   : std_logic_vector(7 downto 0);
   signal nr_17_layer2_scrolly   : std_logic_vector(7 downto 0);
   signal nr_18_layer2_clip_x1   : std_logic_vector(7 downto 0);
   signal nr_18_layer2_clip_x2   : std_logic_vector(7 downto 0);
   signal nr_18_layer2_clip_y1   : std_logic_vector(7 downto 0);
   signal nr_18_layer2_clip_y2   : std_logic_vector(7 downto 0);
   signal nr_18_layer2_clip_idx  : std_logic_vector(1 downto 0);
   signal nr_19_sprite_clip_x1   : std_logic_vector(7 downto 0);
   signal nr_19_sprite_clip_x2   : std_logic_vector(7 downto 0);
   signal nr_19_sprite_clip_y1   : std_logic_vector(7 downto 0);
   signal nr_19_sprite_clip_y2   : std_logic_vector(7 downto 0);
   signal nr_19_sprite_clip_idx  : std_logic_vector(1 downto 0);
   signal nr_1a_ula_clip_x1      : std_logic_vector(7 downto 0);
   signal nr_1a_ula_clip_x2      : std_logic_vector(7 downto 0);
   signal nr_1a_ula_clip_y1      : std_logic_vector(7 downto 0);
   signal nr_1a_ula_clip_y2      : std_logic_vector(7 downto 0);
   signal nr_1a_ula_clip_idx     : std_logic_vector(1 downto 0);
   signal nr_1b_tm_clip_x1       : std_logic_vector(7 downto 0);
   signal nr_1b_tm_clip_x2       : std_logic_vector(7 downto 0);
   signal nr_1b_tm_clip_y1       : std_logic_vector(7 downto 0);
   signal nr_1b_tm_clip_y2       : std_logic_vector(7 downto 0);
   signal nr_1b_tm_clip_idx      : std_logic_vector(1 downto 0);
-- signal nr_1c_clip_select      : std_logic_vector(3 downto 0);
-- signal nr_1d_lores_clip_x1    : std_logic_vector(7 downto 0);
-- signal nr_1d_lores_clip_x2    : std_logic_vector(7 downto 0);
-- signal nr_1d_lores_clip_y1    : std_logic_vector(7 downto 0);
-- signal nr_1d_lores_clip_y2    : std_logic_vector(7 downto 0);
-- signal nr_1d_lores_clip_idx   : std_logic_vector(1 downto 0);
   signal nr_22_line_interrupt_en            : std_logic;
   signal nr_23_line_interrupt   : std_logic_vector(8 downto 0);
   signal nr_26_ula_scrollx      : std_logic_vector(7 downto 0);
   signal nr_27_ula_scrolly      : std_logic_vector(7 downto 0);
   signal nr_2d_i2s_sample       : std_logic_vector(1 downto 0);
   signal nr_30_tm_scrollx       : std_logic_vector(9 downto 0);
   signal nr_31_tm_scrolly       : std_logic_vector(7 downto 0);
   signal nr_32_lores_scrollx    : std_logic_vector(7 downto 0);
   signal nr_33_lores_scrolly    : std_logic_vector(7 downto 0);
   signal nr_palette_idx         : std_logic_vector(7 downto 0);
   signal nr_palette_sub_idx     : std_logic;
   signal nr_42_ulanext_format   : std_logic_vector(7 downto 0);
   signal nr_43_palette_autoinc_disable      : std_logic;
   signal nr_43_palette_write_select         : std_logic_vector(2 downto 0);
   signal nr_43_active_sprite_palette        : std_logic;
   signal nr_43_active_layer2_palette        : std_logic;
   signal nr_43_active_ula_palette           : std_logic;
   signal nr_43_ulanext_en       : std_logic;
   signal nr_stored_palette_value            : std_logic_vector(7 downto 0);
   signal nr_4a_fallback_rgb     : std_logic_vector(7 downto 0);
   signal nr_4b_sprite_transparent_index     : std_logic_vector(7 downto 0);
   signal nr_4c_tm_transparent_index         : std_logic_vector(3 downto 0);
   signal nr_copper_addr         : std_logic_vector(10 downto 0);
   signal nr_copper_data_stored  : std_logic_vector(7 downto 0);
   signal nr_62_copper_mode      : std_logic_vector(1 downto 0);
   signal nr_64_copper_offset    : std_logic_vector(7 downto 0);
   signal nr_68_ula_en           : std_logic;
   signal nr_68_blend_mode       : std_logic_vector(1 downto 0);
   signal nr_68_cancel_extended_keys         : std_logic;
   signal nr_68_ula_fine_scroll_x            : std_logic;
   signal nr_68_ula_stencil_mode : std_logic;
   signal nr_6a_lores_radastan   : std_logic;
   signal nr_6a_lores_radastan_xor           : std_logic;
   signal nr_6a_lores_palette_offset         : std_logic_vector(3 downto 0);
   signal nr_6b_tm_en            : std_logic;
   signal nr_6b_tm_control       : std_logic_vector(6 downto 0);
   signal nr_6c_tm_default_attr  : std_logic_vector(7 downto 0);
   signal nr_6e_tilemap_base     : std_logic_vector(5 downto 0);
   signal nr_6e_tilemap_base_7   : std_logic;
   signal nr_6f_tilemap_tiles    : std_logic_vector(5 downto 0);
   signal nr_6f_tilemap_tiles_7  : std_logic;
   signal nr_70_layer2_resolution      : std_logic_vector(1 downto 0);
   signal nr_70_layer2_palette_offset  : std_logic_vector(3 downto 0);
   signal nr_71_layer2_scrollx_msb     : std_logic;
   signal nr_7f_user_register_0  : std_logic_vector(7 downto 0);
   signal nr_98_pi_gpio_o        : std_logic_vector(7 downto 0);
   signal nr_99_pi_gpio_o        : std_logic_vector(7 downto 0);
   signal nr_9a_pi_gpio_o        : std_logic_vector(7 downto 0);
   signal nr_9b_pi_gpio_o        : std_logic_vector(3 downto 0);
   signal nr_81_expbus_ula_override          : std_logic := '0';
   signal nr_81_expbus_nmi_debounce_disable  : std_logic := '0';
   signal nr_81_expbus_clken     : std_logic := '0';
   signal nr_81_expbus_speed     : std_logic_vector(1 downto 0) := "00";
   signal nr_82_internal_port_enable         : std_logic_vector(7 downto 0);
   signal nr_83_internal_port_enable         : std_logic_vector(7 downto 0);
   signal nr_84_internal_port_enable         : std_logic_vector(7 downto 0);
   signal nr_85_internal_port_enable         : std_logic_vector(3 downto 0);
   signal nr_85_internal_port_reset_type     : std_logic := '1';
   signal nr_86_bus_port_enable  : std_logic_vector(7 downto 0);
   signal nr_87_bus_port_enable  : std_logic_vector(7 downto 0);
   signal nr_88_bus_port_enable  : std_logic_vector(7 downto 0);
   signal nr_89_bus_port_enable  : std_logic_vector(3 downto 0);
   signal nr_89_bus_port_reset_type          : std_logic := '1';
   signal nr_8a_bus_port_propagate           : std_logic_vector(5 downto 0);
   signal nr_90_pi_gpio_o_en     : std_logic_vector(7 downto 0) := (others => '0');
   signal nr_91_pi_gpio_o_en     : std_logic_vector(7 downto 0) := (others => '0');
   signal nr_92_pi_gpio_o_en     : std_logic_vector(7 downto 0) := (others => '0');
   signal nr_93_pi_gpio_o_en     : std_logic_vector(3 downto 0) := (others => '0');
   signal nr_a0_pi_peripheral_en : std_logic_vector(7 downto 0);
   signal nr_a2_pi_i2s_ctl       : std_logic_vector(7 downto 0);
-- signal nr_a3_pi_i2s_clkdiv    : std_logic_vector(7 downto 0);
   signal nr_a8_esp_gpio0_en     : std_logic := '0';
   signal nr_a9_esp_gpio0        : std_logic := '1';
   signal nr_0a_mf_type          : std_logic_vector(1 downto 0) := "00";
   signal nr_0a_mouse_button_reverse         : std_logic := '0';
   signal nr_0a_mouse_dpi        : std_logic_vector(1 downto 0) := "01";
   
   signal machine_type_config    : std_logic;
   signal machine_type_48        : std_logic;
   signal machine_type_128       : std_logic;
   signal machine_type_p3        : std_logic;
   
   signal machine_timing_48      : std_logic;
   signal machine_timing_128     : std_logic;
   signal machine_timing_p3      : std_logic;
   signal machine_timing_pentagon            : std_logic;
   
   signal hotkey_cpu_speed       : std_logic;
   signal hotkey_5060            : std_logic;
   signal hotkey_scandouble      : std_logic;
   signal hotkey_scanlines       : std_logic;
   signal hotkey_hard_reset      : std_logic;
   signal hotkey_soft_reset      : std_logic;
   signal hotkey_expbus_enable   : std_logic;
   signal hotkey_expbus_disable  : std_logic;
   signal hotkey_expbus_freeze   : std_logic;
   signal hotkey_m1              : std_logic;
   signal hotkey_drive           : std_logic;
   
   signal nr_07_cpu_speed        : std_logic_vector(1 downto 0);
   signal cpu_speed              : std_logic_vector(1 downto 0) := "00";
   
   signal nr_05_5060             : std_logic := '0';
   signal nr_05_scandouble_en    : std_logic := '1';
   signal nr_09_scanlines        : std_logic_vector(1 downto 0) := "00";
   
   signal nr_02_reset_type       : std_logic_vector(1 downto 0) := "10";
   signal port_253b_dat          : std_logic_vector(7 downto 0);
   signal port_253b_dat_0        : std_logic_vector(7 downto 0);
   
   -- PS/2 KEYMAP & HOT KEYS
   
   signal nr_keymap_addr         : std_logic_vector(8 downto 0) := "000000000";
   signal nr_keymap_dat_msb      : std_logic := '0';
   signal nr_keymap_we           : std_logic;
   signal nr_keymap_dat          : std_logic_vector(8 downto 0);
   
   signal hotkeys_1              : std_logic_vector(10 downto 1) := "0000000000";
   signal hotkeys_0              : std_logic_vector(10 downto 1) := "0000000000";
   signal nr_02_soft_reset       : std_logic;
   signal nr_02_hard_reset       : std_logic;
   
   -- AUDIO
   
   signal audio_ay_reset         : std_logic;
   signal psg_dat                : std_logic_vector(7 downto 0);
   signal pcm_ay_L               : std_logic_vector(11 downto 0);
   signal pcm_ay_R               : std_logic_vector(11 downto 0);
   signal port_fffd_dat          : std_logic_vector(7 downto 0);
   
   signal port_fe_mic_final      : std_logic;
   signal internal_speaker_beep_exclusive    : std_logic;
   
   signal pcm_dac_L              : std_logic_vector(8 downto 0);
   signal pcm_dac_R              : std_logic_vector(8 downto 0);
   
   signal pi_mi2s_sck            : std_logic;
   signal pi_mi2s_ws             : std_logic;
   signal pi_si2s_sck            : std_logic;
   signal pi_si2s_ws             : std_logic;
   signal pi_i2s_sd_o            : std_logic;
   signal pi_i2s_sd_i            : std_logic;
   signal pi_i2s_audio_L         : std_logic_vector(9 downto 0);
   signal pi_i2s_audio_R         : std_logic_vector(9 downto 0);
   
   signal pcm_audio_L            : std_logic_vector(12 downto 0);
   signal pcm_audio_R            : std_logic_vector(12 downto 0);
   
   -- VIDEO
   
   signal cpu_bank5_req          : std_logic;
   signal cpu_bank5_req_dly      : std_logic;
   signal cpu_bank5_sched_dly    : std_logic;
   signal cpu_bank5_sched        : std_logic;
   signal cpu_bank5_do           : std_logic_vector(7 downto 0);
   signal vram_bank5_do0         : std_logic_vector(7 downto 0);
   signal vram_bank5_do1         : std_logic_vector(7 downto 0);
   signal ula_bank_req          : std_logic;
   signal ula_bank_req_dly      : std_logic;
   signal ula_bank_sched_dly    : std_logic;
   signal ula_bank_sched        : std_logic;
   signal ula_bank_do           : std_logic_vector(7 downto 0);
   signal lores_vram_req         : std_logic;
   signal lores_vram_ack_dly     : std_logic;
   signal vram_bank5_a0          : std_logic_vector(13 downto 0);
   signal vram_bank_a1          : std_logic_vector(13 downto 0);
   signal lores_vram_ack         : std_logic;
   
   signal cpu_bank7_do           : std_logic_vector(7 downto 0);
   signal vram_bank7_do          : std_logic_vector(7 downto 0);
   
   signal video_timing_change    : std_logic;
   signal video_timing_change_d  : std_logic := '1';
   
   signal eff_nr_03_machine_timing           : std_logic_vector(2 downto 0) := "000";
   signal eff_nr_05_5060         : std_logic;
   signal eff_nr_05_scandouble_en            : std_logic;
   signal eff_nr_08_contention_disable       : std_logic := '0';
   signal eff_nr_09_scanlines    : std_logic_vector(1 downto 0);
   
   signal ula_int_en             : std_logic_vector(1 downto 0);
   signal hc                     : unsigned(8 downto 0);
   signal vc                     : unsigned(8 downto 0);
   signal phc                    : unsigned(8 downto 0);
   signal whc                    : unsigned(8 downto 0);
   signal wvc                    : unsigned(8 downto 0);
   signal cvc                    : unsigned(8 downto 0);
   signal rgb_hsync_n            : std_logic;
   signal rgb_vsync_n            : std_logic;
   signal rgb_hblank_n           : std_logic;
   signal rgb_vblank_n           : std_logic;
   
   signal ula_int_n              : std_logic;
   signal ula_int_pulse_n        : std_logic;
   signal ula_int_count_end      : std_logic;
   signal ula_int_count          : std_logic_vector(4 downto 0);

   signal layer_priorities_0     : std_logic_vector(2 downto 0);
   signal ula_en_0               : std_logic;
   signal ula_stencil_mode_0     : std_logic;
   signal ula_blend_mode_0       : std_logic_vector(1 downto 0);
   signal ulanext_en_0           : std_logic;
   signal ulanext_format_0       : std_logic_vector(7 downto 0);
   signal ulap_en_0              : std_logic;
   signal lores_en_0             : std_logic;
   signal sprite_en_0            : std_logic;
   signal tm_en_0                : std_logic;
   signal transparent_rgb_0      : std_logic_vector(7 downto 0);
   signal fallback_rgb_0         : std_logic_vector(7 downto 0);
   signal ula_palette_select_0   : std_logic;
   signal tm_palette_select_0    : std_logic;
   signal layer2_palette_select_0            : std_logic;
   signal sprite_palette_select_0            : std_logic;

   signal lores_pixel_1          : std_logic_vector(7 downto 0);
   signal lores_pixel_en_1a      : std_logic;
   signal layer2_pixel_1         : std_logic_vector(7 downto 0);
   signal sprite_pixel_1         : std_logic_vector(7 downto 0);
   signal sprite_pixel_en_1a     : std_logic;
   signal ula_pixel_1            : std_logic_vector(7 downto 0);
   signal ula_select_bgnd_1      : std_logic;
   signal tm_pixel_1             : std_logic_vector(7 downto 0);
   signal tm_pixel_en_1          : std_logic;
   signal tm_pixel_below_1       : std_logic;
   signal tm_pixel_textmode_1    : std_logic;
   signal ula_border_1           : std_logic;
   signal ula_clipped_1          : std_logic;
   signal layer_priorities_1     : std_logic_vector(2 downto 0);
   signal video_blank_n_1        : std_logic;
   signal rgb_vsync_n_1          : std_logic;
   signal rgb_vblank_n_1         : std_logic;
   signal rgb_hblank_n_1         : std_logic;
   signal rgb_hsync_n_1          : std_logic;
   signal ula_en_1               : std_logic;
   signal ula_en_1a              : std_logic;
   signal ula_stencil_mode_1     : std_logic;
   signal ula_stencil_mode_1a    : std_logic;
   signal ula_blend_mode_1       : std_logic_vector(1 downto 0);
   signal ula_blend_mode_1a      : std_logic_vector(1 downto 0);
   signal lores_en_1             : std_logic;
   signal lores_en_1a            : std_logic;
   signal sprite_en_1            : std_logic;
   signal sprite_en_1a           : std_logic;
   signal tm_en_1                : std_logic;
   signal tm_en_1a               : std_logic;
   signal transparent_rgb_1      : std_logic_vector(7 downto 0);
   signal transparent_rgb_1a     : std_logic_vector(7 downto 0);
   signal fallback_rgb_1         : std_logic_vector(7 downto 0);
   signal fallback_rgb_1a        : std_logic_vector(7 downto 0);
   signal ula_palette_select_1   : std_logic;
   signal ula_palette_select_1a  : std_logic;
   signal tm_palette_select_1    : std_logic;
   signal tm_palette_select_1a   : std_logic;
   signal layer2_palette_select_1            : std_logic;
   signal layer2_palette_select_1a           : std_logic;
   signal sprite_palette_select_1            : std_logic;
   signal sprite_palette_select_1a           : std_logic;
   signal lores_pixel_en_1       : std_logic;
   signal layer2_pixel_en_1      : std_logic;
   signal sprite_pixel_en_1      : std_logic;
   
   signal nr_palette_index       : std_logic_vector(9 downto 0);
   signal nr_palette_index_utm   : std_logic_vector(9 downto 0);
   signal nr_palette_dat         : std_logic_vector(10 downto 0);
   signal nr_palette_rd          : std_logic;
   signal nr_ulatm_we            : std_logic;
   signal nr_ulatm_palette_dat   : std_logic_vector(15 downto 0);
   signal ulatm_rgb_1            : std_logic_vector(15 downto 0);
   signal ulalores_pixel_1       : std_logic_vector(7 downto 0);
   signal ulatm_pixel_1          : std_logic_vector(9 downto 0);
   signal ula_rgb_1              : std_logic_vector(8 downto 0);
   signal ula_rgb_2              : std_logic_vector(8 downto 0);
   signal tm_rgb_2               : std_logic_vector(8 downto 0);
-- signal lores_rgb_2            : std_logic_vector(8 downto 0);
   signal nr_l2s_palette_we      : std_logic;
   signal nr_l2s_palette_dat     : std_logic_vector(15 downto 0);
   signal l2s_prgb_1             : std_logic_vector(15 downto 0);
   signal l2s_pixel_1            : std_logic_vector(9 downto 0);
   signal layer2_prgb_1          : std_logic_vector(9 downto 0);
   signal layer2_rgb_2           : std_logic_vector(8 downto 0);
   signal layer2_priority_2      : std_logic;
   signal sprite_rgb_2           : std_logic_vector(8 downto 0);
   signal ula_en_2               : std_logic;
   signal ula_border_2           : std_logic;
   signal ula_clipped_2          : std_logic;
   signal ula_stencil_mode_2     : std_logic;
   signal ula_blend_mode_2       : std_logic_vector(1 downto 0);
-- signal lores_en_2             : std_logic;
   signal tm_en_2                : std_logic;
   signal tm_pixel_en_2          : std_logic;
   signal tm_pixel_below_2       : std_logic;
   signal tm_pixel_textmode_2    : std_logic;
   signal layer2_pixel_en_2      : std_logic;
   signal sprite_pixel_en_2      : std_logic;
   signal transparent_rgb_2      : std_logic_vector(7 downto 0);
   signal fallback_rgb_2         : std_logic_vector(7 downto 0);
   signal layer_priorities_2     : std_logic_vector(2 downto 0);
   signal video_blank_n_2        : std_logic;
   signal rgb_vsync_n_2          : std_logic;
   signal rgb_vblank_n_2         : std_logic;
   signal rgb_hblank_n_2         : std_logic;
   signal rgb_hsync_n_2          : std_logic;
   
   signal ula_mix_transparent    : std_logic;
   signal ula_mix_rgb            : std_logic_vector(8 downto 0);
   signal mix_top_transparent    : std_logic;
   signal mix_top_rgb            : std_logic_vector(8 downto 0);
   signal mix_bot_transparent    : std_logic;
   signal mix_bot_rgb            : std_logic_vector(8 downto 0);
   signal ula_transparent        : std_logic;
   signal ula_rgb                : std_logic_vector(8 downto 0);
-- signal lores_transparent      : std_logic;
-- signal lores_rgb              : std_logic_vector(8 downto 0);
   signal tm_transparent         : std_logic;
   signal tm_rgb                 : std_logic_vector(8 downto 0);
   signal stencil_transparent    : std_logic;
   signal stencil_rgb            : std_logic_vector(8 downto 0);
   signal ulatm_transparent      : std_logic;
   signal ulatm_rgb              : std_logic_vector(8 downto 0);
   signal sprite_transparent     : std_logic;
   signal sprite_rgb             : std_logic_vector(8 downto 0);
   signal layer2_transparent     : std_logic;
   signal layer2_rgb             : std_logic_vector(8 downto 0);
   signal layer2_priority        : std_logic;
   signal ula_final_rgb          : std_logic_vector(8 downto 0);
   signal ula_final_transparent  : std_logic;
   signal mix_rgb                : std_logic_vector(8 downto 0);
   signal mix_rgb_transparent    : std_logic;
   signal rgb_out_2              : std_logic_vector(8 downto 0);
   signal rgb_out_2a             : std_logic_vector(8 downto 0);

   signal rgb_vsync_n_7          : std_logic;
   signal rgb_vsync_n_6          : std_logic;
   signal rgb_vsync_n_5          : std_logic;
   signal rgb_vsync_n_4          : std_logic;
   signal rgb_vsync_n_3          : std_logic;
   signal rgb_vblank_n_7         : std_logic;
   signal rgb_vblank_n_6         : std_logic;
   signal rgb_vblank_n_5         : std_logic;
   signal rgb_vblank_n_4         : std_logic;
   signal rgb_vblank_n_3         : std_logic;
   signal rgb_hblank_n_7         : std_logic;
   signal rgb_hblank_n_6         : std_logic;
   signal rgb_hblank_n_5         : std_logic;
   signal rgb_hblank_n_4         : std_logic;
   signal rgb_hblank_n_3         : std_logic;
   signal rgb_hsync_n_7          : std_logic;
   signal rgb_hsync_n_6          : std_logic;
   signal rgb_hsync_n_5          : std_logic;
   signal rgb_hsync_n_4          : std_logic;
   signal rgb_hsync_n_3          : std_logic;
   signal rgb_out_7              : std_logic_vector(8 downto 0);
   signal rgb_out_6              : std_logic_vector(8 downto 0);
   signal rgb_out_5              : std_logic_vector(8 downto 0);
   signal rgb_out_4              : std_logic_vector(8 downto 0);
   signal rgb_out_3              : std_logic_vector(8 downto 0);
   
   signal rgb_vsync_n_o          : std_logic;
   signal rgb_vblank_n_o         : std_logic;
   signal rgb_hblank_n_o         : std_logic;
   signal rgb_hsync_n_o          : std_logic;
   signal rgb_out_o              : std_logic_vector(8 downto 0);
   signal rgb_csync_n_o          : std_logic;

begin

   ------------------------------------------------------------
   -- OUTPUT --------------------------------------------------
   ------------------------------------------------------------

   o_CPU_SPEED <= cpu_speed;  
   o_CPU_CONTEND <= ula_cpu_contend;
   o_CPU_CLK_LSB <= hc(0);

   o_RESET_SOFT <= nr_02_soft_reset;
   o_RESET_HARD <= nr_02_hard_reset;
   o_RESET_PERIPHERAL <= nr_02_bus_reset;

   o_FLASH_BOOT <= nr_10_flashboot;
   o_CORE_ID <= nr_10_coreid;

   o_KBD_CANCEL <= nr_68_cancel_extended_keys;
   o_KBD_ROW <= keyrow;

   o_KEYMAP_ADDR <= nr_keymap_addr;
   o_KEYMAP_DATA <= nr_keymap_dat;
   o_KEYMAP_WE <= nr_keymap_we;

   o_JOY_IO_MODE <= io_mode(0) & io_mode_en;
   o_JOY_IO_MODE_LR <= io_mode_lr;
   o_JOY_IO_MODE_PIN_7 <= io_mode_pin_7;

   o_PS2_MODE <= nr_06_ps2_mode;
   o_MOUSE_CONTROL <= nr_0a_mouse_button_reverse & nr_0a_mouse_dpi;
   
   o_I2C_SCL_n <= i2c_scl_o;
   o_I2C_SDA_n <= i2c_sda_o;
   
   o_SPI_SS_FLASH_n <= spi_ss_flash_n;
   o_SPI_SS_SD1_n <= spi_ss_sd1_n;
   o_SPI_SS_SD0_n <= spi_ss_sd0_n;

   o_SPI_SCK <= spi_sck;
   o_SPI_MOSI <= spi_mosi;

   o_UART0_TX <= uart0_tx_esp;

   o_RGB <= rgb_out_o;
   o_RGB_CS_n <= rgb_csync_n_o;
   o_RGB_VS_n <= rgb_vsync_n_o;
   o_RGB_HS_n <= rgb_hsync_n_o;
   o_RGB_VB_n <= rgb_vblank_n_o;
   o_RGB_HB_n <= rgb_hblank_n_o;
      
   o_VIDEO_50_60 <= eff_nr_05_5060;
   o_VIDEO_SCANLINES <= eff_nr_09_scanlines;
   o_VIDEO_SCANDOUBLE <= eff_nr_05_scandouble_en;
   
   o_VIDEO_MODE <= nr_11_video_timing;
   o_MACHINE_TIMING <= eff_nr_03_machine_timing;
   
   o_HDMI_RESET <= video_timing_change_d;
   
   o_AUDIO_HDMI_AUDIO_EN <= not nr_09_hdmi_audio_disable;
   
   o_AUDIO_SPEAKER_EN <= nr_08_internal_speaker_en;
   o_AUDIO_SPEAKER_BEEP <= internal_speaker_beep_exclusive;
   
   o_AUDIO_MIC <= port_fe_mic xor pi_fe_ear;
   
   o_AUDIO_SPEAKER_EAR <= port_fe_ear;
   o_AUDIO_SPEAKER_MIC <= port_fe_mic_final;
   
   o_AUDIO_L <= pcm_audio_L;
   o_AUDIO_R <= pcm_audio_R;

   o_RAM_A_ADDR <= sram_addr;
   o_RAM_A_REQ <= sram_req_t;
   o_RAM_A_RD <= sram_rd;
   o_RAM_A_DO <= cpu_do;

   o_RAM_B_ADDR <= layer2_addr_eff;
   o_RAM_B_REQ_T <= layer2_req_t;

   o_BUS_ADDR <= cpu_a;
   o_BUS_DO <= cpu_do;
   o_BUS_MREQ_n <= bus_mreq_n;
   o_BUS_IORQ_n <= bus_iorq_n;
   o_BUS_RD_n <= cpu_rd_n;
   o_BUS_WR_n <= cpu_wr_n;
   o_BUS_M1_n <= cpu_m1_n;
   o_BUS_INT_n <= ula_int_n;
   o_BUS_BUSAK_n <= '1';
   o_BUS_HALT_n <= cpu_halt_n;
   o_BUS_RFSH_n <= cpu_rfsh_n;

   o_BUS_EN <= expbus_eff_en;
   o_BUS_CLKEN <= expbus_eff_clken;
   
   o_BUS_NMI_DEBOUNCE_DISABLE <= nr_81_expbus_nmi_debounce_disable;

   o_ESP_GPIO_0 <= nr_a9_esp_gpio0;
   o_ESP_GPIO_0_EN <= nr_a8_esp_gpio0_en;

   o_GPIO <= pi_gpio_o(27 downto 22) & gpio_21 & gpio_20 & gpio_19 & gpio_18 & pi_gpio_o(17 downto 16) & gpio_15 & gpio_14 & pi_gpio_o(13 downto 12) & gpio_11 & gpio_10 & pi_gpio_o(9) & gpio_08 & gpio_07 & pi_gpio_o(6 downto 4) & gpio_03 & gpio_02 & pi_gpio_o(1 downto 0);
   o_GPIO_EN <= pi_gpio_en(27 downto 22) & gpio_21_en & gpio_20_en & gpio_19_en & gpio_18_en & pi_gpio_en(17 downto 16) & gpio_15_en & gpio_14_en & pi_gpio_en(13 downto 12) & gpio_11_en & gpio_10_en & gpio_09_en & gpio_08_en & gpio_07_en & pi_gpio_en(6 downto 4) & gpio_03_en & gpio_02_en & pi_gpio_en(1 downto 0);

   ------------------------------------------------------------
   -- RESET ---------------------------------------------------
   ------------------------------------------------------------
   
   -- incoming reset signals are asserted for some time by the top level module
   
   reset <= reset_hard or reset_soft;
   
   reset_soft <= i_RESET_SOFT;
   reset_hard <= i_RESET_HARD;
   
   ------------------------------------------------------------
   -- Z80 & DMA -----------------------------------------------
   ------------------------------------------------------------

   cpu_mod: entity work.T80na
   generic map (
      Mode        => 0
   )
   port map (
      RESET_n     => not reset,     -- in
      CLK_n       => i_CLK_CPU,     -- in
      WAIT_n      => z80_wait_n,    -- in
      INT_n       => z80_int_n,     -- in
      NMI_n       => z80_nmi_n,     -- in (detection is on rising edge of cpu clock)
      BUSRQ_n     => z80_busrq_n,   -- in
      M1_n        => z80_m1_n,      -- out
      MREQ_n      => z80_mreq_n,    -- out
      IORQ_n      => z80_iorq_n,    -- out
      RD_n        => z80_rd_n,      -- out
      WR_n        => z80_wr_n,      -- out
      RFSH_n      => z80_rfsh_n,    -- out
      HALT_n      => z80_halt_n,    -- out
      BUSAK_n     => z80_busak_n,   -- out
      A           => z80_a,         -- out
      D_i         => cpu_di,        -- in
      D_o         => z80_do,        -- out
      -- extended functions
      Z80N_dout_o       => Z80N_dout_s,
      Z80N_data_o       => Z80N_data_s,
      Z80N_command_o    => Z80N_command_s
   );
   
   dma_mod: entity work.z80dma
   port map (
      reset_i        => reset,
      clk_i          => i_CLK_CPU,
      turbo_i        => cpu_speed,
      dma_mode_i     => dma_mode,       -- 0 = zxn dma, 1 = z80 dma

      dma_en_wr_s    => port_dma_wr,    -- allow dma to program itself? ans: no
      dma_en_rd_s    => port_dma_rd,

      cpu_d_i        => z80_do,
      wait_n_i       => dma_wait_n,

      bus_busreq_n_i => '1',            -- busreq in daisy chain (i_BUS_BUSREQ_n)
      cpu_busreq_n_o => dma_busrq_n,    -- busreq out
         
      cpu_bai_n      => z80_busak_n,    -- busak in daisy chain
      cpu_bao_n      => open,           -- busak out daisy chain

      dma_a_o        => dma_a,
      dma_d_o        => dma_do,
      dma_d_i        => cpu_di,
      dma_rd_n_o     => dma_rd_n,
      dma_wr_n_o     => dma_wr_n,
      dma_mreq_n_o   => dma_mreq_n,
      dma_iorq_n_o   => dma_iorq_n,

      cpu_d_o        => port_dma_dat_0
   );
   
   process (i_CLK_CPU)
   begin
      if falling_edge(i_CLK_CPU) then
         port_dma_dat <= port_dma_dat_0;
      end if;
   end process;
   
   process (i_CLK_CPU)
   begin
      if falling_edge(i_CLK_CPU) then
         if reset = '1' then
            dma_mode <= '0';
         elsif port_dma_rd = '1' or port_dma_wr = '1' then
            dma_mode <= port_0b_lsb;
         end if;
      end if;
   end process;
   
   -- no dma controller on the expansion bus at this time

-- dma_holds_bus <= '1' when dma_busrq_n = '0' and z80_busak_n = '0' else '0';
   dma_holds_bus <= '1' when z80_busak_n = '0' else '0';
   
   cpu_m1_n <= '1' when dma_holds_bus = '1' else z80_m1_n;
   cpu_mreq_n <= dma_mreq_n when dma_holds_bus = '1' else z80_mreq_n;
   cpu_iorq_n <= dma_iorq_n when dma_holds_bus = '1' else z80_iorq_n;
   cpu_rd_n <= dma_rd_n when dma_holds_bus = '1' else z80_rd_n;
   cpu_wr_n <= dma_wr_n when dma_holds_bus = '1' else z80_wr_n;
   cpu_rfsh_n <= '1' when dma_holds_bus = '1' else z80_rfsh_n;
   cpu_halt_n <= '1' when dma_holds_bus = '1' else z80_halt_n;
   cpu_a <= dma_a when dma_holds_bus = '1' else z80_a;
   cpu_do <= dma_do when dma_holds_bus = '1' else z80_do;

   z80_wait_n <= '0' when (ula_wait_n = '0') or (ulap_wait_n = '0') or (sram_wait_n = '0') or (i_BUS_WAIT_n = '0' and expbus_eff_en = '1') else '1';
   z80_int_n <= ula_int_n and (i_BUS_INT_n or (not expbus_eff_en) or expbus_eff_disable_io);
   z80_nmi_n <= nmi_generate_n;
   z80_busrq_n <= dma_busrq_n;
   
   dma_wait_n <= z80_wait_n and spi_wait_n;

   cpu_di <= cpu_di_mem when cpu_mreq_n = '0' and cpu_rfsh_n = '1' else cpu_di_io when cpu_iorq_n = '0' else X"FF";
   
   cpu_di_mem <= bootrom_do when cpu_a(15 downto 14) = "00" and eff_bootrom_en = '1' else
      i_BUS_DI when sram_romcs = '1' and eff_expbus_romcs_replace = '0' else
      cpu_bank5_do when sram_bank5 = '1' else
      cpu_bank7_do when sram_bank7 = '1' else
      i_RAM_A_DI;
   
   cpu_di_io <= port_rd_dat when port_internal_rd_response = '1' and bus_iorq_ula = '0' else i_BUS_DI when expbus_eff_en = '1' and expbus_eff_disable_io = '0' else X"FF";

   -- todo: sticky maskable interrupts
   
   --
   -- nmi
   --

   -- first come first serve
   
   process (i_CLK_28)
   begin
      if rising_edge(i_CLK_28) then
         if reset = '1' then
            nmi_expbus_en <= '1';
         elsif nmi_expbus = '1' then
            nmi_expbus_en <= '0';
         elsif i_BUS_NMI_n = '1' then
            nmi_expbus_en <= '1';
         end if;
      end if;
   end process;

   nmi_assert_expbus <= '1' when expbus_eff_en = '1' and expbus_eff_disable_mem = '0' and i_BUS_NMI_n = '0' else '0';
   
   nmi_activated <= nmi_mf or nmi_divmmc or nmi_expbus;
   
   process (i_CLK_28)
   begin
      if rising_edge(i_CLK_28) then
         if reset = '1' or nmi_state = S_NMI_END or machine_type_config = '1' then
            nmi_mf <= '0';
            nmi_divmmc <= '0';
            nmi_expbus <= '0';
         elsif nmi_activated = '0' then
            if hotkey_m1 = '1' and nr_06_button_m1_nmi_en = '1' and port_e3_reg(7) = '0' and divmmc_nmi_hold = '0' then
               nmi_mf <= '1';
            elsif hotkey_drive = '1' and nr_06_divmmc_automap_en = '1' and mf_is_active = '0' then
               nmi_divmmc <= '1';
            elsif nmi_expbus_en = '1' and nmi_assert_expbus = '1' then
               nmi_expbus <= '1';
            end if;
         end if;
      end if;
   end process;
   
   nmi_hold <= mf_nmi_hold when nmi_mf = '1' else divmmc_nmi_hold when nmi_divmmc = '1' else nmi_assert_expbus;
   
   -- nmi state machine
   
   nmi_holding <= '1' when nmi_hold = '1' or dma_holds_bus = '1' else '0';
   nmi_opus <= '1' when nmi_mf = '1' and nr_81_expbus_nmi_debounce_disable = '1' and nmi_assert_expbus = '1' else '0';
   
   process (nmi_state, nmi_activated, nmi_holding, nmi_opus)
   begin
      case nmi_state is
         when S_NMI_IDLE =>
            if nmi_activated = '1' then
               nmi_state_next <= S_NMI_ASSERT;
            else
               nmi_state_next <= S_NMI_IDLE;
            end if;
         when S_NMI_ASSERT =>
            nmi_state_next <= S_NMI_HOLD;
         when S_NMI_OPUS =>                    -- separate to avoid button activation in multiface
            if nmi_opus = '1' then
               nmi_state_next <= S_NMI_OPUS;
            else
               nmi_state_next <= S_NMI_HOLD;
            end if;
         when S_NMI_HOLD  =>
            if nmi_holding = '0' then
               nmi_state_next <= S_NMI_END;
            elsif nmi_opus = '1' then          -- multiface + opus discovery
               nmi_state_next <= S_NMI_OPUS;
            else
               nmi_state_next <= S_NMI_HOLD;
            end if;
--       when S_NMI_END =>
--          nmi_state_next <= S_NMI_IDLE;
         when others =>
            nmi_state_next <= S_NMI_IDLE;
      end case;
   end process;
   
   process (i_CLK_CPU)
   begin
      if rising_edge(i_CLK_CPU) then
         if reset = '1' or machine_type_config = '1' then
            nmi_state <= S_NMI_IDLE;
         else
            nmi_state <= nmi_state_next;
         end if;
      end if;
   end process;
   
   nmi_generate_n <= '0' when nmi_state = S_NMI_ASSERT or nmi_state = S_NMI_OPUS else '1';
   nmi_mf_button <= '1' when nmi_mf = '1' and nmi_state = S_NMI_ASSERT else '0';
   nmi_divmmc_button <= '1' when nmi_divmmc = '1' and nmi_state = S_NMI_ASSERT else '0';

   ------------------------------------------------------------
   -- EXPANSION BUS -------------------------------------------
   ------------------------------------------------------------
   
   --
   -- expansion bus control (changed during iowr to port 253b or nextreg instruction)
   --
   
   hotkey_expbus_freeze <= '1' when (port_divmmc_io_en_diff = '1' and divmmc_automap_held = '1') or (port_multiface_io_en_diff = '1' and mf_mem_en = '1') else '0';
   
   process (i_CLK_28)
   begin
      if rising_edge(i_CLK_28) then
         if reset_hard = '1' then
            nr_80_expbus <= (others => '0');
         elsif reset_soft = '1' then
            nr_80_expbus(7 downto 4) <= nr_80_expbus(3 downto 0);
         elsif nr_80_we = '1' then
            nr_80_expbus <= nr_wr_dat;
         elsif hotkey_expbus_enable = '1' and hotkey_expbus_freeze = '0' then
            nr_80_expbus(7) <= '1';
         elsif hotkey_expbus_disable = '1' and hotkey_expbus_freeze = '0' then
            nr_80_expbus(7) <= '0';
         end if;
      end if;
   end process;

   expbus_en <= nr_80_expbus(7);
   expbus_romcs_replace <= nr_80_expbus(6);
   expbus_disable_io <= nr_80_expbus(5);
   expbus_disable_mem <= nr_80_expbus(4);
   
   expbus_clken <= nr_81_expbus_clken;
   expbus_speed <= nr_81_expbus_speed;
   
   --
   -- expansion bus connection
   --
   
   -- filter io cycles
   -- external devices should see port fe, memory paging

   port_propagate_fe <= port_fe and nr_8a_bus_port_propagate(0);
   port_propagate_7ffd <= port_7ffd and nr_8a_bus_port_propagate(1);
   port_propagate_dffd <= port_dffd and nr_8a_bus_port_propagate(2);
   port_propagate_1ffd <= port_1ffd and nr_8a_bus_port_propagate(3);
   port_propagate_ff <= port_ff and nr_8a_bus_port_propagate(4);
   port_propagate_eff7 <= port_eff7 and nr_8a_bus_port_propagate(5);

   port_propagate <= port_propagate_fe or port_propagate_7ffd or port_propagate_dffd or port_propagate_1ffd or port_propagate_ff or port_propagate_eff7;
   
   bus_iorq_n <= cpu_iorq_n or (cpu_m1_n and ((port_internal_response or expbus_eff_disable_io) and not port_propagate));
   bus_mreq_n <= cpu_mreq_n or ((expbus_eff_disable_mem or (not cpu_a(15) and (not cpu_a(14)) and not sram_romcs_en)) and cpu_rfsh_n);

-- o_BUS_ADDR <= cpu_a;
-- o_BUS_DO <= cpu_do;
-- o_BUS_MREQ_n <= bus_mreq_n;
-- o_BUS_IORQ_n <= bus_iorq_n;
-- o_BUS_RD_n <= cpu_rd_n;
-- o_BUS_WR_n <= cpu_wr_n;
-- o_BUS_M1_n <= cpu_m1_n;
-- o_BUS_INT_n <= ula_int_n;
-- o_BUS_BUSAK_n <= '1';
-- o_BUS_HALT_n <= cpu_halt_n;
-- o_BUS_RFSH_n <= cpu_rfsh_n;

   ------------------------------------------------------------
   -- ALTERNATE ROM -------------------------------------------
   ------------------------------------------------------------

   process (i_CLK_28)
   begin
      if rising_edge(i_CLK_28) then
         if reset_hard = '1' then
            nr_8c_altrom <= (others => '0');
         elsif reset_soft = '1' then
            nr_8c_altrom(7 downto 4) <= nr_8c_altrom(3 downto 0);
         elsif nr_8c_we = '1' then
            nr_8c_altrom <= nr_wr_dat;
         end if;
      end if;
   end process;
   
   nr_8c_altrom_en <= nr_8c_altrom(7);
   nr_8c_altrom_rw <= nr_8c_altrom(6);
   nr_8c_altrom_lock_rom1 <= nr_8c_altrom(5);
   nr_8c_altrom_lock_rom0 <= nr_8c_altrom(4);

   ------------------------------------------------------------
   -- PI GPIO -------------------------------------------------
   ------------------------------------------------------------

   -- https://elinux.org/RPi_BCM2835_GPIOs
   
   -- todo: video in, video out, memory mapping, z80 bus
   
   pi_gpio_en <= nr_93_pi_gpio_o_en & nr_92_pi_gpio_o_en & nr_91_pi_gpio_o_en & nr_90_pi_gpio_o_en;
   pi_gpio_o <= nr_9b_pi_gpio_o & nr_9a_pi_gpio_o & nr_99_pi_gpio_o & nr_98_pi_gpio_o;
   
   pi_uart_rxtx <= nr_a0_pi_peripheral_en(5);
   pi_uart_en <= nr_a0_pi_peripheral_en(4);
   pi_i2c1_en <= nr_a0_pi_peripheral_en(3);
   pi_spi0_en <= nr_a0_pi_peripheral_en(0);
   
   pi_i2s_en <= nr_a2_pi_i2s_ctl(7) or nr_a2_pi_i2s_ctl(6);
   pi_i2s_enL <= nr_a2_pi_i2s_ctl(7);
   pi_i2s_enR <= nr_a2_pi_i2s_ctl(6);
   pi_i2s_inout <= nr_a2_pi_i2s_ctl(4);
   pi_i2s_muteL <= nr_a2_pi_i2s_ctl(3);
   pi_i2s_muteR <= nr_a2_pi_i2s_ctl(2);
-- pi_i2s_slave <= nr_a2_pi_i2s_ctl(1);
   pi_i2s_ear <= nr_a2_pi_i2s_ctl(0);

   -- spi0 7,8,9,10,11
   
   gpio_08_en <= '1' when pi_spi0_en = '1' else pi_gpio_en(8);
   gpio_08 <= spi_ss_rpi0_n when pi_spi0_en = '1' else pi_gpio_o(8);
   
   gpio_07_en <= '1' when pi_spi0_en = '1' else pi_gpio_en(7);
   gpio_07 <= spi_ss_rpi1_n when pi_spi0_en = '1' else pi_gpio_o(7);
   
   gpio_09_en <= '0' when pi_spi0_en = '1' else pi_gpio_en(9);
   pi_spi0_miso <= i_GPIO(9) when pi_spi0_en = '1' else '1';
   
   gpio_10_en <= '1' when pi_spi0_en = '1' else pi_gpio_en(10);
   gpio_10 <= spi_mosi when pi_spi0_en = '1' else pi_gpio_o(10);
   
   gpio_11_en <= '1' when pi_spi0_en = '1' else pi_gpio_en(11);
   gpio_11 <= spi_sck when pi_spi0_en = '1' else pi_gpio_o(11);

   -- i2c1 2,3
   
   gpio_02_en <= not i2c_sda_o when pi_i2c1_en = '1' else pi_gpio_en(2);
   gpio_02 <= '0' when pi_i2c1_en = '1' else pi_gpio_o(2);
   
   gpio_03_en <= not i2c_scl_o when pi_i2c1_en = '1' else pi_gpio_en(3);
   gpio_03 <= '0' when pi_i2c1_en = '1' else pi_gpio_o(3);
   
   pi_i2c1_sda <= i_GPIO(2) when pi_i2c1_en = '1' else '1';
   pi_i2c1_scl <= i_GPIO(3) when pi_i2c1_en = '1' else '1';

   -- uart 14,15 (need to cross wires for pi!)
   -- connect Rx to GPIO14 if pi_uart_rxtx = 1
   
   gpio_14_en <= not pi_uart_rxtx when pi_uart_en = '1' else pi_gpio_en(14);
   gpio_15_en <= pi_uart_rxtx when pi_uart_en = '1' else pi_gpio_en(15);
   
   gpio_14 <= uart1_tx_pi when pi_uart_en = '1' else pi_gpio_o(14);
   gpio_15 <= uart1_tx_pi when pi_uart_en = '1' else pi_gpio_o(15);
   
   pi_uart_rx <= (i_GPIO(14) and pi_uart_rxtx) or (i_GPIO(15) and not pi_uart_rxtx) when pi_uart_en = '1' else '1';

   -- i2s 18,19,20,21
   
-- gpio_18_en <= '1' when pi_i2s_en = '1' and pi_i2s_slave = '0' else '0' when pi_i2s_en = '1' and pi_i2s_slave = '1' else pi_gpio_en(18);
-- gpio_19_en <= '1' when pi_i2s_en = '1' and pi_i2s_slave = '0' else '0' when pi_i2s_en = '1' and pi_i2s_slave = '1' else pi_gpio_en(19);
   gpio_18_en <= '0' when pi_i2s_en = '1' else pi_gpio_en(18);
   gpio_19_en <= '0' when pi_i2s_en = '1' else pi_gpio_en(19);
   gpio_20_en <= pi_i2s_inout when pi_i2s_en = '1' else pi_gpio_en(20);
   gpio_21_en <= not pi_i2s_inout when pi_i2s_en = '1' else pi_gpio_en(21);
   
   gpio_18 <= pi_mi2s_sck when pi_i2s_en = '1' else pi_gpio_o(18);
   gpio_19 <= pi_mi2s_ws when pi_i2s_en = '1' else pi_gpio_o(19);
   gpio_20 <= pi_i2s_sd_o when pi_i2s_en = '1' else pi_gpio_o(20);
   gpio_21 <= pi_i2s_sd_o when pi_i2s_en = '1' else pi_gpio_o(21);
   
   pi_i2s_sd_i <= ((i_GPIO(21) and pi_i2s_inout) or (i_GPIO(20) and not pi_i2s_inout)) and pi_i2s_en;
   
-- pi_si2s_sck <= i_GPIO(18) and pi_i2s_en and pi_i2s_slave;
-- pi_si2s_ws <= i_GPIO(19) and pi_i2s_en and pi_i2s_slave;

   pi_si2s_sck <= i_GPIO(18) and pi_i2s_en;
   pi_si2s_ws <= i_GPIO(19) and pi_i2s_en;
   
   pi_audio_L <= ("10" & X"00") when (pi_i2s_en = '0' or pi_i2s_muteL = '1' or pi_i2s_ear = '1') else pi_i2s_audio_L when pi_i2s_enL = '1' else pi_i2s_audio_R;
   pi_audio_R <= ("10" & X"00") when (pi_i2s_en = '0' or pi_i2s_muteR = '1' or pi_i2s_ear = '1') else pi_i2s_audio_R when pi_i2s_enR = '1' else pi_i2s_audio_L;

   pi_fe_threshold <= pi_i2s_audio_L(9 downto 8) or pi_i2s_audio_R(9 downto 8);
   
   process (i_CLK_28)
   begin
      if rising_edge(i_CLK_28) then
         if pi_i2s_en = '0' or pi_i2s_ear = '0' then
            pi_fe_ear <= '0';
         elsif pi_fe_ear = '1' and pi_fe_threshold = "00" then
            pi_fe_ear <= '0';
         elsif pi_fe_ear = '0' and pi_fe_threshold = "11" then
            pi_fe_ear <= '1';
         end if;
      end if;
   end process;

   --
   -- pi gpio output
   --

-- o_GPIO <= pi_gpio_o(27 downto 22) & gpio_21 & gpio_20 & gpio_19 & gpio_18 & pi_gpio_o(17 downto 16) & gpio_15 & gpio_14 & pi_gpio_o(13 downto 12) & gpio_11 & gpio_10 & pi_gpio_o(9) & gpio_08 & gpio_07 & pi_gpio_o(6 downto 4) & gpio_03 & gpio_02 & pi_gpio_o(1 downto 0);
-- o_GPIO_EN <= pi_gpio_en(27 downto 22) & gpio_21_en & gpio_20_en & gpio_19_en & gpio_18_en & pi_gpio_en(17 downto 16) & gpio_15_en & gpio_14_en & pi_gpio_en(13 downto 12) & gpio_11_en & gpio_10_en & gpio_09_en & gpio_08_en & gpio_07_en & pi_gpio_en(6 downto 4) & gpio_03_en & gpio_02_en & pi_gpio_en(1 downto 0);


   ------------------------------------------------------------
   -- PORT DECODING -------------------------------------------
   ------------------------------------------------------------

   -- todo: investigate switching to pentagon method where decoding depends on instruction type "IN A,(n)" vs "IN r,(C)"

   --
   -- active port enables (changed during iowr to port 253b or nextreg instruction)
   --
   
   internal_port_enable <= (nr_85_internal_port_enable & nr_84_internal_port_enable & nr_83_internal_port_enable & nr_82_internal_port_enable) when expbus_eff_en = '0' else
                           ((nr_89_bus_port_enable and nr_85_internal_port_enable) & (nr_88_bus_port_enable and nr_84_internal_port_enable) & (nr_87_bus_port_enable and nr_83_internal_port_enable) & (nr_86_bus_port_enable and nr_82_internal_port_enable));
   
   --
   
   port_ff_io_en <= internal_port_enable(0);
   
   port_7ffd_io_en <= internal_port_enable(1);
   port_dffd_io_en <= internal_port_enable(2);
   port_1ffd_io_en <= internal_port_enable(3);
   
   port_p3_floating_bus_io_en <= internal_port_enable(4);
   
   port_dma_6b_io_en <= internal_port_enable(5);
   
   port_1f_io_en <= internal_port_enable(6);
   port_37_io_en <= internal_port_enable(7);
   
   --

   port_divmmc_io_en <= internal_port_enable(8);
   port_divmmc_io_en_diff <= nr_83_internal_port_enable(0) xor nr_87_bus_port_enable(0);
   
   port_multiface_io_en <= internal_port_enable(9);
   port_multiface_io_en_diff <= nr_83_internal_port_enable(1) xor nr_87_bus_port_enable(1);
   
   port_i2c_io_en <= internal_port_enable(10);
   port_spi_io_en <= internal_port_enable(11);
   port_uart_io_en <= internal_port_enable(12);
   
   port_mouse_io_en <= internal_port_enable(13);
   port_sprite_io_en <= internal_port_enable(14);
   port_layer2_io_en <= internal_port_enable(15);
   
   --
   
   port_ay_io_en <= internal_port_enable(16);
   port_dac_sd1_ABCD_1f0f4f5f_io_en <= internal_port_enable(17);   -- soundrive mode 1
   port_dac_sd2_ABCD_f1f3f9fb_io_en <= internal_port_enable(18);   -- soundrive mode 2
   port_dac_stereo_AD_3f5f_io_en <= internal_port_enable(19);   -- profi covox
   port_dac_stereo_BC_0f4f_io_en <= internal_port_enable(20);   -- covox
   port_dac_mono_AD_fb_io_en <= internal_port_enable(21) and not port_dac_sd2_ABCD_f1f3f9fb_io_en;   -- pentagon / atm (when mode 2 is off)
   port_dac_mono_BC_b3_io_en <= internal_port_enable(22);   -- gs covox
   port_dac_mono_AD_df_io_en <= internal_port_enable(23);   -- specdrum
   
   --
   
   port_ulap_io_en <= internal_port_enable(24);
   port_dma_0b_io_en <= internal_port_enable(25);
   port_eff7_io_en <= internal_port_enable(26);
   port_ctc_io_en <= internal_port_enable(27);
   
   --
   -- peripheral disable
   -- do not alter port decoding during an io cycle (nextreg changes can occur at any time)
   --

   process (i_CLK_28)
   begin
      if rising_edge(i_CLK_28) then
         if cpu_mreq_n = '0' then
         
            port_1f_hw_en <= joyL_1f_en or joyR_1f_en;
            port_37_hw_en <= joyL_37_en or joyR_37_en;
            
            p3_timing_hw_en <= machine_timing_p3;
            s128_timing_hw_en <= machine_timing_128;
            
            dac_hw_en <= nr_08_dac_en;

         end if;
      end if;
   end process;
   
   process (i_CLK_28)
   begin
      if rising_edge(i_CLK_28) then
         if cpu_iorq_n = '1' or memcycle_delay_complete = '0' then
            bus_iorq_ula <= expbus_eff_en and i_BUS_IORQULA_n and port_fe and cpu_m1_n and not expbus_eff_disable_io;
         else
            bus_iorq_ula <= '0';
         end if;
      end if;
   end process;

   --
   -- early decode of port addresses to allow filtering of io cycles to expansion bus
   --
   
   process (cpu_a(15 downto 8))
   begin
   
      port_00xx_msb <= '0';
      port_04xx_msb <= '0';
      port_05xx_msb <= '0';
      port_10xx_msb <= '0';
      port_11xx_msb <= '0';
      port_12xx_msb <= '0';
      port_13xx_msb <= '0';
      port_14xx_msb <= '0';
      port_15xx_msb <= '0';
      port_1fxx_msb <= '0';
      port_24xx_msb <= '0';
      port_25xx_msb <= '0';
      port_30xx_msb <= '0';
      port_3dxx_msb <= '0';
      port_7fxx_msb <= '0';
      port_bfxx_msb <= '0';
      port_fexx_msb <= '0';
      port_ffxx_msb <= '0';
      
      case cpu_a(15 downto 8) is
      
         when X"00"  => port_00xx_msb <= '1';
         when X"04"  => port_04xx_msb <= '1';
         when X"05"  => port_05xx_msb <= '1';
         when X"10"  => port_10xx_msb <= '1';
         when X"11"  => port_11xx_msb <= '1';
         when X"12"  => port_12xx_msb <= '1';
         when X"13"  => port_13xx_msb <= '1';
         when X"14"  => port_14xx_msb <= '1';
         when X"15"  => port_15xx_msb <= '1';
         when X"1F"  => port_1fxx_msb <= '1';
         when X"24"  => port_24xx_msb <= '1';
         when X"25"  => port_25xx_msb <= '1';
         when X"30"  => port_30xx_msb <= '1';
         when X"3D"  => port_3dxx_msb <= '1';
         when X"7F"  => port_7fxx_msb <= '1';
         when X"BF"  => port_bfxx_msb <= '1';
         when X"FE"  => port_fexx_msb <= '1';
         when X"FF"  => port_ffxx_msb <= '1';
         when others => null;
      
      end case;
   
   end process;
   
   process (cpu_a(7 downto 0))
   begin
   
      port_00_lsb <= '0';
      port_08_lsb <= '0';
      port_0b_lsb <= '0';
      port_0f_lsb <= '0';
      port_1f_lsb <= '0';
      port_37_lsb <= '0';
      port_38_lsb <= '0';
      port_3f_lsb <= '0';
      port_3b_lsb <= '0';
      port_4f_lsb <= '0';
      port_57_lsb <= '0';
      port_5b_lsb <= '0';
      port_5f_lsb <= '0';
      port_62_lsb <= '0';
      port_66_lsb <= '0';
      port_6b_lsb <= '0';
      port_b3_lsb <= '0';
      port_c6_lsb <= '0';
      port_df_lsb <= '0';
      port_e3_lsb <= '0';
      port_e7_lsb <= '0';
      port_eb_lsb <= '0';
      port_f1_lsb <= '0';
      port_f3_lsb <= '0';
      port_f7_lsb <= '0';
      port_f9_lsb <= '0';
      port_fb_lsb <= '0';
      port_ff_lsb <= '0';
   
      case cpu_a(7 downto 0) is
   
         when X"00"  => port_00_lsb <= '1';
         when X"08"  => port_08_lsb <= '1';
         when X"0B"  => port_0b_lsb <= '1';
         when X"0F"  => port_0f_lsb <= '1';
         when X"1F"  => port_1f_lsb <= '1';
         when X"37"  => port_37_lsb <= '1';
         when X"38"  => port_38_lsb <= '1';
         when X"3F"  => port_3f_lsb <= '1';
         when X"4F"  => port_4f_lsb <= '1';
         when X"57"  => port_57_lsb <= '1';
         when X"5B"  => port_5b_lsb <= '1';
         when X"5F"  => port_5f_lsb <= '1';
         when X"3B"  => port_3b_lsb <= '1';
         when X"62"  => port_62_lsb <= '1';
         when X"66"  => port_66_lsb <= '1';
         when X"6B"  => port_6b_lsb <= '1';
         when X"B3"  => port_b3_lsb <= '1';
         when X"C6"  => port_c6_lsb <= '1';
         when X"DF"  => port_df_lsb <= '1';
         when X"E3"  => port_e3_lsb <= '1';
         when X"E7"  => port_e7_lsb <= '1';
         when X"EB"  => port_eb_lsb <= '1';
         when X"F1"  => port_f1_lsb <= '1';
         when X"F3"  => port_f3_lsb <= '1';
         when X"F7"  => port_f7_lsb <= '1';
         when X"F9"  => port_f9_lsb <= '1';
         when X"FB"  => port_fb_lsb <= '1';
         when X"FF"  => port_ff_lsb <= '1';
         when others => null;

      end case;

   end process;
   
   port_fd <= '1' when cpu_a(1 downto 0) = "01" else '0';

   -- ula/scld
   
   port_fe <= '1' when cpu_a(0) = '0' else '0';
   port_ff <= '1' when port_ff_lsb = '1' else '0';
   
   port_fe_override <= '1' when cpu_a(7 downto 4) = "0000" and nr_81_expbus_ula_override = '1' else '0';
   
   -- +3 floating bus
   
-- port_p3_float_active <= '1' when cpu_a(15 downto 12) = "0000" and port_fd = '1' and p3_timing_hw_en = '1' else '0';
-- port_p3_float <= '1' when port_p3_float_active = '1' and port_p3_floating_bus_io_en = '1' else '0';
   port_p3_float <= '1' when cpu_a(15 downto 12) = "0000" and port_fd = '1' and p3_timing_hw_en = '1' and port_p3_floating_bus_io_en = '1' else '0';
   
   -- original spectrum banking

   port_7ffd_assert <= '1' when cpu_a(15) = '0' and (cpu_a(14) = '1' or p3_timing_hw_en = '0') and port_fd = '1' and port_1ffd = '0' else '0';
   port_7ffd_active <= '1' when port_7ffd_assert = '1' and (s128_timing_hw_en = '1' or p3_timing_hw_en = '1') else '0';
   port_7ffd <= '1' when port_7ffd_assert = '1' and port_7ffd_io_en = '1' else '0';
   
   port_dffd <= '1' when cpu_a(15 downto 12) = "1101" and port_fd = '1' and port_dffd_io_en = '1' else '0';

   port_1ffd_assert <= '1' when cpu_a(15 downto 12) = "0001" and port_fd = '1' else '0';
-- port_1ffd_active <= '1' when port_1ffd_assert = '1' and p3_timing_hw_en = '1' else '0';
   port_1ffd <= '1' when port_1ffd_assert = '1' and port_1ffd_io_en = '1' else '0';
   
   port_eff7 <= '1' when cpu_a(15 downto 12) = "1110" and port_f7_lsb = '1' and port_eff7_io_en = '1' else '0';
   
   -- divmmc control
   
   port_e3 <= '1' when port_e3_lsb = '1' and port_divmmc_io_en = '1' else '0';
   
   -- multiface

   port_mf_enable_io_a <= X"9F" when nr_0a_mf_type(1) = '1' else X"BF" when nr_0a_mf_type(0) = '1' else X"3F";
   port_mf_disable_io_a <= X"1F" when nr_0a_mf_type(1) = '1' else X"3F" when nr_0a_mf_type(0) = '1' else X"BF";
   
   port_mf_enable <= '1' when cpu_a(7 downto 0) = port_mf_enable_io_a and port_multiface_io_en = '1' else '0';
   port_mf_disable <= '1' when cpu_a(7 downto 0) = port_mf_disable_io_a and port_multiface_io_en = '1' else '0';
   
   -- spi
   
   port_e7 <= '1' when port_e7_lsb = '1' and port_spi_io_en = '1' else '0';
   port_eb <= '1' when port_eb_lsb = '1' and port_spi_io_en = '1' else '0';
   
   -- nextreg
   
   port_243b <= '1' when port_24xx_msb = '1' and port_3b_lsb = '1' else '0';
   port_253b <= '1' when port_25xx_msb = '1' and port_3b_lsb = '1' else '0';
   
   -- i2c
   
   port_103b <= '1' when port_10xx_msb = '1' and port_3b_lsb = '1' and port_i2c_io_en = '1' else '0';
   port_113b <= '1' when port_11xx_msb = '1' and port_3b_lsb = '1' and port_i2c_io_en = '1' else '0';
   
   -- layer 2
   
   port_123b <= '1' when port_12xx_msb = '1' and port_3b_lsb = '1' and port_layer2_io_en = '1' else '0';
   
   -- uart
   
   port_133b <= '1' when port_13xx_msb = '1' and port_3b_lsb = '1' and port_uart_io_en = '1' else '0';
   port_143b <= '1' when port_14xx_msb = '1' and port_3b_lsb = '1' and port_uart_io_en = '1' else '0';
   port_153b <= '1' when port_15xx_msb = '1' and port_3b_lsb = '1' and port_uart_io_en = '1' else '0';
   
   -- dma
   
   port_dma <= '1' when (port_6b_lsb = '1' and port_dma_6b_io_en = '1') or (port_0b_lsb = '1' and port_dma_0b_io_en = '1') else '0';
   
   -- ay
   
   port_fffd <= '1' when cpu_a(15 downto 14) = "11" and cpu_a(2) = '1' and port_fd = '1' and port_ay_io_en = '1' else '0';
   port_bffd <= '1' when cpu_a(15 downto 14) = "10" and cpu_a(2) = '1' and port_fd = '1' and port_ay_io_en = '1' else '0';
   
   -- audio dac
   
   -- A  -   FB  DF  1F  F1  -  3F
   -- B  B3  -   -   0F  F3  0F -
   -- C  B3  -   -   4F  F9  4F -
   -- D  -   FB  DF  5F  FB  -  5F
   
   port_dac_mono_AD <= '1' when (port_fb_lsb = '1' and port_dac_mono_AD_fb_io_en = '1') or (port_df_lsb = '1' and port_dac_mono_AD_df_io_en = '1') else '0';
   port_dac_mono_BC <= '1' when (port_b3_lsb = '1' and port_dac_mono_BC_b3_io_en = '1') else '0';
   
   port_dac_A <= '1' when port_dac_mono_AD = '1' or (port_1f_lsb = '1' and port_dac_sd1_ABCD_1f0f4f5f_io_en = '1') or (port_f1_lsb = '1' and port_dac_sd2_ABCD_f1f3f9fb_io_en = '1') or (port_3f_lsb = '1' and port_dac_stereo_AD_3f5f_io_en = '1') else '0';
   port_dac_B <= '1' when port_dac_mono_BC = '1' or (port_0f_lsb = '1' and (port_dac_sd1_ABCD_1f0f4f5f_io_en = '1' or port_dac_stereo_BC_0f4f_io_en = '1')) or (port_f3_lsb = '1' and port_dac_sd2_ABCD_f1f3f9fb_io_en = '1') else '0';
   port_dac_C <= '1' when port_dac_mono_BC = '1' or (port_4f_lsb = '1' and (port_dac_sd1_ABCD_1f0f4f5f_io_en = '1' or port_dac_stereo_BC_0f4f_io_en = '1')) or (port_f9_lsb = '1' and port_dac_sd2_ABCD_f1f3f9fb_io_en = '1') else '0';
   port_dac_D <= '1' when port_dac_mono_AD = '1' or (port_5f_lsb = '1' and (port_dac_sd1_ABCD_1f0f4f5f_io_en = '1' or port_dac_stereo_AD_3f5f_io_en = '1')) or (port_fb_lsb = '1' and port_dac_sd2_ABCD_f1f3f9fb_io_en = '1') else '0';

   -- kempston mouse
   
   port_fadf <= '1' when cpu_a(11 downto 8) = X"A" and port_df_lsb = '1' and port_mouse_io_en = '1' else '0';
   port_fbdf <= '1' when cpu_a(11 downto 8) = X"B" and port_df_lsb = '1' and port_mouse_io_en = '1' else '0';
   port_ffdf <= '1' when cpu_a(11 downto 8) = X"F" and port_df_lsb = '1' and port_mouse_io_en = '1' else '0';
   
   -- joystick
   
   port_1f <= '1' when port_1f_lsb = '1' and port_1f_io_en = '1' and port_1f_hw_en = '1' else '0';
   port_37 <= '1' when port_37_lsb = '1' and port_37_io_en = '1' else '0';
   
   -- sprites
   
   port_57 <= '1' when port_57_lsb = '1' and port_sprite_io_en = '1' else '0';
   port_5b <= '1' when port_5b_lsb = '1' and port_sprite_io_en = '1' else '0';
   port_303b <= '1' when port_30xx_msb = '1' and port_3b_lsb = '1' and port_sprite_io_en = '1' else '0';

   -- ula+
   
   port_bf3b <= '1' when port_bfxx_msb = '1' and port_3b_lsb = '1' and port_ulap_io_en = '1' else '0';
   port_ff3b <= '1' when port_ffxx_msb = '1' and port_3b_lsb = '1' and port_ulap_io_en = '1' else '0';
   
   -- z80 ctc
   
   port_ctc <= '1' when cpu_a(15 downto 11) = "00011" and port_3b_lsb = '1' and port_ctc_io_en = '1' else '0';
   
   --
   
   -- check if xst handles this well
   
   port_internal_response <= port_fe or port_ff or port_p3_float or port_7ffd or port_dffd or port_1ffd or port_eff7 or port_e3 or
      port_mf_enable or port_mf_disable or port_e7 or port_eb or port_243b or port_253b or port_103b or port_113b or port_123b or port_133b or 
      port_143b or port_153b or port_dma or port_fffd or port_bffd or port_dac_A or port_dac_B or port_dac_C or port_dac_D or
      port_fadf or port_fbdf or port_ffdf or port_1f or port_37 or port_57 or port_5b or port_303b or port_bf3b or port_ff3b or port_ctc;
   
   --
   -- complete port decode with iorq, rd, wr, m1
   --

   iord <= '1' when cpu_iorq_n = '0' and cpu_m1_n = '1' and cpu_rd_n = '0' else '0';
   iowr <= '1' when cpu_iorq_n = '0' and cpu_m1_n = '1' and cpu_wr_n = '0' else '0';
   
   port_fd_conflict_wr <= (port_f1_lsb and port_dac_sd2_ABCD_f1f3f9fb_io_en) or (port_f9_lsb and port_dac_sd2_ABCD_f1f3f9fb_io_en);
   
   port_fe_rd <= iord and port_fe;
   port_fe_wr <= iowr and port_fe;
   
   port_ff_rd <= iord and port_ff;
   port_ff_wr <= iowr and port_ff and port_ff_io_en;
   
   port_p3_float_rd <= iord and port_p3_float;
   
   port_7ffd_wr <= iowr and port_7ffd and not port_fd_conflict_wr;
   port_dffd_wr <= iowr and port_dffd and not port_fd_conflict_wr;
   port_1ffd_wr <= iowr and port_1ffd and not port_fd_conflict_wr;
   port_eff7_wr <= iowr and port_eff7;
   
   port_e3_rd <= iord and port_e3;
   port_e3_wr <= iowr and port_e3;
   
   port_mf_enable_rd <= iord and port_mf_enable;
   port_mf_enable_wr <= iowr and port_mf_enable;
   port_mf_disable_rd <= iord and port_mf_disable;
   port_mf_disable_wr <= iowr and port_mf_disable;
   
   port_e7_wr <= iowr and port_e7;
   port_eb_rd <= iord and port_eb;
   port_eb_wr <= iowr and port_eb;
   
   port_243b_rd <= iord and port_243b;
   port_243b_wr <= iowr and port_243b;
   port_253b_rd <= iord and port_253b;
   port_253b_wr <= iowr and port_253b;

   port_103b_rd <= iord and port_103b;
   port_103b_wr <= iowr and port_103b;
   port_113b_rd <= iord and port_113b;
   port_113b_wr <= iowr and port_113b;
   
   port_123b_rd <= iord and port_123b;
   port_123b_wr <= iowr and port_123b;
   
   port_133b_rd <= iord and port_133b;
   port_133b_wr <= iowr and port_133b;
   port_143b_rd <= iord and port_143b;
   port_143b_wr <= iowr and port_143b;
   port_153b_rd <= iord and port_153b;
   port_153b_wr <= iowr and port_153b;
   
   port_dma_rd <= iord and port_dma and not dma_holds_bus;
   port_dma_wr <= iowr and port_dma and not dma_holds_bus;
   
   port_fffd_rd <= iord and (port_fffd or (port_bffd and machine_timing_p3));   -- bffd is readable equivalent to fffd on +3
   port_fffd_wr <= iowr and port_fffd and not port_dffd;
   port_bffd_wr <= iowr and port_bffd;

   port_dac_A_wr <= iowr and port_dac_A and dac_hw_en;
   port_dac_B_wr <= iowr and port_dac_B and dac_hw_en;
   port_dac_C_wr <= iowr and port_dac_C and dac_hw_en;
   port_dac_D_wr <= iowr and port_dac_D and dac_hw_en;
   
   port_fadf_rd <= iord and port_fadf;
   port_fbdf_rd <= iord and port_fbdf;
   port_ffdf_rd <= iord and port_ffdf;
   
   port_1f_rd <= iord and port_1f;
   port_37_rd <= iord and port_37 and port_37_hw_en;
   port_37_wr <= iowr and port_37;
   
   port_57_wr <= iowr and port_57;
   port_5b_wr <= iowr and port_5b;
   port_303b_rd <= iord and port_303b;
   port_303b_wr <= iowr and port_303b;

   port_bf3b_wr <= iowr and port_bf3b;
   port_ff3b_rd <= iord and port_ff3b;
   port_ff3b_wr <= iowr and port_ff3b;
   
   port_ctc_wr <= iowr and port_ctc;
   port_ctc_rd <= iord and port_ctc;
   
   --
   
   -- check if xst handles this well
   
   port_internal_rd_response <= port_fe_rd or port_ff_rd or port_p3_float_rd or port_e3_rd or mf_port_en or 
      port_eb_rd or port_243b_rd or port_253b_rd or port_103b_rd or port_113b_rd or port_123b_rd or port_133b_rd or
      port_143b_rd or port_153b_rd or port_dma_rd or port_fffd_rd or port_fadf_rd or port_fbdf_rd or port_ffdf_rd or
      port_1f_rd or port_37_rd or port_303b_rd or port_ff3b_rd or port_ctc_rd;
   
   --
   -- Use wired-or logic to avoid expensive if-elsif-endif chain
   --

   port_fe_rd_dat <= port_fe_dat when port_fe_rd = '1' else X"00";
   port_ff_rd_dat <= port_ff_dat_tmx when nr_08_port_ff_rd_en = '1' and port_ff_io_en = '1' and port_ff_rd = '1' else port_ff_dat_ula when port_ff_rd = '1' else X"00";
   port_p3_float_rd_dat <= port_p3_floating_bus_dat when port_p3_float_rd = '1' else X"00";
   port_e3_rd_dat <= port_e3_dat when port_e3_rd = '1' else X"00";
   port_mf_rd_dat <= mf_port_dat when mf_port_en = '1' else X"00";
   port_eb_rd_dat <= port_eb_dat when port_eb_rd = '1' else X"00";
   port_243b_rd_dat <= port_243b_dat when port_243b_rd = '1' else X"00";
   port_253b_rd_dat <= port_253b_dat_0 when port_253b_rd = '1' else X"00";
   port_103b_rd_dat <= port_103b_dat when port_103b_rd = '1' else X"00";
   port_113b_rd_dat <= port_113b_dat when port_113b_rd = '1' else X"00";
   port_123b_rd_dat <= port_123b_dat when port_123b_rd = '1' else X"00";
   port_133b_rd_dat <= port_133b_dat when port_133b_rd = '1' else X"00";
   port_143b_rd_dat <= port_143b_dat when port_143b_rd = '1' else X"00";
   port_153b_rd_dat <= port_153b_dat when port_153b_rd = '1' else X"00";
   port_dma_rd_dat <= port_dma_dat when port_dma_rd = '1' else X"00";
   port_fffd_rd_dat <= port_fffd_dat when port_fffd_rd = '1' else X"00";
   port_fadf_rd_dat <= port_fadf_dat when port_fadf_rd = '1' else X"00";
   port_fbdf_rd_dat <= port_fbdf_dat when port_fbdf_rd = '1' else X"00";
   port_ffdf_rd_dat <= port_ffdf_dat when port_ffdf_rd = '1' else X"00";
   port_1f_rd_dat <= port_1f_dat when port_1f_rd = '1' else X"00";
   port_37_rd_dat <= port_37_dat when port_37_rd = '1' else X"00";
   port_303b_rd_dat <= port_303b_dat when port_303b_rd = '1' else X"00";
   port_ff3b_rd_dat <= port_ff3b_dat when port_ff3b_rd = '1' else X"00";
   port_ctc_rd_dat <= port_ctc_dat when port_ctc_rd = '1' else X"00";
   
   -- check if xst handles this well
   
   port_rd_dat <= port_fe_rd_dat or port_ff_rd_dat or port_p3_float_rd_dat or port_e3_rd_dat or port_mf_rd_dat or 
      port_eb_rd_dat or port_243b_rd_dat or port_253b_rd_dat or port_103b_rd_dat or port_113b_rd_dat or port_123b_rd_dat or port_133b_rd_dat or
      port_143b_rd_dat or port_153b_rd_dat or port_dma_rd_dat or port_fffd_rd_dat or port_fadf_rd_dat or port_fbdf_rd_dat or
      port_ffdf_rd_dat or port_1f_rd_dat or port_37_rd_dat or port_303b_rd_dat or port_ff3b_rd_dat or port_ctc_rd_dat;
   
   ------------------------------------------------------------
   -- MEMORY ADDRESSES ----------------------------------------
   ------------------------------------------------------------

   -- divmmc
   
   divmmc_automap_en_instant <= port_3dxx_msb;
   divmmc_automap_en_delayed <= (port_00xx_msb and port_08_lsb) or (port_00xx_msb and port_38_lsb) or (port_04xx_msb and port_c6_lsb) or (port_05xx_msb and port_62_lsb);
   divmmc_automap_en_delayed_nohide <= port_00xx_msb and port_00_lsb;
   divmmc_automap_en_delayed_nohide_nmi <= port_00xx_msb and port_66_lsb;
   divmmc_automap_dis_delayed <= '1' when port_1fxx_msb = '1' and cpu_a(7 downto 3) = "11111" else '0';
   
   -- multiface
   
   mf_a_0066 <= port_00xx_msb and port_66_lsb;
   mf_a_1fxx <= port_1fxx_msb;
   mf_a_7fxx <= port_7fxx_msb;
   mf_a_fexx <= port_fexx_msb;

   ------------------------------------------------------------
   -- MEMORY DECODING -----------------------------------------
   ------------------------------------------------------------

   -- 0x000000 - 0x00FFFF (64K)  => ZX Spectrum ROM         A20:A16 = 00000
   -- 0x010000 - 0x011FFF ( 8K)  => divMMC ROM              A20:A16 = 00001,000
   -- 0x012000 - 0x013FFF ( 8K)  => unused                  A20:A16 = 00001,001
   -- 0x014000 - 0x017FFF (16K)  => Multiface ROM,RAM       A20:A16 = 00001,01
   -- 0x018000 - 0x01BFFF (16K)  => Alt ROM0 128k           A20:A16 = 00001,10
   -- 0x01c000 - 0x01FFFF (16K)  => Alt ROM1 48k            A20:A16 = 00001,11
   -- 0x020000 - 0x03FFFF (128K) => divMMC RAM              A20:A16 = 00010
   -- 0x040000 - 0x05FFFF (128K) => ZX Spectrum RAM         A20:A16 = 00100
   -- 0x060000 - 0x07FFFF (128K) => Extra RAM
   -- 0x080000 - 0x0FFFFF (512K) => 1st Extra IC RAM (if present)
   -- 0x100000 - 0x17FFFF (512K) => 2nd Extra IC RAM (if present)
   -- 0x180000 - 0x1FFFFF (512K) => 3rd Extra IC RAM (if present)
   
   -- memory decode order
   --
   -- 0-16k:
   --   1. bootrom
   --   2. machine config mapping
   --   3. multiface
   --   4. divmmc
   --   5. layer 2 mapping
   --   6. mmu
   --   7. romcs expansion bus
   --   8. rom
   --
   -- 16k-48k:
   --   1. layer 2 mapping
   --   2. mmu
   --
   -- 48k-64k:
   --   1. mmu

   mem_active_page <= MMU0 when cpu_a(15 downto 13) = "000" else
                      MMU1 when cpu_a(15 downto 13) = "001" else
                      MMU2 when cpu_a(15 downto 13) = "010" else
                      MMU3 when cpu_a(15 downto 13) = "011" else
                      MMU4 when cpu_a(15 downto 13) = "100" else
                      MMU5 when cpu_a(15 downto 13) = "101" else
                      MMU6 when cpu_a(15 downto 13) = "110" else
                      MMU7;

   layer2_active_bank_offset_pre <= cpu_a(15 downto 14) when port_123b_layer2_map_segment = "11" else port_123b_layer2_map_segment;
   layer2_active_bank_offset <= ("00" & layer2_active_bank_offset_pre) + ('0' & port_123b_layer2_offset);
   layer2_active_bank <= nr_12_layer2_active_bank when port_123b_layer2_map_shadow = '0' else nr_13_layer2_shadow_bank;
   layer2_active_page <= (('0' & layer2_active_bank) + ("0000" & layer2_active_bank_offset)) & cpu_a(13);

   -- note that the copper can change mmu and the layer 2 base bank so these must be frozen during a memory access
   
   --
   -- early memory decode before assertion of mreq where possible
   --

   sram_config_active <= '1' when bootrom_en = '1' or machine_type_config = '1' else '0';

   mmu_A21_A13 <= ("0001" + ('0' & mem_active_page(7 downto 5))) & mem_active_page(4 downto 0);
   layer2_A21_A13 <= ("0001" + ('0' & layer2_active_page(7 downto 5))) & layer2_active_page(4 downto 0);
   
   mem_active_bank5 <= '1' when mem_active_page = X"0A" or mem_active_page = X"0B" else '0';
   mem_active_bank7 <= '1' when mem_active_page = X"0E" else '0';

   process (machine_type_48, machine_type_p3, nr_8c_altrom_lock_rom1, nr_8c_altrom_lock_rom0, port_1ffd_rom)
   begin
      if machine_type_48 = '1' then
         sram_active_rom <= "00";
         sram_rom3 <= '1';
         sram_alt_128 <= (not nr_8c_altrom_lock_rom1) and nr_8c_altrom_lock_rom0;
      elsif machine_type_p3 = '1' then
         if nr_8c_altrom_lock_rom1 = '1' or nr_8c_altrom_lock_rom0 = '1' then
            sram_active_rom <= nr_8c_altrom_lock_rom1 & nr_8c_altrom_lock_rom0;
            sram_rom3 <= nr_8c_altrom_lock_rom1 and nr_8c_altrom_lock_rom0;
            sram_alt_128 <= not nr_8c_altrom_lock_rom1;
         else
            sram_active_rom <= port_1ffd_rom;
            sram_rom3 <= port_1ffd_rom(1) and port_1ffd_rom(0);
            sram_alt_128 <= not port_1ffd_rom(0);   -- behave like a 128k machine
         end if;
      else
         if nr_8c_altrom_lock_rom1 = '1' or nr_8c_altrom_lock_rom0 = '1' then
            sram_active_rom <= '0' & nr_8c_altrom_lock_rom1;
            sram_rom3 <= nr_8c_altrom_lock_rom1;
            sram_alt_128 <= not nr_8c_altrom_lock_rom1;
         else
            sram_active_rom <= '0' & port_1ffd_rom(0);
            sram_rom3 <= port_1ffd_rom(0);
            sram_alt_128 <= not port_1ffd_rom(0);
         end if;
      end if;
   end process;

   process (i_CLK_28)
   begin
      if falling_edge(i_CLK_28) then
         if cpu_mreq_n = '1' then
         
            layer2_pre_A21_A13 <= layer2_A21_A13;
            eff_bootrom_en <= bootrom_en;
            eff_expbus_romcs_replace <= expbus_romcs_replace;
            sram_pre_alt_128 <= sram_alt_128;
            port_123b_layer2_map_rd_pre <= port_123b_layer2_map_rd_en;
            port_123b_layer2_map_wr_pre <= port_123b_layer2_map_wr_en;
            port_123b_layer2_map_segment_pre <= port_123b_layer2_map_segment;
            
            sram_pre_active <= '0';
            sram_pre_bank5 <= '0';
            sram_pre_bank7 <= '0';
            sram_pre_rdonly <= '0';
            sram_pre_romcs <= '0';
            sram_pre_alt_en <= '0';
            sram_pre_rom3 <= '0';

            if cpu_a(15 downto 14) = "00" then
               if sram_config_active = '1' then
                  sram_pre_A20_A13 <= nr_04_romram_bank & cpu_a(13);
                  sram_pre_active <= not bootrom_en;
               elsif mmu_A21_A13(8) = '0' then
                  sram_pre_A20_A13 <= mmu_A21_A13(7 downto 0);
                  sram_pre_active <= not (mem_active_bank5 or mem_active_bank7);
                  sram_pre_bank5 <= mem_active_bank5;
                  sram_pre_bank7 <= mem_active_bank7;
               else
                  sram_pre_A20_A13 <= "00000" & sram_active_rom & cpu_a(13);
                  sram_pre_active <= '1';
                  sram_pre_rdonly <= not (nr_8c_altrom_en and nr_8c_altrom_rw);
                  sram_pre_romcs <= not expbus_eff_disable_mem;
                  sram_pre_alt_en <= nr_8c_altrom_en;
                  sram_pre_rom3 <= sram_rom3;
               end if;
            elsif mmu_A21_A13(8) = '0' then
               sram_pre_A20_A13 <= mmu_A21_A13(7 downto 0);
               sram_pre_active <= not (mem_active_bank5 or mem_active_bank7);
               sram_pre_bank5 <= mem_active_bank5;
               sram_pre_bank7 <= mem_active_bank7;
            end if;
         end if;
      end if;
   end process;
   
   --
   -- finish memory decode after mreq is asserted
   --
   
   layer2_map_en <= (port_123b_layer2_map_wr_pre and cpu_rd_n) or (port_123b_layer2_map_rd_pre and not cpu_rd_n);
   altrom_en <= '0' when (sram_pre_alt_en = '0') or (sram_pre_rdonly = '1' and cpu_wr_n = '0') or (sram_pre_rdonly = '0' and cpu_rd_n = '0') else '1';

   process (cpu_a, sram_config_active, sram_pre_A20_A13, sram_pre_active, mf_mem_en, divmmc_rom_en, divmmc_ram_en, divmmc_bank, altrom_en, sram_pre_alt_128, sram_romcs,
            divmmc_rdonly, layer2_map_en, layer2_pre_A21_A13, sram_pre_bank5, sram_pre_bank7, sram_pre_rdonly, sram_pre_romcs, port_123b_layer2_map_segment_pre)
   begin
      if cpu_a(15 downto 14) = "00" then
         if sram_config_active = '1' then
            sram_A20_A13 <= sram_pre_A20_A13;
            sram_active <= sram_pre_active;
            sram_bank5 <= '0';
            sram_bank7 <= '0';
            sram_rdonly <= '0';
            sram_romcs_en <= '0';
         elsif mf_mem_en = '1' then
            sram_A20_A13 <= "0000101" & cpu_a(13);
            sram_active <= '1';
            sram_bank5 <= '0';
            sram_bank7 <= '0';
            sram_rdonly <= not cpu_a(13);
            sram_romcs_en <= '0';
         elsif divmmc_rom_en = '1' then
            sram_A20_A13 <= "00001000";
            sram_active <= '1';
            sram_bank5 <= '0';
            sram_bank7 <= '0';
            sram_rdonly <= '1';
            sram_romcs_en <= '0';
         elsif divmmc_ram_en = '1' then
            sram_A20_A13 <= "0001" & divmmc_bank;
            sram_active <= '1';
            sram_bank5 <= '0';
            sram_bank7 <= '0';
            sram_rdonly <= divmmc_rdonly;
            sram_romcs_en <= '0';
         elsif layer2_map_en = '1' then
            sram_A20_A13 <= layer2_pre_A21_A13(7 downto 0);
            sram_active <= not layer2_pre_A21_A13(8);
            sram_bank5 <= '0';
            sram_bank7 <= '0';
            sram_rdonly <= '0';
            sram_romcs_en <= '0';
         else
            if sram_romcs = '1' then
               sram_A20_A13 <= "0001111" & cpu_a(13);    -- divmmc banks 14 and 15
            else
               sram_A20_A13(7 downto 4) <= sram_pre_A20_A13(7 downto 4);
               sram_A20_A13(0) <= sram_pre_A20_A13(0);
               if altrom_en = '0' then
                  sram_A20_A13(3 downto 1) <= sram_pre_A20_A13(3 downto 1);
               else
                  sram_A20_A13(3 downto 1) <= "11" & not sram_pre_alt_128;
               end if;
            end if;
            sram_active <= sram_pre_active;
            sram_bank5 <= sram_pre_bank5;
            sram_bank7 <= sram_pre_bank7;
            sram_rdonly <= sram_pre_rdonly or sram_romcs;
            sram_romcs_en <= sram_pre_romcs;
         end if;
      elsif cpu_a(15 downto 14) /= "11" and layer2_map_en = '1' and port_123b_layer2_map_segment_pre = "11" then
         sram_A20_A13 <= layer2_pre_A21_A13(7 downto 0);
         sram_active <= not layer2_pre_A21_A13(8);
         sram_bank5 <= '0';
         sram_bank7 <= '0';
         sram_rdonly <= '0';
         sram_romcs_en <= '0';
      else
         sram_A20_A13 <= sram_pre_A20_A13;
         sram_active <= sram_pre_active;
         sram_bank5 <= sram_pre_bank5;
         sram_bank7 <= sram_pre_bank7;
         sram_rdonly <= sram_pre_rdonly;
         sram_romcs_en <= '0';
      end if;
   end process;
   
   sram_obscure_divmmc_automap <= sram_config_active or mf_mem_en;
   sram_disable_divmmc_automap <= sram_obscure_divmmc_automap or ((not divmmc_automap_held) and (layer2_map_en or sram_romcs or (altrom_en and sram_pre_alt_128) or ((not altrom_en) and not sram_pre_rom3)));
   
   --
   -- generate memory cycle in top level sram, bram banks 5/7, bootrom
   --
   
   memcycle <= '1' when cpu_mreq_n = '0' and cpu_rfsh_n = '1' else '0';
   
   -- must extend memory cycle for romcs from expansion bus with amount of extension dependent on cpu speed
   
   process (i_CLK_28)
   begin
      if rising_edge(i_CLK_28) then
         if cpu_mreq_n = '1' and cpu_iorq_n = '1' then
            memcycle_delay <= (others => '0');
         elsif memcycle_delay_complete = '0' then
            memcycle_delay <= memcycle_delay + 1;
         end if;
      end if;
   end process;
   
   process (cpu_mreq_n, cpu_speed)
   begin
      if cpu_mreq_n = '0' then
         if cpu_speed = "00" then
            memcycle_delay_end <= "1001";
         else
            memcycle_delay_end <= "0011";
         end if;
      else
         if cpu_speed = "00" then
            memcycle_delay_end <= "1111";
         else
            memcycle_delay_end <= "0110";
         end if;
      end if;
   end process;
   
   memcycle_delay_complete <= '1' when cpu_speed = "11" or cpu_speed = "10" or expbus_eff_en = '0' or sram_romcs_en = '0' or memcycle_delay = memcycle_delay_end else '0';
   
   process (i_CLK_28)
   begin
      if rising_edge(i_CLK_28) then
         if cpu_mreq_n = '1' then
            sram_romcs <= '0';
         elsif memcycle_delay_complete = '0' then
            sram_romcs <= expbus_eff_en and sram_romcs_en and i_BUS_ROMCS_n;
         end if;
      end if;
   end process;
   
   -- memory signals
   
   cpu_bank5_rd <= memcycle and memcycle_delay_complete and sram_bank5 and not cpu_rd_n;
   cpu_bank5_we <= memcycle and memcycle_delay_complete and sram_bank5 and not cpu_wr_n;
   cpu_bank7_we <= memcycle and memcycle_delay_complete and sram_bank7 and not cpu_wr_n;
   
   sram_addr <= sram_A20_A13 & cpu_a(12 downto 0);
   sram_rd <= not cpu_rd_n;
   sram_req <= memcycle and memcycle_delay_complete and (eff_expbus_romcs_replace or not sram_romcs) and sram_active and ((not cpu_rd_n) or ((not sram_rdonly) and not cpu_wr_n));
   
   process (i_CLK_28)
   begin
      if rising_edge(i_CLK_28) then
         if reset = '1' then
            sram_req_dly <= '0';
         else
            sram_req_dly <= sram_req;
         end if;
      end if;
   end process;

   sram_req_t <= sram_req and not sram_req_dly;
   
   -- wait states on instruction fetches at 28MHz
   
   process (i_CLK_28)
   begin
      if rising_edge(i_CLK_28) then
--       if sram_req_t = '1' and cpu_rd_n = '0' and cpu_speed = "11" and (cpu_m1_n = '0' or dma_holds_bus = '1') then
         if (sram_req_t = '1' or cpu_bank5_sched = '1') and cpu_rd_n = '0' and cpu_speed = "11" then
            sram_wait_n <= '0';
         else
            sram_wait_n <= '1';
         end if;
      end if;
   end process;

-- signals must be delivered before the next rising edge of i_CLK_28
--
-- o_RAM_A_ADDR <= sram_addr;
-- o_RAM_A_REQ <= sram_req_t;
-- o_RAM_A_RD <= sram_rd;
-- o_RAM_A_DO <= cpu_do;

   --
   -- BOOT ROM
   --
   
   bootrom_mod: entity work.bootrom
   port map (
      clk      => i_CLK_28,
      addr     => cpu_a(12 downto 0),
      data     => bootrom_do
   );
   
   ------------------------------------------------------------
   -- SERIAL COMMS --------------------------------------------
   ------------------------------------------------------------

   --
   -- I2C MASTER (bit-banged)
   --

   -- write
   
   process (i_CLK_28)
   begin
      if rising_edge(i_CLK_28) then
         if reset = '1' then
            i2c_scl_o <= '1';
         elsif port_103b_wr = '1' then
            i2c_scl_o <= cpu_do(0);
         end if;
      end if;
   end process;
   
   process (i_CLK_28)
   begin
      if rising_edge(i_CLK_28) then
         if reset = '1' then
            i2c_sda_o <= '1';
         elsif port_113b_wr = '1' then
            i2c_sda_o <= cpu_do(0);
         end if;
      end if;
   end process;
   
   -- read
   
   process (i_CLK_CPU)
   begin
      if falling_edge(i_CLK_CPU) then
         port_103b_dat <= "1111111" & (i_I2C_SCL_n and pi_i2c1_scl);
      end if;
   end process;

   process (i_CLK_CPU)
   begin
      if falling_edge(i_CLK_CPU) then
         port_113b_dat <= "1111111" & (i_I2C_SDA_n and pi_i2c1_sda);
      end if;
   end process;
   
   --
   -- SPI MASTER (MODE 0 : CPOL = 0, CPHA = 0)
   --
   
   -- read/write to SPI must be separated by 16 cycles (dma has wait to guarantee this)
   
   -- note: do not AND together miso sources
   
   spi_miso <= i_SPI_FLASH_MISO when spi_ss_flash_n = '0' else
               pi_spi0_miso     when spi_ss_rpi1_n = '0' or spi_ss_rpi0_n = '0' else
               i_SPI_SD_MISO    when spi_ss_sd1_n = '0' or spi_ss_sd0_n = '0' else '1';
   
   spi_master_mod: entity work.spi_master
   port map (
      clock_i        => i_CLK_CPU,
      reset_i        => reset_hard,
      
      spi_sck_o      => spi_sck,
      spi_mosi_o     => spi_mosi,
      spi_miso_i     => spi_miso,
      
      spi_mosi_wr_i  => port_eb_wr,
      spi_mosi_dat_i => cpu_do,
      
      spi_miso_rd_i  => port_eb_rd,
      spi_miso_dat_o => port_eb_dat,
      
      spi_wait_n_o   => spi_wait_n     -- wait signal for dma only
   );

   -- slave select register
   -- only one slave must be selected but esxdos may write garbage into bits other than 1:0
   
   -- bit 7 = fpga flash, bit 3 = rpi1, bit 2 = rpi0, bit 1 = sd1, bit 0 = sd0
   
   process (i_CLK_28)
   begin
      if rising_edge(i_CLK_28) then
         if reset = '1' then
            port_e7_reg <= (others => '1');
         elsif port_e7_wr = '1' then
            if cpu_do(1 downto 0) = "10" then
               port_e7_reg <= X"FE";
            elsif cpu_do(1 downto 0) = "01" then
               port_e7_reg <= X"FD";
            elsif cpu_do = X"FB" then
               port_e7_reg <= X"FB";
            elsif cpu_do = X"F7" then
               port_e7_reg <= X"F7";
            elsif cpu_do = X"7F" then
               port_e7_reg <= X"7F";
            else
               port_e7_reg <= (others => '1');
            end if;
         end if;
      end if;
   end process;

   spi_ss_flash_n <= port_e7_reg(7);
   spi_ss_rpi1_n <= port_e7_reg(3);
   spi_ss_rpi0_n <= port_e7_reg(2);
   spi_ss_sd1_n <= port_e7_reg(1);
   spi_ss_sd0_n <= port_e7_reg(0);
   
   --
   -- UART x 2 (wifi, pi)
   --
   
   -- todo: enforce minimum prescalar
   -- todo: add cts/rts
   
   -- multiplex uart with joystick connector

   uart0_rx <= io_mode_uart_rx when io_mode_uart_en = '1' and io_mode_bit_0 = '0' else i_UART0_RX;
   uart1_rx <= io_mode_uart_rx when io_mode_uart_en = '1' and io_mode_bit_0 = '1' else pi_uart_rx;
   
   uart0_tx_esp <= '1' when io_mode_uart_en = '1' and io_mode_bit_0 = '0' else uart0_tx;
   uart1_tx_pi <= '1' when io_mode_uart_en = '1' and io_mode_bit_0 = '1' else uart1_tx;

   -- uart 0 8/1/N
   
   uart0_mod: entity work.uart
   port map (
      clock_i              => i_CLK_28,
      reset_i              => reset_hard,
      
      uart_prescaler_i     => uart0_153b_prescalar_msb & uart0_143b_prescalar,
      
      TX_start_i           => port_133b_wr and not uart_153b_select,   -- 1 to start transmission
      TX_byte_i            => cpu_do,                             -- byte to transmit
      TX_active_o          => uart0_tx_busy,                      -- 1 during transmission
      TX_out_o             => uart0_tx,                           -- Tx
      TX_byte_finished_o   => open,                               -- when complete, 1 for one cycle
      
      RX_in_i              => uart0_rx,                           -- Rx
      RX_byte_finished_o   => uart0_rx_avail,                     -- when complete, 1 for one cycle
      RX_byte_o            => uart0_rx_byte                       -- incoming byte
   );

   fifop_uart0_rx: entity work.fifop
   generic map (
      DEPTH_BITS  => 9
   )
   port map (
      clock_i     => i_CLK_28,
      reset_i     => reset,
      
      empty_o     => uart0_fifo_empty,
      full_o      => uart0_fifo_full,
      
      rd_i        => port_143b_rd and not uart_153b_select,   -- read address adjusted on falling edge if not empty
      raddr_o     => uart0_fifo_raddr,
      
      wr_i        => uart0_fifo_we,                           -- write address adjusted on falling edge if not full
      waddr_o     => uart0_fifo_waddr
   );

   -- uart 1 8/1/N
   
   uart1_mod: entity work.uart
   port map (
      clock_i              => i_CLK_28,
      reset_i              => reset_hard,

      uart_prescaler_i     => uart1_153b_prescalar_msb & uart1_143b_prescalar,
      
      TX_start_i           => port_133b_wr and uart_153b_select,    -- 1 to start transmission
      TX_byte_i            => cpu_do,                          -- byte to transmit
      TX_active_o          => uart1_tx_busy,                   -- 1 during transmission
      TX_out_o             => uart1_tx,                        -- Tx
      TX_byte_finished_o   => open,                            -- when complete, 1 for one cycle
      
      RX_in_i              => uart1_rx,                        -- Rx
      RX_byte_finished_o   => uart1_rx_avail,                  -- when complete, 1 for one cycle
      RX_byte_o            => uart1_rx_byte                    -- incoming byte
   );

   fifop_uart1_rx: entity work.fifop
   generic map (
      DEPTH_BITS  => 9
   )
   port map (
      clock_i     => i_CLK_28,
      reset_i     => reset,
      
      empty_o     => uart1_fifo_empty,
      full_o      => uart1_fifo_full,
      
      rd_i        => port_143b_rd and uart_153b_select,    -- read address adjusted on falling edge if not empty
      raddr_o     => uart1_fifo_raddr,
      
      wr_i        => uart1_fifo_we,                        -- write address adjusted on falling edge if not full
      waddr_o     => uart1_fifo_waddr
   );
   
   -- settings & status
   
   process (i_CLK_28)
   begin
      if rising_edge(i_CLK_28) then
         if reset = '1' then
            uart_153b_select <= '0';
            if reset_hard = '1' then
               uart0_153b_prescalar_msb <= (others => '0');
               uart1_153b_prescalar_msb <= (others => '0');
            end if;
         elsif port_153b_wr = '1' then
            uart_153b_select <= cpu_do(6);
            if cpu_do(4) = '1' then
               if cpu_do(6) = '0' then
                  uart0_153b_prescalar_msb <= cpu_do(2 downto 0);
               else
                  uart1_153b_prescalar_msb <= cpu_do(2 downto 0);
               end if;
            end if;
         end if;
      end if;
   end process;
   
   port_153b_dat(7 downto 3) <= '0' & uart_153b_select & "000";
   port_153b_dat(2 downto 0) <= uart0_153b_prescalar_msb when uart_153b_select = '0' else uart1_153b_prescalar_msb;
   
   process (i_CLK_28)
   begin
      if rising_edge(i_CLK_28) then
         if reset_hard = '1' then
            uart0_143b_prescalar <= "00000011110011";   -- 115200 @ 28MHz system clock
         elsif port_143b_wr = '1' and uart_153b_select = '0' then
            if cpu_do(7) = '0' then
               uart0_143b_prescalar(6 downto 0) <= cpu_do(6 downto 0);
            else
               uart0_143b_prescalar(13 downto 7) <= cpu_do(6 downto 0);
            end if;
         end if;
      end if;
   end process;
   
   process (i_CLK_28)
   begin
      if rising_edge(i_CLK_28) then
         if reset_hard = '1' then
            uart1_143b_prescalar <= "00000011110011";   -- 115200 @ 28MHz system clock
         elsif port_143b_wr = '1' and uart_153b_select = '1' then
            if cpu_do(7) = '0' then
               uart1_143b_prescalar(6 downto 0) <= cpu_do(6 downto 0);
            else
               uart1_143b_prescalar(13 downto 7) <= cpu_do(6 downto 0);
            end if;
         end if;
      end if;
   end process;

   process (i_CLK_CPU)
   begin
      if falling_edge(i_CLK_CPU) then
         if uart_153b_select = '0' then
            port_133b_dat_20 <= uart0_fifo_full & uart0_tx_busy & not uart0_fifo_empty;
         else
            port_133b_dat_20 <= uart1_fifo_full & uart1_tx_busy & not uart1_fifo_empty;
         end if;
      end if;
   end process;
   
   port_133b_dat <= "00000" & port_133b_dat_20;
   
   -- fifo memory, share a single bram unit
   
	
   uart_fifo_rx: entity work.tdpram
   
   port map 
   (
	   clock  => i_CLK_28,
      -- uart 0
      wren_a    => uart0_fifo_we,
      address_a => '0' & uart0_fifo_addr,
      data_a    => uart0_rx_byte_dly,
      q_a       => uart0_rx_o,
      -- uart 1
      wren_b    => uart1_fifo_we,
      address_b => '1' & uart1_fifo_addr,
      data_b    => uart1_rx_byte_dly,
      q_b       => uart1_rx_o
   );

   -- cpu read has priority over uart write
   
   process (i_CLK_28)
   begin
      if rising_edge(i_CLK_28) then
         if reset = '1' then
            uart0_rx_avail_dly <= '0';
         elsif uart0_fifo_we = '1' then
            uart0_rx_avail_dly <= '0';
         elsif uart0_rx_avail = '1' then
            uart0_rx_avail_dly <= '1';
         end if;
      end if;
   end process;
   
   process (i_CLK_28)
   begin
      if rising_edge(i_CLK_28) then
         if uart0_rx_avail = '1' then
            uart0_rx_byte_dly <= uart0_rx_byte;
         end if;
      end if;
   end process;
   
   uart0_fifo_addr <= uart0_fifo_waddr when uart0_fifo_we = '1' else uart0_fifo_raddr;
   uart0_fifo_we <= uart0_rx_avail_dly and (not uart0_fifo_full) and (uart_153b_select or (not port_143b_rd));
   
   process (i_CLK_28)
   begin
      if rising_edge(i_CLK_28) then
         if reset = '1' then
            uart1_rx_avail_dly <= '0';
         elsif uart1_fifo_we = '1' then
            uart1_rx_avail_dly <= '0';
         elsif uart1_rx_avail = '1' then
            uart1_rx_avail_dly <= '1';
         end if;
      end if;
   end process;
   
   process (i_CLK_28)
   begin
      if rising_edge(i_CLK_28) then
         if uart1_rx_avail = '1' then
            uart1_rx_byte_dly <= uart1_rx_byte;
         end if;
      end if;
   end process;
   
   uart1_fifo_addr <= uart1_fifo_waddr when uart1_fifo_we = '1' else uart1_fifo_raddr;
   uart1_fifo_we <= uart1_rx_avail_dly and (not uart1_fifo_full) and ((not uart_153b_select) or (not port_143b_rd));

   process (i_CLK_CPU)
   begin
      if falling_edge(i_CLK_CPU) then
         if uart_153b_select = '0' then
            if uart0_fifo_empty = '1' then
               port_143b_dat <= (others => '0');
            else
               port_143b_dat <= uart0_rx_o;
            end if;
         else
            --if uart1_fifo_empty = '1' then
               port_143b_dat <= (others => '0');
            --else
             --  port_143b_dat <= uart1_rx_o;--rampa
            --end if;
         end if;
      end if;
   end process;
   
   ------------------------------------------------------------
   -- KEYBOARD, JOYSTICKS & MOUSE -----------------------------
   ------------------------------------------------------------
   
   -- Joystick modes:
   --
   -- 000 = Sinclair 2 (67890)
   -- 001 = Kempston 1 (port 0x1F)
   -- 010 = Cursor (56780)
   -- 011 = Sinclair 1 (12345)
   -- 100 = Kempston 2 (port 0x37)
   -- 101 = MD 1 (3 or 6 button joystick port 0x1F)
   -- 110 = MD 2 (3 or 6 button joystick port 0x37)
   -- 111 = Both joysticks in I/O Mode
   --
   -- Physical connector:
   --
   -- START, A, F2, F1, U, D, L, R
   --     7, 6,  5,  4, 3, 2, 1, 0

   -- keyboard and keyboard joysticks
   
   process (i_CLK_CPU)
   begin
      if falling_edge(i_CLK_CPU) then
         keyrow <= cpu_a(15 downto 8);
      end if;
   end process;
   
   -- todo: older tbblue mapped extra fire buttons to Q and W; should we do this?
   -- todo: user defined keys joystick (maybe makes previous point moot)
   
   joyL_up <= i_JOY_LEFT(6) or i_JOY_LEFT(3);
   joyR_up <= i_JOY_RIGHT(6) or i_JOY_RIGHT(3);

   joyL_sinc1 <= not(i_JOY_LEFT(1) & i_JOY_LEFT(0) & i_JOY_LEFT(2) & joyL_up & i_JOY_LEFT(4)) when keyrow(4) = '0' and nr_05_joy0 = "011" else (others => '1');
   joyL_sinc2 <= not(i_JOY_LEFT(4) & joyL_up & i_JOY_LEFT(2) & i_JOY_LEFT(0) & i_JOY_LEFT(1)) when keyrow(3) = '0' and nr_05_joy0 = "000" else (others => '1');
   joyL_cursA <= (not i_JOY_LEFT(1)) & "1111" when keyrow(3) = '0' and nr_05_joy0 = "010" else (others => '1');
   joyL_cursB <= not(i_JOY_LEFT(2) & joyL_up & i_JOY_LEFT(0) & '0' & i_JOY_LEFT(4)) when keyrow(4) = '0' and nr_05_joy0 = "010" else (others => '1');

   joyR_sinc1 <= not(i_JOY_RIGHT(1) & i_JOY_RIGHT(0) & i_JOY_RIGHT(2) & joyR_up & i_JOY_RIGHT(4)) when keyrow(4) = '0' and nr_05_joy1 = "011" else (others => '1');
   joyR_sinc2 <= not(i_JOY_RIGHT(4) & joyR_up & i_JOY_RIGHT(2) & i_JOY_RIGHT(0) & i_JOY_RIGHT(1)) when keyrow(3) = '0' and nr_05_joy1 = "000" else (others => '1');
   joyR_cursA <= (not i_JOY_RIGHT(1)) & "1111" when keyrow(3) = '0' and nr_05_joy1 = "010" else (others => '1');
   joyR_cursB <= not(i_JOY_RIGHT(2) & joyR_up & i_JOY_RIGHT(0) & '0' & i_JOY_RIGHT(4)) when keyrow(4) = '0' and nr_05_joy1 = "010" else (others => '1');   
   
   joy_key <= (joyL_sinc1 and joyL_sinc2 and joyL_cursA and joyL_cursB and joyR_sinc1 and joyR_sinc2 and joyR_cursA and joyR_cursB) when io_mode_en = '0' else (others => '1');

   port_fe_bus <= i_BUS_DI when expbus_eff_en = '1' and port_propagate_fe = '1' else X"FF";

   process (i_CLK_CPU)
   begin
      if falling_edge(i_CLK_CPU) then
         if port_fe_override = '0' or expbus_eff_en = '0' or port_propagate_fe = '0' then
            port_fe_dat_0 <= '1' & ((not i_AUDIO_EAR) xor pi_fe_ear xor (port_fe_ear or (port_fe_mic and nr_08_keyboard_issue2))) & '1' & (i_KBD_COL and joy_key);
         else
            port_fe_dat_0 <= X"FF";
         end if;
      end if;
   end process;

   -- legacy external peripherals are slow so we have to allow reading until the last moment

   port_fe_dat <= port_fe_dat_0 and port_fe_bus;

   -- other joysticks
   
   mdL_1f_en <= '1' when nr_05_joy0 = "101" else '0';
   mdL_37_en <= '1' when nr_05_joy0 = "110" else '0';
   
   joyL_1f_en <= '1' when nr_05_joy0 = "001" or mdL_1f_en = '1' or io_mode_en = '1' else '0';
   joyL_37_en <= '1' when (nr_05_joy0 = "100" or mdL_37_en = '1') and io_mode_en = '0' else '0';
   
   joyL_1f(7 downto 6) <= i_JOY_LEFT(7 downto 6) when mdL_1f_en = '1' else (others => '0');
   joyL_1f(5 downto 0) <= (i_JOY_LEFT(5 downto 4) & (i_JOY_LEFT(3) or (i_JOY_LEFT(6) and not mdL_1f_en)) & i_JOY_LEFT(2 downto 0)) when joyL_1f_en = '1' else (others => '0');

   joyL_37(7 downto 6) <= i_JOY_LEFT(7 downto 6) when mdL_37_en = '1' else (others => '0');
   joyL_37(5 downto 0) <= (i_JOY_LEFT(5 downto 4) & (i_JOY_LEFT(3) or (i_JOY_LEFT(6) and not mdL_37_en)) & i_JOY_LEFT(2 downto 0)) when joyL_37_en = '1' else (others => '0');

   mdR_1f_en <= '1' when nr_05_joy1 = "101" else '0';
   mdR_37_en <= '1' when nr_05_joy1 = "110" else '0';
   
   joyR_1f_en <= '1' when (nr_05_joy1 = "001" or mdR_1f_en = '1') and io_mode_en = '0' else '0';
   joyR_37_en <= '1' when nr_05_joy1 = "100" or mdR_37_en = '1' or io_mode_en = '1' else '0';
   
   joyR_1f(7 downto 6) <= i_JOY_RIGHT(7 downto 6) when mdR_1f_en = '1' else (others => '0');
   joyR_1f(5 downto 0) <= (i_JOY_RIGHT(5 downto 4) & (i_JOY_RIGHT(3) or (i_JOY_RIGHT(6) and not mdR_1f_en)) & i_JOY_RIGHT(2 downto 0)) when joyR_1f_en = '1' else (others => '0');
   
   joyR_37(7 downto 6) <= i_JOY_RIGHT(7 downto 6) when mdR_37_en = '1' else (others => '0');
   joyR_37(5 downto 0) <= (i_JOY_RIGHT(5 downto 4) & (i_JOY_RIGHT(3) or (i_JOY_RIGHT(6) and not mdR_37_en)) & i_JOY_RIGHT(2 downto 0)) when joyR_37_en = '1' else (others => '0');
   
   process (i_CLK_CPU)
   begin
      if falling_edge(i_CLK_CPU) then
         port_1f_dat <= joyL_1f or joyR_1f;
      end if;
   end process;
   
   process (i_CLK_CPU)
   begin
      if falling_edge(i_CLK_CPU) then
         port_37_dat <= joyL_37 or joyR_37;
      end if;
   end process;
   
   -- port 0x37 joystick control io mode

   process (i_CLK_28)
   begin
      if rising_edge(i_CLK_28) then
         if reset = '1' then
            io_mode <= "00";
            io_mode_bit_0 <= '1';
         elsif port_37_wr = '1' then
            io_mode <= cpu_do(7 downto 6);
            io_mode_lr <= cpu_do(4);
            io_mode_bit_0 <= cpu_do(0);
         end if;
      end if;
   end process;

   io_mode_uart_en <= '1' when io_mode_en = '1' and io_mode = "10" else '0';
   io_mode_uart_rx <= not i_JOY_LEFT(5);
   io_mode_uart_tx <= uart0_tx when io_mode_bit_0 = '0' else uart1_tx;
   
   io_mode_pin_7 <= io_mode_uart_tx when io_mode_uart_en = '1' else io_mode_bit_0;
   
   -- mouse
   
   process (i_CLK_CPU)
   begin
      if falling_edge(i_CLK_CPU) then
         port_fbdf_dat <= i_MOUSE_X;
      end if;
   end process;
   
   process (i_CLK_CPU)
   begin
      if falling_edge(i_CLK_CPU) then
         port_ffdf_dat <= i_MOUSE_Y;
      end if;
   end process;
   
   process (i_CLK_CPU)
   begin
      if falling_edge(i_CLK_CPU) then
         port_fadf_dat <= i_MOUSE_WHEEL & '1' & (not i_MOUSE_BUTTON(2)) & (not i_MOUSE_BUTTON(0)) & (not i_MOUSE_BUTTON(1));
      end if;
   end process;

   ------------------------------------------------------------
   -- DEVICES -------------------------------------------------
   ------------------------------------------------------------

   -- FE, FF : ULA/SCLD
   -- 7FFD, DFFD, 1FFD : 128K MEMORY PAGING
   -- 123B : LAYER 2 CONTROL
   -- COPPER
   -- CTC
   -- DIVMMC
   -- LAYER 2
   -- LORES
   -- MULTIFACE
   -- SPRITES
   -- TILEMAP
   -- ULA
   -- ULA+

   --
   -- PORTS FE (ULA) & FF (TIMEX SCLD)
   --
   
   process (i_CLK_28)
   begin
      if rising_edge(i_CLK_28) then
         if reset = '1' then
            port_fe_reg <= (others => '0');
         elsif port_fe_wr = '1' and bus_iorq_ula = '0' then
            port_fe_reg <= cpu_do(4 downto 0);
         end if;
      end if;
   end process;
   
   port_fe_ear <= port_fe_reg(4);
   port_fe_mic <= port_fe_reg(3);
   
   process (i_CLK_CPU)
   begin
      if falling_edge(i_CLK_CPU) then
         port_fe_border <= port_fe_reg(2 downto 0);
      end if;
   end process;

   -- port fe is read in KEYBOARD & JOYSTICK section

   process (i_CLK_28)
   begin
      if rising_edge(i_CLK_28) then
         if reset = '1' then
            port_ff_reg <= (others => '0');
         elsif port_ff_wr = '1' then
            port_ff_reg <= cpu_do;
         elsif nr_69_we = '1' then
            port_ff_reg(5 downto 0) <= nr_wr_dat(5 downto 0);
         elsif nr_22_we = '1' then
            port_ff_reg(6) <= nr_wr_dat(2);
         end if;
      end if;
   end process;

   process (i_CLK_CPU)
   begin
      if falling_edge(i_CLK_CPU) then
         port_ff_dat_tmx <= port_ff_reg;
      end if;
   end process;

   port_ff_screen_mode <= port_ff_dat_tmx(5 downto 0);
   port_ff_interrupt_disable <= port_ff_reg(6);
   
   -- port ff is read through ula

   --
   -- 128K MEMORY PAGING
   --
   
   process (i_CLK_28)
   begin
      if rising_edge(i_CLK_28) then
         if reset = '1' then
         
            port_7ffd_reg <= (others => '0');
            
         elsif port_7ffd_wr = '1' and port_7ffd_locked = '0' then
         
            port_7ffd_reg <= cpu_do;
            
         elsif nr_08_we = '1' and nr_wr_dat(7) = '1' then
         
            port_7ffd_reg(5) <= '0';
            
         elsif nr_69_we = '1' then
         
            port_7ffd_reg(3) <= nr_wr_dat(6);
            
         elsif nr_8e_we = '1' then
         
            if nr_wr_dat(3) = '1' then
               port_7ffd_reg(2 downto 0) <= nr_wr_dat(6 downto 4);
            end if;
            
            if nr_wr_dat(2) = '0' then
               port_7ffd_reg(4) <= nr_wr_dat(0);
            end if;
            
         end if;
      end if;
   end process;
   
   process (i_CLK_CPU)
   begin
      if falling_edge(i_CLK_CPU) then
         port_7ffd_dat <= port_7ffd_reg;
      end if;
   end process;
   
   process (i_CLK_28)
   begin
      if rising_edge(i_CLK_28) then
         if reset = '1' then
         
            port_dffd_reg <= (others => '0');
            port_dffd_reg_6 <= '0';
            
         elsif port_dffd_wr = '1' and (port_7ffd_locked = '0' or nr_8f_mapping_mode_profi = '1') then
         
            port_dffd_reg <= cpu_do(4 downto 0);
            port_dffd_reg_6 <= cpu_do(6);
            
         elsif nr_8e_we = '1' then
         
            if nr_8f_mapping_mode_profi = '0' and nr_wr_dat(3) = '1' then
               port_dffd_reg(3) <= '0';
            end if;
            
            if nr_wr_dat(3) = '1' then
               port_dffd_reg(2 downto 0) <= "00" & nr_wr_dat(7);
            end if;
        
         end if;
      end if;
   end process;

   process (i_CLK_28)
   begin
      if rising_edge(i_CLK_28) then
         if reset = '1' then
         
            port_1ffd_reg <= (others => '0');
            port_1ffd_special_old <= '0';
            
         elsif port_1ffd_wr = '1' and port_7ffd_locked = '0' then

            if port_memory_change_dly = '0' then
               port_1ffd_special_old <= port_1ffd_special;
            end if;
            
            port_1ffd_reg <= cpu_do;
         
         elsif nr_8e_we = '1' then
            
            if port_memory_change_dly = '0' then
               port_1ffd_special_old <= port_1ffd_special;
            end if;
            
            port_1ffd_reg(2) <= nr_wr_dat(1);
            port_1ffd_reg(1) <= nr_wr_dat(0);
            port_1ffd_reg(0) <= nr_wr_dat(2);
            
         else
         
            port_1ffd_special_old <= '0';
         
         end if;
      end if;
   end process;
   
   port_1ffd_dat <= port_1ffd_reg;

   port_7ffd_bank(2 downto 0) <= port_7ffd_reg(2 downto 0);
   port_7ffd_bank(4 downto 3) <= port_7ffd_reg(7 downto 6) when nr_8f_mapping_mode_pentagon = '1' else port_dffd_reg(1 downto 0);
   port_7ffd_bank(5) <= port_dffd_reg(2) when nr_8f_mapping_mode_pentagon = '0' else (nr_8f_mapping_mode_pentagon_1024_en and port_7ffd_reg(5));
   port_7ffd_bank(6) <= '0' when nr_8f_mapping_mode_pentagon = '1' or nr_8f_mapping_mode_profi = '1' else port_dffd_reg(3);
   
   port_7ffd_shadow <= port_7ffd_dat(3);
   port_7ffd_locked <= '0' when (nr_8f_mapping_mode_pentagon_1024_en = '1') or (nr_8f_mapping_mode_profi = '1' and port_dffd_reg(4) = '1') else port_7ffd_reg(5);
   
   port_1ffd_special <= port_1ffd_reg(0);
   port_1ffd_rom <= port_1ffd_reg(2) & port_7ffd_reg(4);
   
   process (i_CLK_28)
   begin
      if rising_edge(i_CLK_28) then
         if reset = '1' then
            port_eff7_reg_2 <= '0';
            port_eff7_reg_3 <= '0';
         elsif port_eff7_wr = '1' then
            port_eff7_reg_2 <= cpu_do(2);
            port_eff7_reg_3 <= cpu_do(3);
         end if;
      end if;
   end process;

   process (i_CLK_28)
   begin
      if rising_edge(i_CLK_28) then
         if reset_hard = '1' then
            nr_8f_mapping_mode <= "00";
         elsif nr_8f_we = '1' then
            nr_8f_mapping_mode <= nr_wr_dat(1 downto 0);
         end if;
      end if;
   end process;
   
   nr_8f_mapping_mode_profi <= '1' when nr_8f_mapping_mode = "01" else '0';
   nr_8f_mapping_mode_pentagon <= '1' when nr_8f_mapping_mode = "10" or nr_8f_mapping_mode_pentagon_1024_en = '1' else '0';
   nr_8f_mapping_mode_pentagon_1024 <= '1' when nr_8f_mapping_mode = "11" else '0';
   
   nr_8f_mapping_mode_pentagon_1024_en <= '1' when nr_8f_mapping_mode_pentagon_1024 = '1' and port_eff7_reg_2 = '0' else '0';
   
   -- communicate paging changes to mmu

   process (i_CLK_28)
   begin
      if rising_edge(i_CLK_28) then
         if reset = '1' then
            port_memory_change_dly <= '0';
            port_memory_ram_change_dly <= '0';
            nr_8f_we_dly <= '0';
         else
            port_memory_change_dly <= ((port_7ffd_wr or port_1ffd_wr) and not port_7ffd_locked) or (port_dffd_wr and (nr_8f_mapping_mode_profi or not port_7ffd_locked)) or port_eff7_wr or nr_8e_we or nr_8f_we_dly;
            port_memory_ram_change_dly <= not (nr_8e_we and not nr_wr_dat(3));
            nr_8f_we_dly <= nr_8f_we;
         end if;
      end if;
   end process;
   
   --
   -- PORT 123B LAYER 2 CONTROL
   --
   
   process (i_CLK_28)
   begin
      if rising_edge(i_CLK_28) then
         if reset = '1' then
            port_123b_layer2_en <= '0';
            port_123b_layer2_map_wr_en <= '0';
            port_123b_layer2_map_rd_en <= '0';
            port_123b_layer2_map_shadow <= '0';
            port_123b_layer2_map_segment <= (others => '0');
            port_123b_layer2_offset <= (others => '0');
         elsif port_123b_wr = '1' then
            if cpu_do(4) = '0' then
               port_123b_layer2_en <= cpu_do(1);
               port_123b_layer2_map_wr_en <= cpu_do(0);
               port_123b_layer2_map_rd_en <= cpu_do(2);
               port_123b_layer2_map_shadow <= cpu_do(3);
               port_123b_layer2_map_segment <= cpu_do(7 downto 6);
            else
               port_123b_layer2_offset <= cpu_do(2 downto 0);
            end if;
         elsif nr_69_we = '1' then
            port_123b_layer2_en <= nr_wr_dat(7);
         end if;
      end if;
   end process;
   
   process (i_CLK_CPU)
   begin
      if falling_edge(i_CLK_CPU) then
         port_123b_dat <= port_123b_layer2_map_segment & "00" & port_123b_layer2_map_shadow & port_123b_layer2_map_rd_en & port_123b_layer2_en & port_123b_layer2_map_wr_en;
      end if;
   end process;

   --
   -- COPPER
   -- simple co-processor synchronized with display generation
   --
   
   copper_mod: entity work.copper
   port map (
      clock_i              => i_CLK_28,
      reset_i              => reset,
      
      copper_en_i          => nr_62_copper_mode,
      
      hcount_i             => hc,
      vcount_i             => cvc,
      
      copper_list_addr_o   => copper_instr_addr,
      copper_list_data_i   => copper_instr_data,
      
      copper_dout_o        => copper_dout_en,
      copper_data_o        => copper_dout
   );
   
   copper_inst_msb_ram: entity work.dpram2
   generic map (
      addr_width_g => 10,
      data_width_g => 8
   )
   port map (
      -- CPU port
      clk_a_i  => i_CLK_28,
      we_i     => copper_msb_we,
      addr_a_i => nr_copper_addr(10 downto 1),
      data_a_i => copper_msb_dat,
      data_a_o => open,
      -- Copper Instructions
      clk_b_i  => i_CLK_28_n,
      addr_b_i => copper_instr_addr,
      data_b_o => copper_instr_data(15 downto 8)
   );

   copper_msb_we <= '1' when nr_copper_we = '1' and ((nr_copper_write_8 = '0' and nr_copper_addr(0) = '1') or (nr_copper_write_8 = '1' and nr_copper_addr(0) = '0')) else '0';
   copper_msb_dat <= nr_wr_dat when nr_copper_write_8 = '1' else nr_copper_data_stored;
   
   copper_inst_lsb_ram: entity work.dpram2
   generic map (
      addr_width_g => 10,
      data_width_g => 8
   )
   port map (
      -- CPU port
      clk_a_i  => i_CLK_28,
      we_i     => copper_lsb_we,
      addr_a_i => nr_copper_addr(10 downto 1),
      data_a_i => copper_lsb_dat,
      data_a_o => open,
      -- Copper Instructions
      clk_b_i  => i_CLK_28_n,
      addr_b_i => copper_instr_addr,
      data_b_o => copper_instr_data(7 downto 0)
   );

   copper_lsb_we <= '1' when nr_copper_we = '1' and nr_copper_addr(0) = '1' else '0';
   copper_lsb_dat <= nr_wr_dat;

   --
   -- CTC (COUNTER / TIMER CIRCUIT)
   --

   ctc_mod: entity work.ctc
   port map
   (
      i_CLK          => i_CLK_28,
      i_reset        => reset,
      
      i_port_ctc_wr  => port_ctc_wr,
      i_port_ctc_sel => cpu_a(10 downto 8),

      i_int_en_wr    => nr_c6_we,
      i_int_en       => nr_wr_dat,

      i_cpu_d        => cpu_do,
      o_cpu_d        => ctc_do,
      
      i_clk_trg      => ctc_zc_to(6 downto 0) & ctc_zc_to(7),
      
      o_im2_vector_wr  => open,
      
      o_zc_to        => ctc_zc_to,
      o_int_en       => ctc_int_en
   );
   
   process (i_CLK_CPU)
   begin
      if falling_edge(i_CLK_CPU) then
         port_ctc_dat <= ctc_do;
      end if;
   end process;
   
   ctc_int <= ctc_int_en and ctc_zc_to;
   ctc_int_n <= (not port_ctc_io_en) or not (ctc_int(7) or ctc_int(6) or ctc_int(5) or ctc_int(4) or ctc_int(3) or ctc_int(2) or ctc_int(1) or ctc_int(0));
   
   --
   -- DIVMMC
   --
   
   -- divmmc normally includes an spi interface to the sd card but on the next
   -- the spi interface is implemented separately

   -- todo: add sets of automap entry points for trapping different systems
   
   divmmc_mod: entity work.divmmc
   port map
   (
      reset_i              => reset,
      clock_i              => i_CLK_28,
      
      enable_i             => port_divmmc_io_en,
      
      cpu_a_15_13_i        => cpu_a(15 downto 13),
      cpu_mreq_n_i         => cpu_mreq_n,
      cpu_m1_n_i           => cpu_m1_n,
      
      divmmc_button_i      => nmi_divmmc_button,
      
      reset_automap_i      => not nr_06_divmmc_automap_en,
      hide_automap_i       => sram_disable_divmmc_automap,
      obscure_automap_i    => sram_obscure_divmmc_automap,
      
      automap_en_instant_i             => divmmc_automap_en_instant,
      automap_en_delayed_i             => divmmc_automap_en_delayed,
      automap_en_delayed_nohide_i      => divmmc_automap_en_delayed_nohide,
      automap_en_delayed_nohide_nmi_i  => divmmc_automap_en_delayed_nohide_nmi,
      automap_dis_delayed_i            => divmmc_automap_dis_delayed,

      disable_nmi_o        => divmmc_nmi_hold,
      automap_held_o       => divmmc_automap_held,
      
      divmmc_reg_i         => port_e3_reg,
      
      divmmc_rom_en_o      => divmmc_rom_en,     -- 1 if divmmc rom is active
      divmmc_ram_en_o      => divmmc_ram_en,     -- 1 if divmmc ram bank is active
      divmmc_rdonly_o      => divmmc_rdonly,     -- 1 if active divmmc is read only
      divmmc_ram_bank_o    => divmmc_bank        -- active divmmc ram bank
   );
   
   process (i_CLK_28)
   begin
      if rising_edge(i_CLK_28) then
         if reset = '1' then
            port_e3_reg <= (others => '0');
         elsif port_e3_wr = '1' then
            port_e3_reg(7) <= cpu_do(7);
            port_e3_reg(6) <= cpu_do(6) or port_e3_reg(6);
            port_e3_reg(5 downto 0) <= cpu_do(5 downto 0);
         elsif nr_09_we = '1' and nr_wr_dat(3) = '1' then
            port_e3_reg(6) <= '0';
         end if;
      end if;
   end process;
   
   port_e3_dat <= port_e3_reg;
   
   --
   -- LAYER 2
   -- 256x192x8, 320x256x8, 640x256x4 in external sram
   --
   
   layer2_mod: entity work.layer2
   port map
   (
      i_CLK_7              => i_CLK_7,
      i_CLK_28             => i_CLK_28,
      
      i_sc                 => sc,
      
      i_phc                => std_logic_vector(phc),
      i_pvc                => std_logic_vector(vc),
      
      i_whc                => std_logic_vector(whc),
      i_wvc                => std_logic_vector(wvc),
      
      i_layer2_en          => port_123b_layer2_en,
      i_resolution         => nr_70_layer2_resolution,
      i_palette_offset     => nr_70_layer2_palette_offset,
      
      i_scroll_x           => nr_71_layer2_scrollx_msb & nr_16_layer2_scrollx,
      i_scroll_y           => nr_17_layer2_scrolly,
      
      i_clip_x1            => nr_18_layer2_clip_x1,
      i_clip_x2            => nr_18_layer2_clip_x2,
      i_clip_y1            => nr_18_layer2_clip_y1,
      i_clip_y2            => nr_18_layer2_clip_y2,
      
      i_layer2_active_bank => nr_12_layer2_active_bank,
      
      o_layer2_sram_addr   => layer2_addr_eff,
      o_layer2_req_t       => layer2_req_t,
      i_layer2_sram_di     => i_RAM_B_DI,
      
      o_layer2_en          => layer2_pixel_en,
      o_layer2_pixel       => layer2_pixel
   );

-- o_RAM_B_ADDR <= layer2_addr_eff;
-- o_RAM_B_REQ_T <= layer2_req_t;

   --
   -- LORES
   -- 128 x 96 4-bit or 8-bit pixels in bank 5
   --

   lores_mod: entity work.lores
   port map
   (
      mode_i            => lores_mode_0,   -- 0 = lores, 1 = radastan
      dfile_i           => lores_dfile_0,  -- timex display file to use for radastan
      ulap_en_i         => ulap_en_0 and not ulanext_en_0,  -- translate radastan pixel to ula+ palette
      
      lores_palette_offset_i  => lores_palette_offset_0,
      
      hc_i              => std_logic_vector(phc),   -- current x coordinate
      vc_i              => std_logic_vector(vc),    -- current y coordinate

--    clip_x1_i         => lores_clip_x1_0,
--    clip_x2_i         => lores_clip_x2_0,
--    clip_y1_i         => lores_clip_y1_0,
--    clip_y2_i         => lores_clip_y2_0,
   
      clip_x1_i         => ula_clip_x1_0,
      clip_x2_i         => ula_clip_x2_0,
      clip_y1_i         => ula_clip_y1_0,
      clip_y2_i         => ula_clip_y2_0,

      scroll_x_i        => lores_scroll_x_0,
      scroll_y_i        => lores_scroll_y_0,

      lores_addr_o      => lores_addr,     -- bank 5 address
      lores_data_i      => lores_vram_di,  -- read from bank 5
      
      lores_pixel_o     => lores_pixel,
      lores_pixel_en_o  => lores_pixel_en  -- valid unclipped pixel
   );

   --
   -- MULTIFACE
   --

   multiface_mod: entity work.multiface
   port map
   (
      reset_i              => reset,
      clock_i              => i_CLK_28,
      
      cpu_a_0066_i         => mf_a_0066,
      cpu_a_1fxx_i         => mf_a_1fxx,
      cpu_a_7fxx_i         => mf_a_7fxx,
      cpu_a_fexx_i         => mf_a_fexx,
      
      cpu_mreq_n_i         => cpu_mreq_n,
      cpu_m1_n_i           => cpu_m1_n,
      
      port_1ffd_i          => port_1ffd_dat,
      port_7ffd_i          => port_7ffd_dat,
      port_fe_border_i     => port_fe_border,
      
      enable_i             => port_multiface_io_en,
      button_i             => nmi_mf_button,

      mf_mode_i            => nr_0a_mf_type,
      
      port_mf_enable_rd_i  => port_mf_enable_rd,
      port_mf_enable_wr_i  => port_mf_enable_wr,
      port_mf_disable_rd_i => port_mf_disable_rd,
      port_mf_disable_wr_i => port_mf_disable_wr,
      
      nmi_disable_o        => mf_nmi_hold,
      mf_enabled_o         => mf_mem_en,
      
      mf_port_en_o         => mf_port_en,
      mf_port_dat_o        => mf_port_dat
   );
   
   mf_is_active <= mf_mem_en or mf_nmi_hold;
   
   --
   -- SPRITES
   --

   sprite_mod: entity work.sprites
   port map (
      clock_master_i       => i_CLK_28,
      clock_master_180o_i  => i_CLK_28_n,
      clock_pixel_i        => i_CLK_7,
      reset_i              => reset,
      zero_on_top_i        => nr_15_sprite_priority,
      border_clip_en_i     => nr_15_sprite_border_clip_en,
      over_border_i        => nr_15_sprite_over_border_en,
      hcounter_i           => whc,
      vcounter_i           => wvc,
      transp_colour_i      => nr_4b_sprite_transparent_index,

      -- CPU
         
      port57_w_en_s     => port_57_wr,
      port5B_w_en_s     => port_5b_wr,
      port303b_r_en_s   => port_303b_rd,
      port303b_w_en_s   => port_303b_wr,
      cpu_d_i           => cpu_do,
      cpu_d_o           => port_303b_dat,
         
      -- NEXTREG Mirror
         
      mirror_tie_i      => nr_09_sprite_tie,  -- 1 = nextreg and io port are tied
      mirror_we_i       => nr_sprite_mirror_we,
      mirror_index_i    => nr_sprite_mirror_index,
      mirror_data_i     => nr_wr_dat,
      mirror_inc_i      => nr_sprite_mirror_inc,
      mirror_num_o      => sprite_mirror_id,
         
      -- Video out
         
      rgb_o             => sprite_pixel,
      pixel_en_o        => sprite_pixel_en,
      
      -- clip window
         
      clip_x1_i         => unsigned(nr_19_sprite_clip_x1),
      clip_x2_i         => unsigned(nr_19_sprite_clip_x2),
      clip_y1_i         => unsigned(nr_19_sprite_clip_y1),
      clip_y2_i         => unsigned(nr_19_sprite_clip_y2)
   );

   --
   -- TILEMAP
   -- tilemap display
   --
   
   tilemap_mod: entity work.tilemap
   port map (
      reset_i              => reset,
      
      clock_master_i       => i_CLK_28,
      clock_master_180o_i  => i_CLK_28_n,
      
      hcounter_i           => whc,
      vcounter_i           => wvc,
      subpixel_i           => sc,
      
      control_i            => nr_6b_tm_control,
      default_flags_i      => nr_6c_tm_default_attr,
      transp_colour_i      => nr_4c_tm_transparent_index,
      
      -- ULA Bank 5 Memory Interface
      
      tm_mem_bank7_o       => tm_mem_bank7,
      tm_mem_addr_o        => tm_vram_a,
      tm_mem_rd_o          => tm_vram_rd,
      tm_mem_ack_i         => tm_vram_ack,
      tm_mem_data_i        => tm_vram_di,
   
      -- Memory Map
      
      tm_map_base_i        => nr_6e_tilemap_base_7 & nr_6e_tilemap_base,
      tm_tile_base_i       => nr_6f_tilemap_tiles_7 & nr_6f_tilemap_tiles,
      
      -- Out
      
      pixel_o              => tm_pixel,
      pixel_en_o           => tm_pixel_en,
      pixel_below_o        => tm_pixel_below,
      pixel_textmode_o     => tm_pixel_textmode,
      
      -- Scroll

      tm_scroll_x_i        => nr_30_tm_scrollx,
      tm_scroll_y_i        => nr_31_tm_scrolly,
      
      -- Clip Window
      
      clip_x1_i            => unsigned(nr_1b_tm_clip_x1),
      clip_x2_i            => unsigned(nr_1b_tm_clip_x2),
      clip_y1_i            => unsigned(nr_1b_tm_clip_y1),
      clip_y2_i            => unsigned(nr_1b_tm_clip_y2)
   );

   --
   -- ULA
   -- cpu contention, zx spectrum screen, timex video modes, floating bus
   --

   ula_mod: entity work.zxula
   port map (
      i_CLK_7                 => i_CLK_7,
      i_CLK_14                => i_CLK_14,
      i_CLK_CPU               => i_CLK_CPU,
      
      i_cpu_mreq_n            => cpu_mreq_n,
      i_cpu_iorq_n            => cpu_iorq_n,
      
      i_hc                    => std_logic_vector(hc),
      i_vc                    => std_logic_vector(vc),
      i_phc                   => std_logic_vector(phc),
      
      i_timing_pentagon       => machine_timing_pentagon,
      i_timing_p3             => machine_timing_p3,
   
      i_port_ff_reg           => port_ff_screen_mode,
      i_port_fe_border        => port_fe_border,
      i_ula_shadow_en         => port_7ffd_shadow,
      
      i_ulanext_en            => ulanext_en_0,
      i_ulanext_format        => ulanext_format_0,
      i_ulap_en               => ulap_en_0,
      
      o_ula_vram_a            => ula_vram_a,
      o_ula_shadow            => ula_vram_shadow,
      o_ula_vram_rd           => ula_vram_rd,
      i_ula_vram_d            => ula_vram_di,
      
      o_ula_border            => ula_border,
      o_ula_pixel             => ula_pixel,
      o_ula_select_bgnd       => ula_select_bgnd,
      o_ula_clipped           => ula_clipped,
      
      i_ula_clip_x1           => ula_clip_x1_0,
      i_ula_clip_x2           => ula_clip_x2_0,
      i_ula_clip_y1           => ula_clip_y1_0,
      i_ula_clip_y2           => ula_clip_y2_0,
      
      i_ula_scroll_x          => nr_26_ula_scrollx,
      i_ula_scroll_y          => nr_27_ula_scrolly,
      i_ula_fine_scroll_x     => nr_68_ula_fine_scroll_x,
      
      i_p3_floating_bus       => p3_floating_bus_dat,
      o_ula_floating_bus      => ula_floating_bus,
      
      i_contention_en         => (not eff_nr_08_contention_disable) and (not machine_timing_pentagon) and (not cpu_speed(1)) and (not cpu_speed(0)),
      i_contention_port       => port_contend,
      i_contention_memory     => mem_contend,
      
      o_cpu_wait_n            => ula_wait_n,
      o_cpu_contend           => ula_cpu_contend
   );

   mem_contend <= '0' when mem_active_page(7 downto 4) /= "0000" else  -- contention can only occur in 16k banks 0-7
                  '1' when machine_timing_48  = '1' and mem_active_page(3 downto 1) = "101" else   -- bank 5 only
                  '1' when machine_timing_128 = '1' and mem_active_page(1) = '1' else              -- odd banks
                  '1' when machine_timing_p3  = '1' and mem_active_page(3) = '1' else              -- banks >= 4
                  '0';
   
-- port_contend <= (not cpu_a(0)) or port_7ffd_active or port_1ffd_active or port_p3_float_active or port_bf3b or port_ff3b;
   port_contend <= (not cpu_a(0)) or port_7ffd_active or port_bf3b or port_ff3b;

   process (i_CLK_CPU)
   begin
      if rising_edge(i_CLK_CPU) then
         if mem_contend = '1' and cpu_mreq_n = '0' then
            if cpu_rd_n = '0' then
               p3_floating_bus_dat <= cpu_di;
            elsif cpu_wr_n = '0' then
               p3_floating_bus_dat <= cpu_do;
            end if;
         end if;
      end if;
   end process;

   -- floating bus read through port ff

   port_ff_dat_ula <= ula_floating_bus when (machine_timing_48 = '1' or machine_timing_128 = '1') else X"FF";
   
   -- +3 floating bus
   
   port_p3_floating_bus_dat <= ula_floating_bus when port_7ffd_locked = '0' else X"FF";
   
   --
   -- ULA+
   --
   
   -- port bf3b
   
   process (i_CLK_28)
   begin
      if rising_edge(i_CLK_28) then
         if reset = '1' then
            port_bf3b_ulap_mode <= (others => '0');
            port_bf3b_ulap_index <= (others => '0');
         elsif port_bf3b_wr = '1' then
            port_bf3b_ulap_mode <= cpu_do(7 downto 6);
            if cpu_do(7 downto 6) = "00" then
               port_bf3b_ulap_index <= cpu_do(5 downto 0);
            end if;
         end if;
      end if;
   end process;
   
   -- port ff3b write
   -- mode group 00 palette writes handled by nextreg stream
   
   process (i_CLK_28)
   begin
      if rising_edge(i_CLK_28) then
         if reset = '1' then
            port_ff3b_ulap_en <= '0';
         elsif port_ff3b_wr = '1' and port_bf3b_ulap_mode = "01" then
            port_ff3b_ulap_en <= cpu_do(0);
         elsif nr_68_we = '1' then
            port_ff3b_ulap_en <= nr_wr_dat(3);
         end if;
      end if;
   end process;
   
   -- port ff3b read
   
   process (i_CLK_28)
   begin
      if falling_edge(i_CLK_28) then
         if port_bf3b_ulap_mode = "00" then
            if ulap_palette_rd_dly = '1' then
               port_ff3b_dat <= nr_ulatm_palette_dat(5 downto 3) & nr_ulatm_palette_dat(8 downto 6) & nr_ulatm_palette_dat(2 downto 1);
            end if;
         else
            port_ff3b_dat <= "0000000" & port_ff3b_ulap_en;
         end if;
      end if;
   end process;
   
   ulap_palette_rd <= '1' when port_ff3b_rd = '1' and port_bf3b_ulap_mode = "00" and nr_ulatm_we = '0' else '0';
   
   process (i_CLK_28)
   begin
      if rising_edge(i_CLK_28) then
         ulap_palette_rd_dly <= ulap_palette_rd;
         ulap_palette_rd_done <= ulap_palette_rd or (port_ff3b_rd and ulap_palette_rd_done);
      end if;
   end process;
   
   -- At 28MHz, a copper write to the palette may delay a palette read past the end of an io cycle so insert a wait state for this case
   
   ulap_wait_n <= '0' when port_ff3b_rd = '1' and port_bf3b_ulap_mode = "00" and ulap_palette_rd_done = '0' else '1';
   
   ------------------------------------------------------------
   -- TBBLUE REGISTRY -----------------------------------------
   ------------------------------------------------------------

   -- Port 0x243B selects nextreg
   -- Port 0x253B reads / writes selected nextreg
   
   process (i_CLK_28)
   begin
      if rising_edge(i_CLK_28) then
         if reset = '1' then
            nr_register <= (others => '0');
         elsif port_243b_wr = '1' then
            nr_register <= cpu_do;
         end if;
      end if;
   end process;
   
   port_243b_dat <= nr_register;

   -- MMUs are set by nextreg and spectrum ports 1ffd, 7ffd, dffd, eff7

   process (i_CLK_28)
   begin
      if rising_edge(i_CLK_28) then
         if reset = '1' then
            MMU0 <= X"FF";
            MMU1 <= X"FF";
            MMU2 <= X"0A";
            MMU3 <= X"0B";
            MMU4 <= X"04";
            MMU5 <= X"05";
            MMU6 <= X"00";
            MMU7 <= X"01";
         elsif port_memory_change_dly = '1' then
         
            -- 1ffd, 7ffd, dffd, eff7 have been written to
            
            if port_1ffd_special = '1' then

               MMU0 <= X"0" & (port_1ffd_reg(2) or port_1ffd_reg(1)) & "00" & '0';
               MMU1 <= X"0" & (port_1ffd_reg(2) or port_1ffd_reg(1)) & "00" & '1';
               MMU2 <= X"0" & (port_1ffd_reg(2) or port_1ffd_reg(1)) & (port_1ffd_reg(2) and port_1ffd_reg(1)) & '1' & '0';
               MMU3 <= X"0" & (port_1ffd_reg(2) or port_1ffd_reg(1)) & (port_1ffd_reg(2) and port_1ffd_reg(1)) & '1' & '1';
               MMU4 <= X"0" & (port_1ffd_reg(2) or port_1ffd_reg(1)) & "10" & '0';
               MMU5 <= X"0" & (port_1ffd_reg(2) or port_1ffd_reg(1)) & "10" & '1';
               MMU6 <= X"0" & (not(port_1ffd_reg(2)) and port_1ffd_reg(1)) & "11" & '0';
               MMU7 <= X"0" & (not(port_1ffd_reg(2)) and port_1ffd_reg(1)) & "11" & '1';

            else
            
               if port_eff7_reg_3 = '1' or (nr_8f_mapping_mode_profi = '1' and port_dffd_reg(4) = '1') then
               
                  MMU0 <= X"00";
                  MMU1 <= X"01";
                  
               else
               
                  MMU0 <= X"FF";
                  MMU1 <= X"FF";
                  
               end if;
               
               if nr_8f_mapping_mode_profi = '1' and port_dffd_reg(3) = '1' then
               
                  MMU2 <= port_7ffd_bank & '0';
                  MMU3 <= port_7ffd_bank & '1';
               
               elsif nr_8f_mapping_mode_profi = '1' or port_1ffd_special_old = '1' then
               
                  MMU2 <= X"0A";
                  MMU3 <= X"0B";
               
               end if;
               
               if nr_8f_mapping_mode_profi = '1' and port_dffd_reg_6 = '1' then
               
                  MMU4 <= X"0C";
                  MMU5 <= X"0D";
               
               elsif nr_8f_mapping_mode_profi = '1' or port_1ffd_special_old = '1' then

                  MMU4 <= X"04";
                  MMU5 <= X"05";
                  
               end if;
               
               if nr_8f_mapping_mode_profi = '1' and port_dffd_reg(3) = '1' then
               
                  MMU6 <= X"0E";
                  MMU7 <= X"0F";
                  
               elsif port_1ffd_special_old = '1' or port_memory_ram_change_dly = '1' then 

                  MMU6 <= port_7ffd_bank & '0';
                  MMU7 <= port_7ffd_bank & '1';
               
               end if;

            end if;

         elsif nr_mmu_we = '1' then
            case nr_mmu is
               when "000"  => MMU0 <= nr_wr_dat;
               when "001"  => MMU1 <= nr_wr_dat;
               when "010"  => MMU2 <= nr_wr_dat;
               when "011"  => MMU3 <= nr_wr_dat;
               when "100"  => MMU4 <= nr_wr_dat;
               when "101"  => MMU5 <= nr_wr_dat;
               when "110"  => MMU6 <= nr_wr_dat;
               when others => MMU7 <= nr_wr_dat;
            end case;
         end if;

      end if;
   end process;
   
   --
   -- Write Registry
   --
   
   -- Arbitrate access between cpu (out, nextreg) and copper
   -- Must be mindful of 28MHz speed on cpu and dma; copper has highest priority

   copper_requester <= copper_dout_en;

   process (i_CLK_28)
   begin
      if rising_edge(i_CLK_28) then
         if reset = '1' then
            copper_req_dly <= '0';
         else
            copper_req_dly <= copper_requester;
         end if;
      end if;
   end process;
   
   process (i_CLK_28)
   begin
      if rising_edge(i_CLK_28) then
         if reset = '1' then
            copper_req <= '0';
            copper_nr_reg <= (others => '0');
            copper_nr_dat <= (others => '0');
         elsif copper_requester = '1' and copper_req_dly = '0' then
            copper_req <= '1';
            copper_nr_reg <= '0' & copper_dout(14 downto 8);
            copper_nr_dat <= copper_dout(7 downto 0);
         else
            copper_req <= '0';
         end if;
      end if;
   end process;

   cpu_requester_0 <= '1' when Z80N_dout_s = '1' and Z80N_command_s = NEXTREGW else '0';
   cpu_requester_1 <= port_253b_wr;
   cpu_requester_2 <= '1' when port_ff3b_wr = '1' and port_bf3b_ulap_mode = "00" else '0';

   process (i_CLK_28)
   begin
      if rising_edge(i_CLK_28) then
         if reset = '1' then
            cpu_req_dly <= '0';
         else
            cpu_req_dly <= cpu_requester_0 or cpu_requester_1 or cpu_requester_2 or (cpu_req and not cpu_served);
         end if;
      end if;
   end process;
   
   process (i_CLK_28)
   begin
      if rising_edge(i_CLK_28) then
         if reset = '1' then
            cpu_req <= '0';
            cpu_nr_reg <= (others => '0');
            cpu_nr_dat <= (others => '0');
         elsif cpu_served = '1' then
            cpu_req <= '0';
         elsif cpu_req_dly = '0' and cpu_requester_0 = '1' then
            cpu_req <= '1';
            cpu_nr_reg <= Z80N_data_s(15 downto 8);
            cpu_nr_dat <= Z80N_data_s(7 downto 0);
         elsif cpu_req_dly = '0' and cpu_requester_1 = '1' then
            cpu_req <= '1';
            cpu_nr_reg <= nr_register;
            cpu_nr_dat <= cpu_do;
         elsif cpu_req_dly = '0' and cpu_requester_2 = '1' then
            cpu_req <= '1';
            cpu_nr_reg <= X"FF";  -- shhh our little secret
            cpu_nr_dat <= cpu_do(4 downto 2) & cpu_do(7 downto 5) & cpu_do(1 downto 0);
         end if;
      end if;
   end process;

   nr_wr_en <= copper_req or cpu_req;
   nr_wr_reg <= copper_nr_reg when copper_req = '1' else cpu_nr_reg;
   nr_wr_dat <= copper_nr_dat when copper_req = '1' else cpu_nr_dat;
   
   cpu_served <= '1' when copper_req = '0' and cpu_req = '1' else '0';
   
   -- Write Registers
   
   -- combinatorial
   
   process (nr_wr_en, nr_wr_reg)
   begin
   
      nr_02_we <= '0';
      nr_05_we <= '0';
      nr_07_we <= '0';
      nr_08_we <= '0';
      nr_09_we <= '0';
      nr_22_we <= '0';
      nr_28_we <= '0';
      nr_29_we <= '0';
      nr_2a_we <= '0';
      nr_2b_we <= '0';
      nr_2c_we <= '0';
      nr_2d_we <= '0';
      nr_2e_we <= '0';
      nr_41_we <= '0';
      nr_44_we <= '0';
      nr_68_we <= '0';
      nr_69_we <= '0';
      nr_80_we <= '0';
      nr_8c_we <= '0';
      nr_8e_we <= '0';
      nr_8f_we <= '0';
      nr_c6_we <= '0';
      nr_ff_we <= '0';

      nr_sprite_mirror_we <= '0';
      nr_sprite_mirror_index <= "111";
      
      nr_mmu_we <= '0';
      
      nr_copper_we <= '0';
      nr_copper_write_8 <= '0';
      
      if nr_wr_en = '1' then
   
         case nr_wr_reg is
         
            when X"02"  => nr_02_we <= '1';
            when X"05"  => nr_05_we <= '1';
            when X"07"  => nr_07_we <= '1';
            when X"08"  => nr_08_we <= '1';
            when X"09"  => nr_09_we <= '1';
            when X"22"  => nr_22_we <= '1';
            when X"28"  => nr_28_we <= '1';
            when X"29"  => nr_29_we <= '1';
            when X"2A"  => nr_2a_we <= '1';
            when X"2B"  => nr_2b_we <= '1';
            when X"2C"  => nr_2c_we <= '1';
            when X"2D"  => nr_2d_we <= '1';
            when X"2E"  => nr_2e_we <= '1';
            when X"34"  => nr_sprite_mirror_we <= '1';
            
            when X"35" | X"75" =>
               nr_sprite_mirror_we <= '1';
               nr_sprite_mirror_index <= "000";
               
            when X"36" | X"76" =>
               nr_sprite_mirror_we <= '1';
               nr_sprite_mirror_index <= "001";
               
            when X"37" | X"77" =>
               nr_sprite_mirror_we <= '1';
               nr_sprite_mirror_index <= "010";
               
            when X"38" | X"78" =>
               nr_sprite_mirror_we <= '1';
               nr_sprite_mirror_index <= "011";
               
            when X"39" | X"79" =>
               nr_sprite_mirror_we <= '1';
               nr_sprite_mirror_index <= "100";
            
            when X"41" => nr_41_we <= '1';
            when X"44" => nr_44_we <= '1';
            
            when X"50" | X"51" | X"52" | X"53" | X"54" | X"55" | X"56" | X"57" =>
               nr_mmu_we <= '1';
            
            when X"60" =>
               nr_copper_we <= '1';
               nr_copper_write_8 <= '1';
            
            when X"63" => nr_copper_we <= '1';
            when X"68" => nr_68_we <= '1';
            when X"69" => nr_69_we <= '1';
            when X"80" => nr_80_we <= '1';
            when X"8C" => nr_8c_we <= '1';
            when X"8E" => nr_8e_we <= '1';
            when X"8F" => nr_8f_we <= '1';
            when X"C6" => nr_c6_we <= '1';
            when X"FF" => nr_ff_we <= '1';
            
            when others => null;
         
         end case;

      end if;
   
   end process;

   nr_sprite_mirror_inc <= nr_sprite_mirror_we and nr_wr_reg(6);
   
   nr_palette_we <= '1' when nr_41_we = '1' or (nr_44_we = '1' and nr_palette_sub_idx = '1') else '0';
   nr_palette_value <= (nr_wr_dat & (nr_wr_dat(1) or nr_wr_dat(0))) when (nr_41_we = '1' or nr_ff_we = '1') else (nr_stored_palette_value & nr_wr_dat(0));
   nr_palette_priority <= nr_wr_dat(7 downto 6) when nr_44_we = '1' else (others => '0');

   nr_mmu <= nr_wr_reg(2 downto 0);
   
   -- state
            
   nr_05_joymode_0 <= nr_wr_dat(3) & nr_wr_dat(7 downto 6);
   nr_05_joymode_1 <= nr_wr_dat(1) & nr_wr_dat(5 downto 4);
   nr_05_io_mode <= '1' when nr_05_joymode_0 = "111" or nr_05_joymode_1 = "111" else '0';

   process (i_CLK_28)
   begin
      if rising_edge(i_CLK_28) then

         if reset = '1' then

            io_mode_en <= '0';

            nr_06_hotkey_cpu_speed_en <= '1';
            nr_06_hotkey_5060_en <= '1';
            
            nr_08_contention_disable <= '0';
            
            nr_09_sprite_tie <= '0';
            
            nr_12_layer2_active_bank <= "0001000";
            nr_13_layer2_shadow_bank <= "0001011";
            
            nr_14_global_transparent_rgb <= X"E3";
            
            nr_15_lores_en <= '0';
            nr_15_sprite_priority <= '0';
            nr_15_sprite_border_clip_en <= '0';
            nr_15_layer_priority <= (others => '0');
            nr_15_sprite_over_border_en <= '0';
            nr_15_sprite_en <= '0';
            
            nr_16_layer2_scrollx <= (others => '0');
            
            nr_17_layer2_scrolly <= (others => '0');
            
            nr_18_layer2_clip_x1 <= X"00";
            nr_18_layer2_clip_x2 <= X"FF";
            nr_18_layer2_clip_y1 <= X"00";
            nr_18_layer2_clip_y2 <= X"BF";
            nr_18_layer2_clip_idx <= "00";
            
            nr_19_sprite_clip_x1 <= X"00";
            nr_19_sprite_clip_x2 <= X"FF";
            nr_19_sprite_clip_y1 <= X"00";
            nr_19_sprite_clip_y2 <= X"BF";
            nr_19_sprite_clip_idx <= "00";
            
            nr_1a_ula_clip_x1 <= X"00";
            nr_1a_ula_clip_x2 <= X"FF";
            nr_1a_ula_clip_y1 <= X"00";
            nr_1a_ula_clip_y2 <= X"BF";
            nr_1a_ula_clip_idx <= "00";
            
            nr_1b_tm_clip_x1 <= X"00";
            nr_1b_tm_clip_x2 <= X"9F";
            nr_1b_tm_clip_y1 <= X"00";
            nr_1b_tm_clip_y2 <= X"FF";
            nr_1b_tm_clip_idx <= "00";

            nr_22_line_interrupt_en <= '0';
            
            nr_23_line_interrupt <= (others => '0');
            
            nr_26_ula_scrollx <= X"00";
            
            nr_27_ula_scrolly <= X"00";
            
            nr_30_tm_scrollx <= (others => '0');
            
            nr_31_tm_scrolly <= X"00";
            
            nr_32_lores_scrollx <= X"00";
            
            nr_33_lores_scrolly <= X"00";
            
            nr_palette_idx <= X"00";
            nr_palette_sub_idx <= '0';
            
            nr_42_ulanext_format <= X"07";
            
            nr_43_palette_autoinc_disable <= '0';
            nr_43_palette_write_select <= "000";
            nr_43_active_sprite_palette <= '0';
            nr_43_active_layer2_palette <= '0';
            nr_43_active_ula_palette <= '0';
            nr_43_ulanext_en <= '0';
            
            nr_stored_palette_value <= X"00";
            
--          nr_4a_fallback_rgb <= X"00";
            nr_4a_fallback_rgb <= X"E3";
            
            nr_4b_sprite_transparent_index <= X"E3";
            
            nr_4c_tm_transparent_index <= X"F";
            
            nr_62_copper_mode <= "00";
            nr_copper_addr <= (others => '0');
            nr_copper_data_stored <= X"00";
            
            nr_64_copper_offset <= (others => '0');
            
            nr_68_ula_en <= '1';
            nr_68_blend_mode <= "00";
            nr_68_cancel_extended_keys <= '0';
            nr_68_ula_fine_scroll_x <= '0';
            nr_68_ula_stencil_mode <= '0';
            
            nr_6a_lores_radastan <= '0';
            nr_6a_lores_palette_offset <= X"0";
            nr_6a_lores_radastan_xor <= '0';
            
            nr_6b_tm_en <= '0';
            nr_6b_tm_control <= (others => '0');
            
            nr_6c_tm_default_attr <= (others => '0');
            
            nr_6e_tilemap_base_7 <= '0';
            nr_6e_tilemap_base <= "101100";
            
            nr_6f_tilemap_tiles_7 <= '0';
            nr_6f_tilemap_tiles <= "001100";
            
            nr_70_layer2_resolution <= "00";
            nr_70_layer2_palette_offset <= (others => '0');
            
            nr_71_layer2_scrollx_msb <= '0';
            
            nr_7f_user_register_0 <= (others => '1');

            if nr_85_internal_port_reset_type = '1' or reset_hard = '1' then
            
               nr_82_internal_port_enable <= (others => '1');
               nr_83_internal_port_enable <= (others => '1');
               nr_84_internal_port_enable <= (others => '1');
               nr_85_internal_port_enable <= "1111";
            
            end if;

            if nr_89_bus_port_reset_type = '0' or reset_hard = '1' then
            
               nr_86_bus_port_enable <= (others => '1');
               nr_87_bus_port_enable <= (others => '1');
               nr_88_bus_port_enable <= (others => '1');
               nr_89_bus_port_enable <= "1111";
            
            end if;

            nr_98_pi_gpio_o <= X"FF";
            nr_99_pi_gpio_o <= X"01";
            nr_9a_pi_gpio_o <= X"00";
            nr_9b_pi_gpio_o <= X"0";

            nr_90_pi_gpio_o_en <= (others => '0');
            nr_91_pi_gpio_o_en <= (others => '0');
            nr_92_pi_gpio_o_en <= (others => '0');
            nr_93_pi_gpio_o_en <= (others => '0');
         
            nr_a0_pi_peripheral_en <= (others => '0');
            nr_a2_pi_i2s_ctl <= (others => '0');
--          nr_a3_pi_i2s_clkdiv <= X"0B";  -- ~44.1kHz

            nr_a8_esp_gpio0_en <= '0';
            nr_a9_esp_gpio0 <= '1';

            if machine_type_config = '1' or reset_hard = '1' then
               bootrom_en <= '1';
            end if;
            
            if reset_hard = '1' then

               nr_02_bus_reset <= '0';
               
               nr_03_machine_type <= "000";
               nr_04_romram_bank <= (others => '0');
               nr_03_user_dt_lock <= '0';

               nr_06_internal_speaker_beep <= '0';
               nr_06_divmmc_automap_en <= '0';
               nr_06_button_m1_nmi_en <= '0';

               nr_08_psg_stereo_mode <= '0';
               nr_08_internal_speaker_en <= '1';
               nr_08_dac_en <= '0';
               nr_08_port_ff_rd_en <= '0';
               nr_08_psg_turbosound_en <= '0';
               nr_08_keyboard_issue2 <= '0';
               
               nr_09_psg_mono <= (others => '0');
               nr_09_hdmi_audio_disable <= '0';
               
               nr_0a_mf_type <= "00";
               nr_0a_mouse_button_reverse <= '0';
               nr_0a_mouse_dpi <= "01";
               
               nr_10_flashboot <= '0';
               
               nr_81_expbus_ula_override <= '0';
               nr_81_expbus_nmi_debounce_disable <= '0';
               nr_81_expbus_clken <= '0';
               nr_81_expbus_speed <= (others => '0');

               nr_85_internal_port_reset_type <= '1';
               nr_89_bus_port_reset_type <= '1';
               
               nr_8a_bus_port_propagate <= (others => '0');
         
            end if;
         
         elsif nr_wr_en = '1' then
         
            case nr_wr_reg is
            
               when X"02" =>
--                nr_02_we <= '1';
                  nr_02_bus_reset <= nr_wr_dat(7);
                  
               when X"03" =>
                  bootrom_en <= '0';
                  
                  if nr_wr_dat(7) = '1' and nr_03_user_dt_lock = '0' and nr_wr_dat(3) = '0' then
                     case nr_wr_dat(6 downto 4) is
                        when "000"  => nr_03_machine_timing <= "001";
                        when "001"  => nr_03_machine_timing <= "001";
                        when "010"  => nr_03_machine_timing <= "010";
                        when "011"  => nr_03_machine_timing <= "011";
                        when "100"  => nr_03_machine_timing <= "100";
                        when others => nr_03_machine_timing <= "011";
                     end case;
                  end if;
                  
                  nr_03_user_dt_lock <= nr_03_user_dt_lock xor nr_wr_dat(3);
                  
                  if machine_type_config = '1' then
                     case nr_wr_dat(2 downto 0) is
                        when "001"  => nr_03_machine_type <= "001";
                        when "010"  => nr_03_machine_type <= "010";
                        when "011"  => nr_03_machine_type <= "011";
                        when "100"  => nr_03_machine_type <= "100";
                        when others => nr_03_machine_type <= "000";
                     end case;
                  end if;
               
               when X"04" =>
                  nr_04_romram_bank <= nr_wr_dat(6 downto 0);
               
               when X"05" =>
                  io_mode_en <= nr_05_io_mode;
                  
                  if nr_05_io_mode = '0' then
                     nr_05_joy0 <= nr_05_joymode_0;
                     nr_05_joy1 <= nr_05_joymode_1;
                  end if;

--                nr_05_we <= '1';

               when X"06" =>
                  nr_06_hotkey_cpu_speed_en <= nr_wr_dat(7);
                  nr_06_internal_speaker_beep <= nr_wr_dat(6);
                  nr_06_hotkey_5060_en <= nr_wr_dat(5);
                  nr_06_divmmc_automap_en <= nr_wr_dat(4);
                  nr_06_button_m1_nmi_en <= nr_wr_dat(3);
                  if machine_type_config = '1' then
                     nr_06_ps2_mode <= nr_wr_dat(2);
                  end if;
                  nr_06_psg_mode <= nr_wr_dat(1 downto 0);
               
--             when X"07" =>
--                nr_07_we <= '1';
               
               when X"08" =>
                  nr_08_contention_disable <= nr_wr_dat(6);
                  nr_08_psg_stereo_mode <= nr_wr_dat(5);
                  nr_08_internal_speaker_en <= nr_wr_dat(4);
                  nr_08_dac_en <= nr_wr_dat(3);
                  nr_08_port_ff_rd_en <= nr_wr_dat(2);
                  nr_08_psg_turbosound_en <= nr_wr_dat(1);
                  nr_08_keyboard_issue2 <= nr_wr_dat(0);
--                nr_08_we <= '1';
               
               when X"09" =>
                  nr_09_psg_mono <= nr_wr_dat(7 downto 5);
                  nr_09_sprite_tie <= nr_wr_dat(4);
                  nr_09_hdmi_audio_disable <= nr_09_hdmi_audio_disable or nr_wr_dat(2);
--                nr_09_we <= '1';

               when X"0A" =>
                  if machine_type_config = '1' then
                     nr_0a_mf_type <= nr_wr_dat(7 downto 6);
                  end if;
                  nr_0a_mouse_button_reverse <= nr_wr_dat(3);
                  nr_0a_mouse_dpi <= nr_wr_dat(1 downto 0);
               
               when X"10" =>
                  nr_10_flashboot <= nr_wr_dat(7);
                  if machine_type_config = '1' then
                     nr_10_coreid <= nr_wr_dat(4 downto 0);
                  end if;
               
               when X"11" =>
                  if machine_type_config = '1' then
                     nr_11_video_timing <= nr_wr_dat(2 downto 0);
                  end if;
               
               when X"12" =>
                  nr_12_layer2_active_bank <= nr_wr_dat(6 downto 0);
               
               when X"13" =>
                  nr_13_layer2_shadow_bank <= nr_wr_dat(6 downto 0);
               
               when X"14" =>
                  nr_14_global_transparent_rgb <= nr_wr_dat;
               
               when X"15" =>
                  nr_15_lores_en <= nr_wr_dat(7);
                  nr_15_sprite_priority <= nr_wr_dat(6);
                  nr_15_sprite_border_clip_en <= nr_wr_dat(5);
                  nr_15_layer_priority <= nr_wr_dat(4 downto 2);
                  nr_15_sprite_over_border_en <= nr_wr_dat(1);
                  nr_15_sprite_en <= nr_wr_dat(0);
               
               when X"16" =>
                  nr_16_layer2_scrollx <= nr_wr_dat;
               
               when X"17" =>
                  nr_17_layer2_scrolly <= nr_wr_dat;
               
               when X"18" =>
                  case nr_18_layer2_clip_idx is
                     when "00"  => nr_18_layer2_clip_x1 <= nr_wr_dat;
                     when "01"  => nr_18_layer2_clip_x2 <= nr_wr_dat;
                     when "10"  => nr_18_layer2_clip_y1 <= nr_wr_dat;
                     when others => nr_18_layer2_clip_y2 <= nr_wr_dat;
                  end case;
                  nr_18_layer2_clip_idx <= nr_18_layer2_clip_idx + 1;
               
               when X"19" =>
                  case nr_19_sprite_clip_idx is
                     when "00"  => nr_19_sprite_clip_x1 <= nr_wr_dat;
                     when "01"  => nr_19_sprite_clip_x2 <= nr_wr_dat;
                     when "10"  => nr_19_sprite_clip_y1 <= nr_wr_dat;
                     when others => nr_19_sprite_clip_y2 <= nr_wr_dat;
                  end case;
                  nr_19_sprite_clip_idx <= nr_19_sprite_clip_idx + 1;
               
               when X"1A" =>
                  case nr_1a_ula_clip_idx is
                     when "00"  => nr_1a_ula_clip_x1 <= nr_wr_dat;
                     when "01"  => nr_1a_ula_clip_x2 <= nr_wr_dat;
                     when "10"  => nr_1a_ula_clip_y1 <= nr_wr_dat;
                     when others => nr_1a_ula_clip_y2 <= nr_wr_dat;
                  end case;
                  nr_1a_ula_clip_idx <= nr_1a_ula_clip_idx + 1;

               when X"1B" =>
                  case nr_1b_tm_clip_idx is
                     when "00"  => nr_1b_tm_clip_x1 <= nr_wr_dat;
                     when "01"  => nr_1b_tm_clip_x2 <= nr_wr_dat;
                     when "10"  => nr_1b_tm_clip_y1 <= nr_wr_dat;
                     when others => nr_1b_tm_clip_y2 <= nr_wr_dat;
                  end case;
                  nr_1b_tm_clip_idx <= nr_1b_tm_clip_idx + 1;
               
               when X"1C" =>
                  if nr_wr_dat(0) = '1' then
                     nr_18_layer2_clip_idx <= "00";
                  end if;
                  if nr_wr_dat(1) = '1' then
                     nr_19_sprite_clip_idx <= "00";
                  end if;
                  if nr_wr_dat(2) = '1' then
                     nr_1a_ula_clip_idx <= "00";
                  end if;
                  if nr_wr_dat(3) = '1' then
                     nr_1b_tm_clip_idx <= "00";
                  end if;

               when X"22" =>
--                nr_22_we <= '1';
                  nr_22_line_interrupt_en <= nr_wr_dat(1);
                  nr_23_line_interrupt(8) <= nr_wr_dat(0);
               
               when X"23" =>
                  nr_23_line_interrupt(7 downto 0) <= nr_wr_dat;

               when X"26" =>
                  nr_26_ula_scrollx <= nr_wr_dat;
               
               when X"27" =>
                  nr_27_ula_scrolly <= nr_wr_dat;

--             when X"28" =>
--                nr_28_we <= '1';
               
--             when X"29" =>
--                nr_29_we <= '1';

--             when X"2A" =>
--                nr_2a_we <= '1';
               
--             when X"2B" =>
--                nr_2b_we <= '1';

--             when X"2C" =>
--                nr_2c_we <= '1';
      
--             when X"2D" =>
--                nr_2d_we <= '1';

--             when X"2E" =>
--                nr_2e_we <= '1';

               when X"2F" =>
                  nr_30_tm_scrollx(9 downto 8) <= nr_wr_dat(1 downto 0);
               
               when X"30" =>
                  nr_30_tm_scrollx(7 downto 0) <= nr_wr_dat;
               
               when X"31" =>
                  nr_31_tm_scrolly <= nr_wr_dat;
               
               when X"32" =>
                  nr_32_lores_scrollx <= nr_wr_dat;
               
               when X"33" =>
                  nr_33_lores_scrolly <= nr_wr_dat;
               
--             when X"34" =>
--                nr_sprite_mirror_we <= '1';
--                nr_sprite_mirror_index <= "111";
--             
--             when X"35" | X"75" =>
--                nr_sprite_mirror_we <= '1';
--                nr_sprite_mirror_index <= "000";
--                nr_sprite_mirror_inc <= nr_wr_reg(6);
--             
--             when X"36" | X"76" =>
--                nr_sprite_mirror_we <= '1';
--                nr_sprite_mirror_index <= "001";
--                nr_sprite_mirror_inc <= nr_wr_reg(6);
--             
--             when X"37" | X"77" =>
--                nr_sprite_mirror_we <= '1';
--                nr_sprite_mirror_index <= "010";
--                nr_sprite_mirror_inc <= nr_wr_reg(6);
--             
--             when X"38" | X"78" =>
--                nr_sprite_mirror_we <= '1';
--                nr_sprite_mirror_index <= "011";
--                nr_sprite_mirror_inc <= nr_wr_reg(6);
--
--             when X"39" | X"79" =>
--                nr_sprite_mirror_we <= '1';
--                nr_sprite_mirror_index <= "100";
--                nr_sprite_mirror_inc <= nr_wr_reg(6);
                  
               when X"40" =>
                  nr_palette_idx <= nr_wr_dat;
                  nr_palette_sub_idx <= '0';
               
               when X"41" =>
                  if nr_43_palette_autoinc_disable = '0' then
                     nr_palette_idx <= nr_palette_idx + 1;
                  end if;
                  nr_palette_sub_idx <= '0';
--                nr_41_we <= '1';
               
               when X"42" =>
                  nr_42_ulanext_format <= nr_wr_dat;
               
               when X"43" =>
                  nr_43_palette_autoinc_disable <= nr_wr_dat(7);
                  nr_43_palette_write_select <= nr_wr_dat(6 downto 4);
                  nr_43_active_sprite_palette <= nr_wr_dat(3);
                  nr_43_active_layer2_palette <= nr_wr_dat(2);
                  nr_43_active_ula_palette <= nr_wr_dat(1);
                  nr_43_ulanext_en <= nr_wr_dat(0);
                  nr_palette_sub_idx <= '0';
               
               when X"44" =>
                  if nr_palette_sub_idx = '0' then
                     nr_stored_palette_value <= nr_wr_dat;
                  elsif nr_43_palette_autoinc_disable = '0' then
                     nr_palette_idx <= nr_palette_idx + 1;
                  end if;
                  nr_palette_sub_idx <= not nr_palette_sub_idx;
--                nr_44_we <= '1';
               
               when X"4A" =>
                  nr_4a_fallback_rgb <= nr_wr_dat;
               
               when X"4B" =>
                  nr_4b_sprite_transparent_index <= nr_wr_dat;
               
               when X"4C" =>
                  nr_4c_tm_transparent_index <= nr_wr_dat(3 downto 0);
               
--             when X"50" | X"51" | X"52" | X"53" | X"54" | X"55" | X"56" | X"57" =>
--                nr_mmu_we <= '1';
               
               when X"60" =>
                  if nr_copper_addr(0) = '0' then
                     nr_copper_data_stored <= nr_wr_dat;
                  end if;
--                nr_copper_we <= '1';
--                nr_copper_write_8 <= '1';
                  nr_copper_addr <= nr_copper_addr + 1;
               
               when X"61" =>
                  nr_copper_addr(7 downto 0) <= nr_wr_dat;
               
               when X"62" =>
                  nr_62_copper_mode <= nr_wr_dat(7 downto 6);
                  nr_copper_addr(10 downto 8) <= nr_wr_dat(2 downto 0);
               
               when X"63" =>
                  if nr_copper_addr(0) = '0' then
                     nr_copper_data_stored <= nr_wr_dat;
                  end if;
                  nr_copper_addr <= nr_copper_addr + 1;
--                nr_copper_we <= '1';
--                nr_copper_write_8 <= '0';

               when X"64" =>
                  nr_64_copper_offset <= nr_wr_dat;
               
               when X"68" =>
                  nr_68_ula_en <= not nr_wr_dat(7);
                  nr_68_blend_mode <= nr_wr_dat(6 downto 5);
                  nr_68_cancel_extended_keys <= nr_wr_dat(4);
--                nr_68_ulap_en <= nr_wr_dat(3);
                  nr_68_ula_fine_scroll_x <= nr_wr_dat(2);
                  nr_68_ula_stencil_mode <= nr_wr_dat(0);
               
--             when X"69" =>
--                nr_69_we <= '1';

               when X"6A" =>
                  nr_6a_lores_radastan <= nr_wr_dat(5);
                  nr_6a_lores_radastan_xor <= nr_wr_dat(4);
                  nr_6a_lores_palette_offset <= nr_wr_dat(3 downto 0);

               when X"6B" =>
                  nr_6b_tm_en <= nr_wr_dat(7);
                  nr_6b_tm_control <= nr_wr_dat(6 downto 0);
               
               when X"6C" =>
                  nr_6c_tm_default_attr <= nr_wr_dat;
               
               when X"6E" =>
                  nr_6e_tilemap_base_7 <= nr_wr_dat(7);
                  nr_6e_tilemap_base <= nr_wr_dat(5 downto 0);
               
               when X"6F" =>
                  nr_6f_tilemap_tiles_7 <= nr_wr_dat(7);
                  nr_6f_tilemap_tiles <= nr_wr_dat(5 downto 0);
               
               when X"70" =>
                  nr_70_layer2_resolution <= nr_wr_dat(5 downto 4);
                  nr_70_layer2_palette_offset <= nr_wr_dat(3 downto 0);
               
               when X"71" =>
                  nr_71_layer2_scrollx_msb <= nr_wr_dat(0);

--             when X"75" | X"76" | X"77" | X"78" | X"79" =>
--                sprite mirror;
               
               when X"7F" =>
                  nr_7f_user_register_0 <= nr_wr_dat;
               
--             when X"80" =>
--                nr_80_we <= '1';

               when X"81" =>
                  nr_81_expbus_ula_override <= nr_wr_dat(6);
                  nr_81_expbus_nmi_debounce_disable <= nr_wr_dat(5);
                  nr_81_expbus_clken <= nr_wr_dat(4);
                  nr_81_expbus_speed <= "00";   -- nr_wr_dat(1 downto 0);
               
               when X"82" =>
                  nr_82_internal_port_enable <= nr_wr_dat;
               
               when X"83" =>
                  nr_83_internal_port_enable <= nr_wr_dat;

               when X"84" =>
                  nr_84_internal_port_enable <= nr_wr_dat;
               
               when X"85" =>
                  nr_85_internal_port_enable <= nr_wr_dat(3 downto 0);
                  nr_85_internal_port_reset_type <= nr_wr_dat(7);
               
               when X"86" =>
                  nr_86_bus_port_enable <= nr_wr_dat;
               
               when X"87" =>
                  nr_87_bus_port_enable <= nr_wr_dat;
               
               when X"88" =>
                  nr_88_bus_port_enable <= nr_wr_dat;
               
               when X"89" =>
                  nr_89_bus_port_enable <= nr_wr_dat(3 downto 0);
                  nr_89_bus_port_reset_type <= nr_wr_dat(7);
                  
               when X"8A" =>
                  nr_8a_bus_port_propagate <= nr_wr_dat(5 downto 0);

--             when X"8C" =>
--                nr_8c_we <= '1';

--             when X"8E" =>
--                nr_8e_we <= '1';

--             when X"8F" =>
--                nr_8f_we <= '1';

               when X"90" =>
                  nr_90_pi_gpio_o_en <= nr_wr_dat(7 downto 2) & "00";   -- not enabling output on GPIO 1:0
               
               when X"91" =>
                  nr_91_pi_gpio_o_en <= nr_wr_dat;
               
               when X"92" =>
                  nr_92_pi_gpio_o_en <= nr_wr_dat;
               
               when X"93" =>
                  nr_93_pi_gpio_o_en <= nr_wr_dat(3 downto 0);

               when X"98" =>
                  nr_98_pi_gpio_o <= nr_wr_dat;
               
               when X"99" =>
                  nr_99_pi_gpio_o <= nr_wr_dat;
               
               when X"9A" =>
                  nr_9a_pi_gpio_o <= nr_wr_dat;
               
               when X"9B" =>
                  nr_9b_pi_gpio_o <= nr_wr_dat(3 downto 0);

               when X"A0" =>
                  nr_a0_pi_peripheral_en <= nr_wr_dat;
               
               when X"A2" =>
                  nr_a2_pi_i2s_ctl <= nr_wr_dat;
               
--             when X"A3" =>
--                nr_a3_pi_i2s_clkdiv <= nr_wr_dat;
               
               when X"A8" =>
                  nr_a8_esp_gpio0_en <= nr_wr_dat(0);
               
               when X"A9" =>
                  nr_a9_esp_gpio0 <= nr_wr_dat(0);
               
--             when X"B0" =>
--                read only extended keys

--             when X"B1" =>
--                read only extended keys

--             when X"C6" =>
--                nr_c6_we <= '1';

--             when X"FF" =>
--                reserved for ula+

               when others =>
                  null;
            
            end case;

         end if;
      
      end if;
   end process;

   -- Machine Type

   machine_type_config <= '1' when nr_03_machine_type = "000" else '0';   -- 48k config
   machine_type_48 <= '1' when nr_03_machine_type(2 downto 1) = "00" else '0';   -- 48k
   machine_type_128 <= '1' when nr_03_machine_type = "010" or nr_03_machine_type = "100" else '0';  -- 128k or pentagon
   machine_type_p3 <= '1' when nr_03_machine_type = "011" else '0';   -- +3

   -- Machine Timing
   
   machine_timing_48 <= '1' when nr_03_machine_timing(2 downto 1) = "00" else '0';
   machine_timing_128 <= '1' when nr_03_machine_timing = "010" else '0';
   machine_timing_p3 <= '1' when nr_03_machine_timing = "011" else '0';
   machine_timing_pentagon <= '1' when nr_03_machine_timing = "100" else '0';
   
   -- CPU Speed
   
   process (i_CLK_28)
   begin
      if rising_edge(i_CLK_28) then
         if reset = '1' then
            nr_07_cpu_speed <= "00";
         elsif nr_07_we = '1' then
            nr_07_cpu_speed <= nr_wr_dat(1 downto 0);
         elsif hotkey_cpu_speed = '1' and nr_06_hotkey_cpu_speed_en = '1' then
            nr_07_cpu_speed <= nr_07_cpu_speed + 1;
         end if;
      end if;
   end process;
   
   process (i_CLK_CPU)
   begin
      if rising_edge(i_CLK_CPU) then
         if reset_hard = '1' then
         
            cpu_speed <= "00";
            eff_nr_08_contention_disable <= '0';
            
            expbus_eff_en <= '0';
            expbus_eff_disable_io <= '0';
            expbus_eff_disable_mem <= '0';
            expbus_eff_clken <= '0';
            
         elsif reset_soft = '1' then
         
            cpu_speed <= "00";
            eff_nr_08_contention_disable <= '0';
            
            expbus_eff_en <= expbus_en;
            expbus_eff_disable_io <= expbus_disable_io;
            expbus_eff_disable_mem <= expbus_disable_mem;
            expbus_eff_clken <= expbus_clken;
            
         elsif cpu_mreq_n = '1' and cpu_iorq_n = '1' and cpu_m1_n = '1' and dma_holds_bus = '0' then
         
            expbus_eff_en <= expbus_en;
            expbus_eff_disable_io <= expbus_disable_io;
            expbus_eff_disable_mem <= expbus_disable_mem;
            expbus_eff_clken <= expbus_clken;
            
            if expbus_en = '0' then
               cpu_speed <= nr_07_cpu_speed;
            else
               cpu_speed <= expbus_speed;
            end if;
            
            if hc(8) = '1' then
               eff_nr_08_contention_disable <= nr_08_contention_disable;
            end if;
            
         end if;
      end if;
   end process;

   -- Various State
   
   process (i_CLK_28)
   begin
      if rising_edge(i_CLK_28) then
         if nr_05_we = '1' then
            nr_05_5060 <= nr_wr_dat(2);
         elsif hotkey_5060 = '1' and nr_06_hotkey_5060_en = '1' then
            nr_05_5060 <= not nr_05_5060;
         end if;
      end if;
   end process;
   
   process (i_CLK_28)
   begin
      if rising_edge(i_CLK_28) then
         if nr_05_we = '1' then
            nr_05_scandouble_en <= nr_wr_dat(0);
         elsif hotkey_scandouble = '1' then
            nr_05_scandouble_en <= not nr_05_scandouble_en;
         end if;
      end if;
   end process;
   
   process (i_CLK_28)
   begin
      if rising_edge(i_CLK_28) then
         if reset_hard = '1' then
            nr_09_scanlines <= (others => '0');
         elsif nr_09_we = '1' then
            nr_09_scanlines <= nr_wr_dat(1 downto 0);
         elsif hotkey_scanlines = '1' then
            nr_09_scanlines <= nr_09_scanlines + 1;
         end if;
      end if;
   end process;

   --
   -- Read Registry
   --

   process (i_CLK_28)
   begin
      if rising_edge(i_CLK_28) then
         if reset = '1' then
            nr_02_reset_type <= reset_hard & reset_soft;
         end if;
      end if;
   end process;
   
   process (i_CLK_CPU)
   begin
      if falling_edge(i_CLK_CPU) then
         port_253b_dat_0 <= port_253b_dat;
      end if;
   end process;

   process (i_CLK_28)
   begin
      if rising_edge(i_CLK_28) then

         case nr_register is
      
            when X"00" =>
               port_253b_dat <= std_logic_vector(g_machine_id);
         
            when X"01" =>
               port_253b_dat <= std_logic_vector(g_version);
         
            when X"02" =>
               port_253b_dat <= nr_02_bus_reset & "00000" & nr_02_reset_type;
         
            when X"03" =>
               port_253b_dat <= nr_palette_sub_idx & nr_03_machine_timing & nr_03_user_dt_lock & nr_03_machine_type;
            
            when X"05" =>
               port_253b_dat <= nr_05_joy0(1 downto 0) & nr_05_joy1(1 downto 0) & nr_05_joy0(2) & eff_nr_05_5060 & nr_05_joy1(2) & eff_nr_05_scandouble_en;

            when X"06" =>
               port_253b_dat <= nr_06_hotkey_cpu_speed_en & nr_06_internal_speaker_beep & nr_06_hotkey_5060_en & nr_06_divmmc_automap_en & nr_06_button_m1_nmi_en & nr_06_ps2_mode & nr_06_psg_mode;

            when X"07" =>
               port_253b_dat <= "00" & cpu_speed & "00" & nr_07_cpu_speed;
         
            when X"08" =>
               port_253b_dat <= (not port_7ffd_locked) & eff_nr_08_contention_disable & nr_08_psg_stereo_mode & nr_08_internal_speaker_en & nr_08_dac_en & nr_08_port_ff_rd_en & nr_08_psg_turbosound_en & nr_08_keyboard_issue2;

            when X"09" =>
               port_253b_dat <= nr_09_psg_mono & nr_09_sprite_tie & '0' & nr_09_hdmi_audio_disable & eff_nr_09_scanlines;

            when X"0A" =>
               port_253b_dat <= nr_0a_mf_type & "00" & nr_0a_mouse_button_reverse & '0' & nr_0a_mouse_dpi;
 
            when X"0E" =>
               port_253b_dat <= std_logic_vector(g_sub_version);
         
            when X"10" =>
               port_253b_dat <= "000000" & i_SPKEY_BUTTONS(1 downto 0);
         
            when X"11" =>
               port_253b_dat <= "00000" & nr_11_video_timing;
         
            when X"12" =>
               port_253b_dat <= '0' & nr_12_layer2_active_bank;
         
            when X"13" =>
               port_253b_dat <= '0' & nr_13_layer2_shadow_bank;
         
            when X"14" =>
               port_253b_dat <= nr_14_global_transparent_rgb;
         
            when X"15" =>
               port_253b_dat <= nr_15_lores_en & nr_15_sprite_priority & nr_15_sprite_border_clip_en & nr_15_layer_priority & nr_15_sprite_over_border_en & nr_15_sprite_en;
         
            when X"16" =>
               port_253b_dat <= nr_16_layer2_scrollx;
         
            when X"17" =>
               port_253b_dat <= nr_17_layer2_scrolly;
         
            when X"18" =>
               case nr_18_layer2_clip_idx is
                  when "00"  => port_253b_dat <= nr_18_layer2_clip_x1;
                  when "01"  => port_253b_dat <= nr_18_layer2_clip_x2;
                  when "10"  => port_253b_dat <= nr_18_layer2_clip_y1;
                  when others => port_253b_dat <= nr_18_layer2_clip_y2;
               end case;

            when X"19" =>
               case nr_19_sprite_clip_idx is
                  when "00"  => port_253b_dat <= nr_19_sprite_clip_x1;
                  when "01"  => port_253b_dat <= nr_19_sprite_clip_x2;
                  when "10"  => port_253b_dat <= nr_19_sprite_clip_y1;
                  when others => port_253b_dat <= nr_19_sprite_clip_y2;
               end case;
         
            when X"1A" =>
               case nr_1a_ula_clip_idx is
                  when "00"  => port_253b_dat <= nr_1a_ula_clip_x1;
                  when "01"  => port_253b_dat <= nr_1a_ula_clip_x2;
                  when "10"  => port_253b_dat <= nr_1a_ula_clip_y1;
                  when others => port_253b_dat <= nr_1a_ula_clip_y2;
               end case;
         
            when X"1B" =>
               case nr_1b_tm_clip_idx is
                  when "00"  => port_253b_dat <= nr_1b_tm_clip_x1;
                  when "01"  => port_253b_dat <= nr_1b_tm_clip_x2;
                  when "10"  => port_253b_dat <= nr_1b_tm_clip_y1;
                  when others => port_253b_dat <= nr_1b_tm_clip_y2;
               end case;
         
            when X"1C" =>
               port_253b_dat <= nr_1b_tm_clip_idx & nr_1a_ula_clip_idx & nr_19_sprite_clip_idx & nr_18_layer2_clip_idx;

            when X"1E" =>
               port_253b_dat <= "0000000" & cvc(8);
         
            when X"1F" =>
               port_253b_dat <= std_logic_vector(cvc(7 downto 0));
         
            when X"22" =>
               port_253b_dat <= (not ula_int_n) & "0000" & port_ff_interrupt_disable & nr_22_line_interrupt_en & nr_23_line_interrupt(8);
         
            when X"23" =>
               port_253b_dat <= nr_23_line_interrupt(7 downto 0);

            when X"26" =>
               port_253b_dat <= nr_26_ula_scrollx;
               
            when X"27" =>
               port_253b_dat <= nr_27_ula_scrolly;

            when X"28" =>
               port_253b_dat <= nr_stored_palette_value;
         
            when X"2C" =>
               port_253b_dat <= pi_audio_L(9 downto 2);
               nr_2d_i2s_sample <= pi_audio_L(1 downto 0);
            
            when X"2D" =>
               port_253b_dat <= nr_2d_i2s_sample & "000000";
            
            when X"2E" =>
               port_253b_dat <= pi_audio_R(9 downto 2);
               nr_2d_i2s_sample <= pi_audio_R(1 downto 0);
            
            when X"2F" =>
               port_253b_dat <= "000000" & nr_30_tm_scrollx(9 downto 8);
         
            when X"30" =>
               port_253b_dat <= nr_30_tm_scrollx(7 downto 0);
         
            when X"31" =>
               port_253b_dat <= nr_31_tm_scrolly;
         
            when X"32" =>
               port_253b_dat <= nr_32_lores_scrollx;
         
            when X"33" =>
               port_253b_dat <= nr_33_lores_scrolly;
         
            when X"34" =>
               port_253b_dat <= '0' & sprite_mirror_id;
         
            when X"40" =>
               port_253b_dat <= nr_palette_idx;
         
            when X"41" =>
               port_253b_dat <= nr_palette_dat(8 downto 1);
         
            when X"42" =>
               port_253b_dat <= nr_42_ulanext_format;
         
            when X"43" =>
               port_253b_dat <= nr_43_palette_autoinc_disable & nr_43_palette_write_select & nr_43_active_sprite_palette & nr_43_active_layer2_palette & nr_43_active_ula_palette & nr_43_ulanext_en;
         
            when X"44" =>
               port_253b_dat <= nr_palette_dat(10 downto 9) & "00000" & nr_palette_dat(0);
         
            when X"4A" =>
               port_253b_dat <= nr_4a_fallback_rgb;
         
            when X"4B" =>
               port_253b_dat <= nr_4b_sprite_transparent_index;
         
            when X"4C" =>
               port_253b_dat <= "0000" & nr_4c_tm_transparent_index;
         
            when X"50" =>
               port_253b_dat <= MMU0;
         
            when X"51" =>
               port_253b_dat <= MMU1;
         
            when X"52" =>
               port_253b_dat <= MMU2;
         
            when X"53" =>
               port_253b_dat <= MMU3;
         
            when X"54" =>
               port_253b_dat <= MMU4;
         
            when X"55" =>
               port_253b_dat <= MMU5;
         
            when X"56" =>
               port_253b_dat <= MMU6;
         
            when X"57" =>
               port_253b_dat <= MMU7;

            when X"61" =>
               port_253b_dat <= nr_copper_addr(7 downto 0);
               
            when X"62" =>
               port_253b_dat <= nr_62_copper_mode & "000" & nr_copper_addr(10 downto 8);
            
            when X"64"=>
               port_253b_dat <= nr_64_copper_offset;

            when X"68" =>
               port_253b_dat <= (not nr_68_ula_en) & nr_68_blend_mode & nr_68_cancel_extended_keys & port_ff3b_ulap_en & nr_68_ula_fine_scroll_x & '0' & nr_68_ula_stencil_mode;
         
            when X"69" =>
               port_253b_dat <= port_123b_layer2_en & port_7ffd_shadow & port_ff_reg(5 downto 0);
         
            when X"6A" =>
               port_253b_dat <= "00" & nr_6a_lores_radastan & nr_6a_lores_radastan_xor & nr_6a_lores_palette_offset;
         
            when X"6B" =>
               port_253b_dat <= nr_6b_tm_en & nr_6b_tm_control;
         
            when X"6C" =>
               port_253b_dat <= nr_6c_tm_default_attr;
         
            when X"6E" =>
               port_253b_dat <= nr_6e_tilemap_base_7 & '0' & nr_6e_tilemap_base;
         
            when X"6F" =>
               port_253b_dat <= nr_6f_tilemap_tiles_7 & '0' & nr_6f_tilemap_tiles;
            
            when X"70" =>
               port_253b_dat <= "00" & nr_70_layer2_resolution & nr_70_layer2_palette_offset;
            
            when X"71" =>
               port_253b_dat <= "0000000" & nr_71_layer2_scrollx_msb;

            when X"7F" =>
               port_253b_dat <= nr_7f_user_register_0;
               
            when X"80" =>
               port_253b_dat <= nr_80_expbus;
            
            when X"81" =>
               port_253b_dat <= i_BUS_ROMCS_n & nr_81_expbus_ula_override & nr_81_expbus_nmi_debounce_disable & nr_81_expbus_clken & "00" & nr_81_expbus_speed;
            
            when X"82" =>
               port_253b_dat <= nr_82_internal_port_enable;
            
            when X"83" =>
               port_253b_dat <= nr_83_internal_port_enable;

            when X"84" =>
               port_253b_dat <= nr_84_internal_port_enable;
            
            when X"85" =>
               port_253b_dat <= nr_85_internal_port_reset_type & "000" & nr_85_internal_port_enable;
            
            when X"86" =>
               port_253b_dat <= nr_86_bus_port_enable;
            
            when X"87" =>
               port_253b_dat <= nr_87_bus_port_enable;

            when X"88" =>
               port_253b_dat <= nr_88_bus_port_enable;

            when X"89" =>
               port_253b_dat <= nr_89_bus_port_reset_type & "000" & nr_89_bus_port_enable;
            
            when X"8A" =>
               port_253b_dat <= "00" & nr_8a_bus_port_propagate;
            
            when X"8C" =>
               port_253b_dat <= nr_8c_altrom;
            
            when X"8E" =>
               port_253b_dat <= port_dffd_reg(0) & port_7ffd_reg(2 downto 0) & '1' & port_1ffd_reg(0) & port_1ffd_reg(2) & ((port_7ffd_reg(4) and not port_1ffd_reg(0)) or (port_1ffd_reg(1) and port_1ffd_reg(0)));
            
            when X"8F" =>
               port_253b_dat <= "000000" & nr_8f_mapping_mode;
            
            when X"90" =>
               port_253b_dat <= nr_90_pi_gpio_o_en;

            when X"91" =>
               port_253b_dat <= nr_91_pi_gpio_o_en;
            
            when X"92" =>
               port_253b_dat <= nr_92_pi_gpio_o_en;
            
            when X"93" =>
               port_253b_dat <= "0000" & nr_93_pi_gpio_o_en;

            when X"98" =>
               port_253b_dat <= i_GPIO(7 downto 0);
            
            when X"99" =>
               port_253b_dat <= i_GPIO(15 downto 8);
            
            when X"9A" =>
               port_253b_dat <= i_GPIO(23 downto 16);
            
            when X"9B" =>
               port_253b_dat <= "0000" & i_GPIO(27 downto 24);

            when X"A0" =>
               port_253b_dat <= "00" & nr_a0_pi_peripheral_en(5 downto 3) & "00" & nr_a0_pi_peripheral_en(0);

            when X"A2" =>
               port_253b_dat <= nr_a2_pi_i2s_ctl(7 downto 6) & '0' & nr_a2_pi_i2s_ctl(4 downto 2) & '1' & nr_a2_pi_i2s_ctl(0);

--          when X"A3" =>
--             port_253b_dat <= nr_a3_pi_i2s_clkdiv;
            
            when X"A8" =>
               port_253b_dat <= "0000000" & nr_a8_esp_gpio0_en;
            
            when X"A9" =>
               port_253b_dat <= "00000" & i_ESP_GPIO_20(2) & '0' & i_ESP_GPIO_20(0);
            
            -- i_KBD_EXTENDED_KEYS(15 downto 8) = DOWN LEFT RIGHT DELETE . , " ;
            -- i_KBD_EXTENDED_KEYS( 7 downto 0) = EDIT BREAK INV TRU GRAPH CAPSLOCK UP EXTEND
            
            when X"B0" =>
               -- ; " , . UP DOWN LEFT RIGHT
               port_253b_dat <= i_KBD_EXTENDED_KEYS(8) & i_KBD_EXTENDED_KEYS(9) & i_KBD_EXTENDED_KEYS(10) & i_KBD_EXTENDED_KEYS(11) & i_KBD_EXTENDED_KEYS(1) & i_KBD_EXTENDED_KEYS(15 downto 13);
               
            when X"B1" =>
               -- DELETE EDIT BREAK INV TRU GRAPH CAPSLOCK EXTEND
               port_253b_dat <= i_KBD_EXTENDED_KEYS(12) & i_KBD_EXTENDED_KEYS(7 downto 2) & i_KBD_EXTENDED_KEYS(0);

            when X"C6" =>
               port_253b_dat <= ctc_int_en;
            
            when others =>
               port_253b_dat <= (others => '0');

         end case;

      end if;
   end process;

   ------------------------------------------------------------
   -- PS/2 KEYMAP & HOT KEYS ----------------------------------
   ------------------------------------------------------------
   
   process (i_CLK_28)
   begin
      if rising_edge(i_CLK_28) then
         if nr_28_we = '1' then
            nr_keymap_addr(8) <= nr_wr_dat(0);
         elsif nr_29_we = '1' then
            nr_keymap_addr(7 downto 0) <= nr_wr_dat;
         elsif nr_keymap_we = '1' then
            nr_keymap_addr <= nr_keymap_addr + 1;
         end if;
      end if;
   end process;

   process (i_CLK_28)
   begin
      if rising_edge(i_CLK_28) then
         if nr_2a_we = '1' then
            nr_keymap_dat_msb <= nr_wr_dat(0);
         end if;
      end if;
   end process;

   nr_keymap_we <= nr_2b_we;
   nr_keymap_dat <= nr_keymap_dat_msb & nr_wr_dat;

   -- Hot Keys
   
   process (i_CLK_28)
   begin
      if rising_edge(i_CLK_28) then
         hotkeys_1 <= hotkeys_0;
         hotkeys_0 <= i_SPKEY_FUNCTION(10 downto 1);
      end if;
   end process;

   hotkey_hard_reset <= hotkeys_0(1) and not hotkeys_1(1);                         -- F1
   hotkey_scandouble <= hotkeys_0(2) and not hotkeys_1(2);                         -- F2
   hotkey_5060 <= hotkeys_0(3) and not hotkeys_1(3);                               -- F3
   hotkey_soft_reset <= hotkeys_0(4) and not hotkeys_1(4);                         -- F4
   hotkey_expbus_enable <= hotkeys_0(5) and not hotkeys_1(5);                      -- F5
   hotkey_expbus_disable <= hotkeys_0(6) and not hotkeys_1(6);                     -- F6
   hotkey_scanlines <= hotkeys_0(7) and not hotkeys_1(7);                          -- F7
   hotkey_cpu_speed <= hotkeys_0(8) and not hotkeys_1(8);                          -- F8
   hotkey_m1 <= hotkeys_0(9) and not hotkeys_1(9);                                 -- F9
   hotkey_drive <= hotkeys_0(10) and not hotkeys_1(10) and port_divmmc_io_en;      -- F10

   nr_02_soft_reset <= hotkey_soft_reset or (nr_02_we and nr_wr_dat(0));
   nr_02_hard_reset <= hotkey_hard_reset or (nr_02_we and nr_wr_dat(1));

   ------------------------------------------------------------
   -- AUDIO ---------------------------------------------------
   ------------------------------------------------------------
   
   -- AY-8910 x 3 (turbosound)
   
   audio_ay_reset <= '1' when reset = '1' or nr_06_psg_mode = "11" else '0';
   
   turbosound_mod: entity work.turbosound
   port map
   (
      clock_i           => i_CLK_28,
      clock_en_i        => i_CLK_PSG_EN,
      
      reset_i           => audio_ay_reset,
      
      aymode_i          => nr_06_psg_mode(0),
      turbosound_en_i   => nr_08_psg_turbosound_en,
      
      psg_reg_addr_i    => port_fffd_wr,
      psg_reg_wr_i      => port_bffd_wr,
      psg_d_i           => cpu_do,
      psg_d_o           => psg_dat,
      
      mono_mode_i       => nr_09_psg_mono,
      stereo_mode_i     => nr_08_psg_stereo_mode,
   
--    port_a_i          => (others => '1'),   -- AYs have internal pullups
--    port_a_o          => open,
   
      pcm_ay_L_o        => pcm_ay_L,
      pcm_ay_R_o        => pcm_ay_R
   );

   process (i_CLK_CPU)
   begin
      if falling_edge(i_CLK_CPU) then
         port_fffd_dat <= psg_dat;
      end if;
   end process;

   -- todo: bit-banged 128 serial?
   -- for now only exposing R14 of AY#0 on port_a
   --
   -- I/O Port A from AY chip is connected to rs232 / keypad on the 128
   -- http://www.matthew-wilson.net/spectrum/rom/128_ROM0.pdf
   --
   -- Bit 0: KEYPAD CTS (out) - 0=Spectrum ready to receive, 1=Busy
   -- Bit 1: KEYPAD RXD (out) - 0=Transmit high bit, 1=Transmit low bit
   -- Bit 2: RS232 CTS (out) - 0=Spectrum ready to receive, 1=Busy
   -- Bit 3: RS232 RXD (out) - 0=Transmit high bit, 1=Transmit low bit
   -- Bit 4: KEYPAD DTR (in) - 0=Keypad ready for data, 1=Busy
   -- Bit 5: KEYPAD TXD (in) - 0=Receive high bit, 1=Receive low bit
   -- Bit 6: RS232 DTR (in) - 0=Device ready for data, 1=Busy
   -- Bit 7: RS232 TXD (in) - 0=Receive high bit, 1=Receive low bit

   -- DAC x 4 (soundrive, covox, specdrum, etc)
   
   soundrive_mod: entity work.soundrive
   port map
   (
      clock_i        => i_CLK_28,
      reset_i        => reset or not nr_08_dac_en,
      
      cpu_d_i        => cpu_do,
      
      -- left
      
      chA_wr_i       => port_dac_A_wr,
      chB_wr_i       => port_dac_B_wr,
      
      -- right
      
      chC_wr_i       => port_dac_C_wr,
      chD_wr_i       => port_dac_D_wr,

      -- nextreg mirrors
      
      nr_mono_we_i   => nr_2d_we,
      nr_left_we_i   => nr_2c_we,
      nr_right_we_i  => nr_2e_we,
      
      nr_audio_dat_i => nr_wr_dat,
      
      -- pcm audio out
      
      pcm_L_o        => pcm_dac_L,
      pcm_R_o        => pcm_dac_R
   );
   
   -- i2s pi audio
   
   i2s_mod : entity work.zx_i2s
   port map
   (
      i_reset        => reset or not pi_i2s_en,
      
      i_CLK          => i_CLK_28,
--    i_CLK_DIV      => nr_a3_pi_i2s_clkdiv,
      
--    i_slave_mode   => pi_i2s_slave,
      
      -- slave mode (incoming clock signals, synchronized)
      
      i_i2s_sck      => pi_si2s_sck,
      i_i2s_ws       => pi_si2s_ws,
      
      -- outgoing clock signals (master or slave)
      
      o_i2s_sck      => pi_mi2s_sck,
      o_i2s_ws       => pi_mi2s_ws,
      o_i2s_wsp      => open,
      
      -- zx next audio to pi
      
      i_audio_zxn_L  => pcm_audio_L,
      i_audio_zxn_R  => pcm_audio_R,
      o_i2s_sd_pi    => pi_i2s_sd_o,
      
      -- pi audio to zx next
      
      i_i2s_sd_pi    => pi_i2s_sd_i,
      o_audio_pi_L   => pi_i2s_audio_L,
      o_audio_pi_R   => pi_i2s_audio_R
   );

   -- todo: switch to signed audio
   -- todo: power of two volume adjustment on all inputs (?)
   
   port_fe_mic_final <= port_fe_mic xor i_AUDIO_EAR xor pi_fe_ear;
   internal_speaker_beep_exclusive <= nr_06_internal_speaker_beep and nr_08_internal_speaker_en;
   
   audio_mixer_mod: entity work.audio_mixer
   port map
   (
      clock_i        => i_CLK_28,
      reset_i        => reset,
      
      -- beeper and tape
      
      ear_i          => port_fe_ear and not internal_speaker_beep_exclusive,
      mic_i          => port_fe_mic_final and not internal_speaker_beep_exclusive,
      
      -- ay
      
      ay_L_i         => pcm_ay_L,
      ay_R_i         => pcm_ay_R,
      
      -- dac
      
      dac_L_i        => pcm_dac_L,
      dac_R_i        => pcm_dac_R,
      
      -- pi i2s audio
      
      pi_i2s_L_i     => pi_audio_L,
      pi_i2s_R_i     => pi_audio_R,
      
      -- mixed pcm audio out
      
      pcm_L_o        => pcm_audio_L,
      pcm_R_o        => pcm_audio_R
   );
   
   ------------------------------------------------------------
   -- VIDEO ---------------------------------------------------
   ------------------------------------------------------------
   
   -- The normal resolution pixel clock operates at 7MHz.  On the rising edge of i_CLK_7, the horizontal and vertical pixel counters
   -- are updated in the timing module.  Video output for that pixel position is expected to be generated before the next rising edge.
   --
   -- The high resolution pixel clock operates on the rising edge of the 14MHz clock i_CLK_14.  i_CLK_14 and i_CLK_7 are generated
   -- in phase by the top level pll module.  This means the rising edge of i_CLK_7 aligns with a rising edge of i_CLK_14.
   -- In hi-res, pixels are generated on every rising edge of i_CLK_14, ie two pixels are generated for every normal resolution pixel.
   --
   -- Sub-pixel timing at 28MHz is synchronized with i_CLK_7.  The sub-pixel counter counts 0-3 for each rising edge of i_CLK_28 inside
   -- a single i_CLK_7 period.  The transition from 3 to 0 corresponds to a rising edge of i_CLK_7.  Transitions from 3 to 0 and from
   -- 1 to 2 correspond to a rising edge of i_CLK_14.  ("sc")

   --
   -- VIDEO MEMORY
   --
   
   -- ULA BANK 5 (16k)
   -- the cpu/lores share access through one port and the ula/tilemap share the other
   -- ula contention is implemented by holding the cpu clock high in clock generation in the top level module

   bank5_ram: entity work.dpram2
   generic map (
      addr_width_g => 14,
      data_width_g => 8
   )
   port map (
      -- CPU port
      clk_a_i  => i_CLK_28,
      we_i     => cpu_bank5_sched and cpu_bank5_we,
      addr_a_i => vram_bank5_a0,
      data_a_i => cpu_do,
      data_a_o => vram_bank5_do0,
      -- ULA port
      clk_b_i  => i_CLK_28_n,
      addr_b_i => vram_bank_a1,
      data_b_o => vram_bank5_do1
   );
   
   -- Arbitrate cpu,lores on first port
   
   cpu_bank5_req <= cpu_bank5_rd or cpu_bank5_we;
   
   process (i_CLK_28)
   begin
      if rising_edge(i_CLK_28) then
         cpu_bank5_req_dly <= cpu_bank5_req;
         cpu_bank5_sched_dly <= cpu_bank5_sched;
      end if;
   end process;
   
   cpu_bank5_sched <= '1' when cpu_bank5_req_dly = '0' and cpu_bank5_req = '1' else '0';
   
   process (i_CLK_28)
   begin
      if falling_edge(i_CLK_28) then
         if cpu_bank5_sched_dly = '1' then
            cpu_bank5_do <= vram_bank5_do0;
         end if;
      end if;
   end process;
   
   process (i_CLK_28)
   begin
      if rising_edge(i_CLK_28) then
         if sc = "00" then    -- one 28MHz period past rising edge of i_CLK_7
            lores_vram_req <= '1';
         elsif lores_vram_ack = '1' then
            lores_vram_req <= '0';
         end if;
      end if;
   end process;
   
   process (i_CLK_28)
   begin
      if rising_edge(i_CLK_28) then
         lores_vram_ack_dly <= lores_vram_ack;
      end if;
   end process;
   
   process (i_CLK_28)
   begin
      if falling_edge(i_CLK_28) then
         if lores_vram_ack_dly = '1' then
            lores_vram_di <= vram_bank5_do0;
         end if;
      end if;
   end process;
   
   lores_vram_ack <= '1' when cpu_bank5_sched = '0' and lores_vram_req = '1' else '0'; 
   vram_bank5_a0 <= (sram_A20_A13(0) & cpu_a(12 downto 0)) when cpu_bank5_sched = '1' else lores_addr;
   
   -- Arbitrate ula,tilemap on second port in both banks 5 and 7
   
   ula_bank_req <= ula_vram_rd;
   
   process (i_CLK_28_n)
   begin
      if rising_edge(i_CLK_28_n) then
         ula_bank_req_dly <= ula_bank_req;
         ula_bank_sched_dly <= ula_bank_sched;
      end if;
   end process;
   
   ula_bank_sched <= '1' when ula_bank_req_dly = '0' and ula_bank_req = '1' else '0';
   
   process (i_CLK_28_n)
   begin
      if falling_edge(i_CLK_28_n) then
         if ula_bank_sched_dly = '1' then
            if ula_vram_shadow = '0' then
               ula_bank_do <= vram_bank5_do1;
            else
               ula_bank_do <= vram_bank7_do;
            end if;
         end if;
      end if;
   end process;

   vram_bank_a1 <= ula_vram_a when ula_bank_sched = '1' else tm_vram_a;
   ula_vram_di <= ula_bank_do;

   tm_vram_di <= vram_bank5_do1 when tm_mem_bank7 = '0' else vram_bank7_do;
   tm_vram_ack <= '1' when ula_bank_sched = '0' and tm_vram_rd = '1' else '0';
   
   -- ULA BANK 7 (8k only due to limited bram resources)
   -- cpu has access through one port and the ula/tilemap through the other.
   -- A consequence of only having the first 8k here is that the timex video modes cannot be placed in bank 7.
   
   bank7_ram: entity work.dpram2
   generic map (
      addr_width_g => 13,
      data_width_g => 8
   )
   port map (
      -- CPU port
      clk_a_i  => i_CLK_28,
      we_i     => cpu_bank7_we,
      addr_a_i => cpu_a(12 downto 0),
      data_a_i => cpu_do,
      data_a_o => cpu_bank7_do,
      -- ULA port
      clk_b_i  => i_CLK_28_n,
      addr_b_i => vram_bank_a1(12 downto 0),
      data_b_o => vram_bank7_do
   );

   --
   -- VIDEO TIMING & VBI/LINE INTERRUPT GENERATION
   --
   
   -- changes to video timing occur during vsync
   
   video_timing_change <= '1' when (eff_nr_05_5060 /= nr_05_5060) or (eff_nr_05_scandouble_en /= nr_05_scandouble_en) or ((eff_nr_03_machine_timing /= nr_03_machine_timing) and (nr_11_video_timing /= "111")) else '0';
   
   process (i_CLK_7)
   begin
      if rising_edge(i_CLK_7) then
         if reset_hard = '1' then
            video_timing_change_d <= '1';
         elsif rgb_vsync_n_o = '0' and video_timing_change = '1' then
            eff_nr_05_5060 <= nr_05_5060;
            eff_nr_05_scandouble_en <= nr_05_scandouble_en;
            eff_nr_03_machine_timing <= nr_03_machine_timing;
            video_timing_change_d <= '1';
         else
            video_timing_change_d <= '0';
         end if;
      end if;
   end process;
   
   process (i_CLK_7)
   begin
      if rising_edge(i_CLK_7) then
         if rgb_vsync_n_o = '0' then
            eff_nr_09_scanlines <= nr_09_scanlines;
         end if;
      end if;
   end process;

   ula_int_en <= (not port_ff_interrupt_disable) & nr_22_line_interrupt_en;

   timing_mod: entity work.zxula_timing
   port map (
      clock_i        => i_CLK_7,
      clock_x4_i     => i_CLK_28,
      reset_conter_i => video_timing_change_d,
      mode_i         => eff_nr_03_machine_timing,
      video_timing_i => nr_11_video_timing,
      vf50_60_i      => eff_nr_05_5060,
      cu_offset_i    => nr_64_copper_offset,
      hcount_o       => hc,
      vcount_o       => vc,
      phcount_o      => phc,
      whcount_o      => whc,
      wvcount_o      => wvc,
      cvcount_o      => cvc,
      sc_o           => sc,
      hsync_n_o      => rgb_hsync_n,
      vsync_n_o      => rgb_vsync_n,
      hblank_n_o     => rgb_hblank_n,
      vblank_n_o     => rgb_vblank_n,
      int_n_o        => ula_int_pulse_n,
      lint_ctrl_i    => ula_int_en,
      lint_line_i    => nr_23_line_interrupt
   );

   -- interrupt pulse duration is fixed at ~32 cpu cycles and must be asserted immediately

   process (i_CLK_28)
   begin
      -- int is sampled on rising edge of cpu clock
      if falling_edge(i_CLK_28) then
         if reset = '1' then
            ula_int_n <= '1';
         elsif ula_int_n = '1' then
            if ula_int_pulse_n = '0' or ctc_int_n = '0' then
               ula_int_n <= '0';
            end if;
         elsif ula_int_count_end = '1' then
            ula_int_n <= '1';
         end if;
      end if;
   end process;
   
   ula_int_count_end <= '1' when ula_int_count = "11111" else '0';
   
   process (i_CLK_CPU)
   begin
      if rising_edge(i_CLK_CPU) then
         if ula_int_n = '1' then
            ula_int_count <= (others => '0');
         elsif ula_int_count_end = '0' then
            ula_int_count <= ula_int_count + 1;
         end if;
      end if;
   end process;

   --
   -- VIDEO PIPELINE STAGE 0 - gather pixels
   -- Time = +0 (rising edge on i_CLK_7)
   --
   
   -- Hold pixel parameters constant for one pixel period
   
   process (i_CLK_7)
   begin
      if rising_edge(i_CLK_7) then

         lores_scroll_x_0 <= nr_32_lores_scrollx;
         lores_scroll_y_0 <= nr_33_lores_scrolly;
         
         ula_clip_x1_0 <= nr_1a_ula_clip_x1;
         ula_clip_x2_0 <= nr_1a_ula_clip_x2;
         ula_clip_y1_0 <= nr_1a_ula_clip_y1;
         
         if nr_1a_ula_clip_y2(7 downto 6) = "11" then
            ula_clip_y2_0 <= X"BF";
         else
            ula_clip_y2_0 <= nr_1a_ula_clip_y2;
         end if;
         
--       lores_clip_x1_0 <= nr_1d_lores_clip_x1;
--       lores_clip_x2_0 <= nr_1d_lores_clip_x2;
--       lores_clip_y1_0 <= nr_1d_lores_clip_y1;
--       
--       if nr_1d_lores_clip_y2(7 downto 6) = "11" then
--          lores_clip_y2_0 <= X"BF";
--       else
--          lores_clip_y2_0 <= nr_1d_lores_clip_y2;
--       end if;

         lores_mode_0 <= nr_6a_lores_radastan;
         lores_dfile_0 <= port_ff_screen_mode(0) xor nr_6a_lores_radastan_xor;   -- radastan can coexist with standard timex display files
         lores_palette_offset_0 <= nr_6a_lores_palette_offset;

         layer_priorities_0 <= nr_15_layer_priority;
         
      end if;
   end process;

   process (i_CLK_14)
   begin
      if rising_edge(i_CLK_14) then
         if sc(0) = '1' then
            
            ula_en_0 <= nr_68_ula_en;
            ula_stencil_mode_0 <= nr_68_ula_stencil_mode;
            ula_blend_mode_0 <= nr_68_blend_mode;

            ulanext_en_0 <= nr_43_ulanext_en;
            ulanext_format_0 <= nr_42_ulanext_format;
            ulap_en_0 <= port_ff3b_ulap_en;

            lores_en_0 <= nr_15_lores_en;

            sprite_en_0 <= nr_15_sprite_en;
            tm_en_0 <= nr_6b_tm_en;

            transparent_rgb_0 <= nr_14_global_transparent_rgb;
            fallback_rgb_0 <= nr_4a_fallback_rgb;
      
            ula_palette_select_0 <= nr_43_active_ula_palette;
            tm_palette_select_0 <= nr_6b_tm_control(4);
            layer2_palette_select_0 <= nr_43_active_layer2_palette;
            sprite_palette_select_0 <= nr_43_active_sprite_palette;
         
         end if;
      end if;
   end process;

   -- Pixels are generated by modules
   -- ...
   
   -- Hold pixel values for next stage of pipeline
   
   process (i_CLK_7)
   begin
      if rising_edge(i_CLK_7) then
      
         lores_pixel_1 <= lores_pixel;
         lores_pixel_en_1a <= lores_pixel_en;

         layer2_pixel_en_1 <= layer2_pixel_en;
         
         sprite_pixel_1 <= sprite_pixel;
         sprite_pixel_en_1a <= sprite_pixel_en;

      end if;
   end process;
   
   process (i_CLK_14)
   begin
      if rising_edge(i_CLK_14) then

         ula_pixel_1 <= ula_pixel;
         ula_select_bgnd_1 <= ula_select_bgnd;

         tm_pixel_1 <= tm_pixel;
         tm_pixel_en_1 <= tm_pixel_en;
         tm_pixel_below_1 <= (tm_pixel_below and tm_en_1a) or ((not nr_6b_tm_control(0)) and not tm_en_1a);
         tm_pixel_textmode_1 <= tm_pixel_textmode;

         layer2_pixel_1 <= layer2_pixel;
         
      end if;
   end process;

   -- Hold video parameters for next stage of pipeline
   
   process (i_CLK_7)
   begin
      if rising_edge(i_CLK_7) then

         ula_border_1 <= ula_border;
         ula_clipped_1 <= ula_clipped;

         layer_priorities_1 <= layer_priorities_0;

         rgb_vsync_n_1 <= rgb_vsync_n;
         rgb_vblank_n_1 <= rgb_vblank_n;
         rgb_hblank_n_1 <= rgb_hblank_n;
         rgb_hsync_n_1 <= rgb_hsync_n;
      
      end if;
   end process;

   process (i_CLK_14)
   begin
      if rising_edge(i_CLK_14) then
      
         ula_en_1 <= ula_en_1a;
         ula_en_1a <= ula_en_0;
         
         ula_stencil_mode_1 <= ula_stencil_mode_1a;
         ula_stencil_mode_1a <= ula_stencil_mode_0;
         
         ula_blend_mode_1 <= ula_blend_mode_1a;
         ula_blend_mode_1a <= ula_blend_mode_0;
         
         lores_en_1 <= lores_en_1a;
         lores_en_1a <= lores_en_0;
         
         sprite_en_1 <= sprite_en_1a;
         sprite_en_1a <= sprite_en_0;
         
         tm_en_1 <= tm_en_1a;
         tm_en_1a <= tm_en_0;
         
         transparent_rgb_1 <= transparent_rgb_1a;
         transparent_rgb_1a <= transparent_rgb_0;
         
         fallback_rgb_1 <= fallback_rgb_1a;
         fallback_rgb_1a <= fallback_rgb_0;

         ula_palette_select_1 <= ula_palette_select_1a;
         ula_palette_select_1a <= ula_palette_select_0;
         
         tm_palette_select_1 <= tm_palette_select_1a;
         tm_palette_select_1a <= tm_palette_select_0;
         
         layer2_palette_select_1 <= layer2_palette_select_1a;
         layer2_palette_select_1a <= layer2_palette_select_0;
         
         sprite_palette_select_1 <= sprite_palette_select_1a;
         sprite_palette_select_1a <= sprite_palette_select_0;
   
      end if;
   end process;
   
   lores_pixel_en_1 <= lores_pixel_en_1a and lores_en_1;
   sprite_pixel_en_1 <= sprite_pixel_en_1a and sprite_en_1;
   
   --
   -- VIDEO PIPELINE STAGE 1 - palette lookup
   -- Time = +1 (i_CLK_7)
   --

   -- Pixel data from ula / lores, tilemap, sprites, layer 2 is passed through palette memory to
   -- generate 9-bit rgb values.
   --
   -- The ula / tilemap share one 1k x 9 memory to save on bram resources.  These are hi-res pixels.
   -- Sprites / layer 2 share one 1k x 16 memory to accommodate layer order promotion bits.  These are lo-res pixels.
   --
   -- Memory is edge triggered write, read edge triggered with data coming out a short time later
   
   -- todo: move extra bit in 1k x 16 memory to lut to free up a bram
   -- todo: investigate giving every layer priority bits

   nr_palette_index <= nr_43_palette_write_select(1) & nr_43_palette_write_select(2) & nr_palette_idx;
   nr_palette_dat <= (nr_ulatm_palette_dat(15 downto 14) & nr_ulatm_palette_dat(8 downto 0)) when (nr_43_palette_write_select(1) = nr_43_palette_write_select(0)) else (nr_l2s_palette_dat(15 downto 14) & nr_l2s_palette_dat(8 downto 0));
   
   -- ULA / Tilemap palette
   
   nr_ulatm_we <= (nr_palette_we and not (nr_43_palette_write_select(1) xor nr_43_palette_write_select(0))) or nr_ff_we;
   nr_palette_index_utm <= ('0' & nr_43_palette_write_select(2) & "11" & port_bf3b_ulap_index) when (ulap_palette_rd = '1' or nr_ff_we = '1') else nr_palette_index;
   
   palette_utm: entity work.dpram2
   generic map 
   (
      addr_width_g  => 10,
      data_width_g  => 16
   )
   port map 
   (
      -- nextreg write
      clk_a_i  => i_CLK_28,
      we_i     => nr_ulatm_we,
      addr_a_i => nr_palette_index_utm,
      data_a_i => nr_palette_priority & "00000" & nr_palette_value,
      data_a_o => nr_ulatm_palette_dat,
      -- ula / tm
      clk_b_i  => i_CLK_28_n,
      addr_b_i => ulatm_pixel_1,
      data_b_o => ulatm_rgb_1
   );
   
   ulalores_pixel_1 <= lores_pixel_1 when lores_pixel_en_1 = '1' else ula_pixel_1;
   ulatm_pixel_1 <= ('0' & ula_palette_select_1 & ulalores_pixel_1) when sc(0) = '0' else ('1' & tm_palette_select_1 & tm_pixel_1);
   
   process (i_CLK_28)
   begin
      if rising_edge(i_CLK_28) then
         if sc(0) = '0' then
            if lores_pixel_en_1 = '1' or ula_select_bgnd_1 = '0' then
               ula_rgb_1 <= ulatm_rgb_1(8 downto 0);
            else
               ula_rgb_1 <= fallback_rgb_1 & (fallback_rgb_1(1) or fallback_rgb_1(0));
            end if;
         end if;
      end if;
   end process;

   -- send rgb to next stage
   
   process (i_CLK_14)
   begin
      if rising_edge(i_CLK_14) then
         ula_rgb_2 <= ula_rgb_1;
         tm_rgb_2 <= ulatm_rgb_1(8 downto 0);
      end if;
   end process;
   
-- lores_rgb_2 <= ula_rgb_2;
   
   -- Layer 2 / Sprite palette
   -- move the extra layer priority bits to lut ram if possible

   nr_l2s_palette_we <= nr_palette_we and (nr_43_palette_write_select(1) xor nr_43_palette_write_select(0));
   
   palette_l2s: entity work.dpram2
   generic map 
   (
      addr_width_g  => 10,
      data_width_g  => 16
   )
   port map 
   (
      -- nextreg write
      clk_a_i  => i_CLK_28,
      we_i     => nr_l2s_palette_we,
      addr_a_i => nr_palette_index,
      data_a_i => nr_palette_priority & "00000" & nr_palette_value,
      data_a_o => nr_l2s_palette_dat,
      -- layer 2 / sprite
      clk_b_i  => i_CLK_28_n,
      addr_b_i => l2s_pixel_1,
      data_b_o => l2s_prgb_1
   );
   
   l2s_pixel_1 <= ('0' & layer2_palette_select_1 & layer2_pixel_1) when sc(0) = '0' else ('1' & sprite_palette_select_1 & sprite_pixel_1);
   
   process (i_CLK_28)
   begin
      if rising_edge(i_CLK_28) then
         if sc(0) = '0' then
            layer2_prgb_1 <= l2s_prgb_1(15) & l2s_prgb_1(8 downto 0);
         end if;
      end if;
   end process;
   
   -- send prgb to next stage
   
   process (i_CLK_14)
   begin
      if rising_edge(i_CLK_14) then
         layer2_rgb_2 <= layer2_prgb_1(8 downto 0);
         layer2_priority_2 <= layer2_prgb_1(9);
         sprite_rgb_2 <= l2s_prgb_1(8 downto 0);
      end if;
   end process;

   -- Hold video parameters for next stage of pipeline
   
   process (i_CLK_14)
   begin
      if rising_edge(i_CLK_14) then
      
         ula_en_2 <= ula_en_1;
         ula_border_2 <= ula_border_1;
         ula_clipped_2 <= ula_clipped_1 and not lores_pixel_en_1;
         ula_stencil_mode_2 <= ula_stencil_mode_1;
         ula_blend_mode_2 <= ula_blend_mode_1;
      
--       lores_en_2 <= lores_pixel_en_1;
         
         tm_en_2 <= tm_en_1;
         tm_pixel_en_2 <= tm_pixel_en_1;
         tm_pixel_below_2 <= tm_pixel_below_1;
         tm_pixel_textmode_2 <= tm_pixel_textmode_1;
         
         layer2_pixel_en_2 <= layer2_pixel_en_1;
         
         sprite_pixel_en_2 <= sprite_pixel_en_1;
         
         transparent_rgb_2 <= transparent_rgb_1;
         fallback_rgb_2 <= fallback_rgb_1;
      
         layer_priorities_2 <= layer_priorities_1;
         
         rgb_vsync_n_2 <= rgb_vsync_n_1;
         rgb_vblank_n_2 <= rgb_vblank_n_1;
         rgb_hblank_n_2 <= rgb_hblank_n_1;
         rgb_hsync_n_2 <= rgb_hsync_n_1;
      
      end if;
   end process;
   
   --
   -- VIDEO PIPELINE STAGE 2 - final pixel generation
   -- Time = +1.5 (i_CLK_7) = +3 (i_CLK_14)
   -- Now synchronized to i_CLK_14, important for retiming at next stage
   --

   -- stop pretending lores and ula are separate
   -- only one of these can get a colour, the ula contains the lores colour when lores is active
   
   ula_mix_transparent <= '1' when (ula_rgb_2(8 downto 1) = transparent_rgb_2) or (ula_clipped_2 = '1') else '0';
   ula_mix_rgb <= ula_rgb_2 when ula_mix_transparent = '0' else "000000000";
   
   ula_transparent <= '1' when (ula_mix_transparent = '1') or (ula_en_2 = '0') else '0';
   ula_rgb <= ula_rgb_2 when ula_transparent = '0' else "000000000";
   
-- lores_transparent <= '1' when (lores_rgb_2(8 downto 1) = transparent_rgb_2) or (ula_clipped_2 = '1') else '0';
-- lores_rgb <= lores_rgb_2 when lores_transparent = '0' else "000000000";

   tm_transparent <= '1' when (tm_pixel_en_2 = '0') or (tm_pixel_textmode_2 = '1' and tm_rgb_2(8 downto 1) = transparent_rgb_2) or (tm_en_2 = '0') else '0';
   tm_rgb <= tm_rgb_2 when tm_transparent = '0' else "000000000";
   
   stencil_transparent <= '1' when (ula_transparent = '1') or (tm_transparent = '1') else '0';
   stencil_rgb <= (ula_rgb and tm_rgb) when stencil_transparent = '0' else "000000000";
   
   ulatm_transparent <= '1' when (ula_transparent = '1') and (tm_transparent = '1') else '0';
   ulatm_rgb <= tm_rgb when (tm_transparent = '0') and (tm_pixel_below_2 = '0' or ula_transparent = '1') else ula_rgb;
   
   sprite_transparent <= not sprite_pixel_en_2;
   sprite_rgb <= sprite_rgb_2 when sprite_transparent = '0' else "000000000";
   
   layer2_transparent <= '1' when (layer2_rgb_2(8 downto 1) = transparent_rgb_2) or (layer2_pixel_en_2 = '0') else '0';
   layer2_rgb <= layer2_rgb_2 when layer2_transparent = '0' else "000000000";
   layer2_priority <= layer2_priority_2 when layer2_transparent = '0' else '0';

   process (ula_stencil_mode_2, ula_en_2, tm_en_2, stencil_rgb, stencil_transparent, ulatm_rgb, ulatm_transparent)
   begin
--    if lores_en_2 = '1' and lores_transparent = '0' then
--       ula_final_rgb <= lores_rgb;
--       ula_final_transparent <= lores_transparent;
      if ula_stencil_mode_2 = '1' and ula_en_2 = '1' and tm_en_2 = '1' then
         ula_final_rgb <= stencil_rgb;
         ula_final_transparent <= stencil_transparent;
      else
         ula_final_rgb <= ulatm_rgb;
         ula_final_transparent <= ulatm_transparent;
      end if;
   end process;

   process (ula_blend_mode_2, ula_mix_transparent, ula_mix_rgb, ula_final_transparent, ula_final_rgb, tm_transparent, tm_rgb, tm_pixel_below_2, ula_transparent, ula_rgb, layer_priorities_2)
   begin
      case ula_blend_mode_2 is
         when "00" =>
            mix_rgb <= ula_mix_rgb;
            mix_rgb_transparent <= ula_mix_transparent;
            mix_top_transparent <= tm_transparent or tm_pixel_below_2;
            mix_top_rgb <= tm_rgb;
            mix_bot_transparent <= tm_transparent or not tm_pixel_below_2;
            mix_bot_rgb <= tm_rgb;
         when "10" => 
            mix_rgb <= ula_final_rgb;
            mix_rgb_transparent <= ula_final_transparent;
            mix_top_transparent <= '1';
            mix_top_rgb <= tm_rgb;
            mix_bot_transparent <= '1';
            mix_bot_rgb <= tm_rgb;
         when "11" =>
            mix_rgb <= tm_rgb;
            mix_rgb_transparent <= tm_transparent;
            mix_top_transparent <= ula_transparent or not tm_pixel_below_2;
            mix_top_rgb <= ula_rgb;
            mix_bot_transparent <= ula_transparent or tm_pixel_below_2;
            mix_bot_rgb <= ula_rgb;
         when others =>
            mix_rgb <= (others => '0');
            mix_rgb_transparent <= '1';
            if tm_pixel_below_2 = '1' then
               mix_top_transparent <= ula_transparent;
               mix_top_rgb <= ula_rgb;
               mix_bot_transparent <= tm_transparent;
               mix_bot_rgb <= tm_rgb;
            else
               mix_top_transparent <= tm_transparent;
               mix_top_rgb <= tm_rgb;
               mix_bot_transparent <= ula_transparent;
               mix_bot_rgb <= ula_rgb;
            end if;
      end case;
   end process;

   -- Implement SLU Ordering
   -- todo: insert layer priority shuffle-memory

   -- in:
   --   ula_final_rgb: layer U colour
   --   ula_final_transparent: layer U transparent
   --   mix_rgb: layer U colour for modes 6 & 7
   --   sprite_rgb: layer S colour
   --   sprite_transparent: layer S transparent
   --   layer2_rgb: layer L colour
   --   layer2_transparent: layer L transparent
   --   layer2_priority: layer L promotion bit and non-transparent

   process (layer2_rgb, mix_rgb, fallback_rgb_2, layer_priorities_2, layer2_priority, sprite_transparent, sprite_rgb,
            layer2_transparent, ula_final_transparent, ula_final_rgb, ula_border_2, tm_transparent,
            mix_top_transparent, mix_top_rgb, mix_bot_transparent, mix_bot_rgb, mix_rgb_transparent)
      variable mixer_r_t         : std_logic_vector(3 downto 0);
      variable mixer_g_t         : std_logic_vector(3 downto 0);
      variable mixer_b_t         : std_logic_vector(3 downto 0);
   begin
   
      mixer_r_t := ('0' & layer2_rgb(8 downto 6)) + ('0' & mix_rgb(8 downto 6));
      mixer_g_t := ('0' & layer2_rgb(5 downto 3)) + ('0' & mix_rgb(5 downto 3));
      mixer_b_t := ('0' & layer2_rgb(2 downto 0)) + ('0' & mix_rgb(2 downto 0));
   
      -- Layer priorities - nextreg 0x15 bits 4-2
      
      -- 000 S L U
      -- 001 L S U
      -- 010 S U L
      -- 011 L U S
      -- 100 U S L
      -- 101 U L S
      
      rgb_out_2 <= fallback_rgb_2 & (fallback_rgb_2(1) or fallback_rgb_2(0));
      
      case layer_priorities_2 is
      
         when "000" =>  -- SLU
         
            if layer2_priority = '1' then
               rgb_out_2 <= layer2_rgb;
            elsif sprite_transparent = '0' then
               rgb_out_2 <= sprite_rgb;
            elsif layer2_transparent = '0' then
               rgb_out_2 <= layer2_rgb;
            elsif ula_final_transparent = '0' then
               rgb_out_2 <= ula_final_rgb;
            end if;
         
         when "001" =>  -- LSU
         
            if layer2_transparent = '0' then 
               rgb_out_2 <= layer2_rgb;
            elsif sprite_transparent = '0' then
               rgb_out_2 <= sprite_rgb;
            elsif ula_final_transparent = '0' then
               rgb_out_2 <= ula_final_rgb;
            end if;
         
         when "010" =>  -- SUL

            if layer2_priority = '1' then
               rgb_out_2 <= layer2_rgb;
            elsif sprite_transparent = '0' then
               rgb_out_2 <= sprite_rgb;
            elsif ula_final_transparent = '0' then
               rgb_out_2 <= ula_final_rgb;
            elsif layer2_transparent = '0' then
               rgb_out_2 <= layer2_rgb;
            end if;

         when "011" =>  -- LUS
         
            if layer2_transparent = '0' then
               rgb_out_2 <= layer2_rgb;
            elsif ula_final_transparent = '0' and not (ula_border_2 = '1' and tm_transparent = '1' and sprite_transparent = '0') then
               rgb_out_2 <= ula_final_rgb;
            elsif sprite_transparent = '0' then
               rgb_out_2 <= sprite_rgb;
            end if;
         
         when "100" =>  -- USL
         
            if layer2_priority = '1' then
               rgb_out_2 <= layer2_rgb;
            elsif ula_final_transparent = '0' and not (ula_border_2 = '1' and tm_transparent = '1' and sprite_transparent = '0') then
               rgb_out_2 <= ula_final_rgb;
            elsif sprite_transparent = '0' then
               rgb_out_2 <= sprite_rgb;
            elsif layer2_transparent = '0' then
               rgb_out_2 <= layer2_rgb;
            end if;
         
         when "101" =>  -- ULS
         
            if layer2_priority = '1' then
               rgb_out_2 <= layer2_rgb;
            elsif ula_final_transparent = '0' and not (ula_border_2 = '1' and tm_transparent = '1' and sprite_transparent = '0') then
               rgb_out_2 <= ula_final_rgb;
            elsif layer2_transparent = '0' then
               rgb_out_2 <= layer2_rgb;
            elsif sprite_transparent = '0' then
               rgb_out_2 <= sprite_rgb;
            end if;
         
         when "110" =>  -- (U|T)S(T|U)(B+L)
         
            if mixer_r_t(3) = '1' then  -- greater than 7
               mixer_r_t := "0111";
            end if;
            
            if mixer_g_t(3) = '1' then  -- greater than 7
               mixer_g_t := "0111";
            end if;
            
            if mixer_b_t(3) = '1' then  -- greater than 7
               mixer_b_t := "0111";
            end if;
            
            if layer2_priority = '1' then
               rgb_out_2 <= mixer_r_t(2 downto 0) & mixer_g_t(2 downto 0) & mixer_b_t(2 downto 0);
            elsif mix_top_transparent = '0' then
               rgb_out_2 <= mix_top_rgb;
            elsif sprite_transparent = '0' then
               rgb_out_2 <= sprite_rgb;
            elsif mix_bot_transparent = '0' then
               rgb_out_2 <= mix_bot_rgb;
            elsif layer2_transparent = '0' then
               rgb_out_2 <= mixer_r_t(2 downto 0) & mixer_g_t(2 downto 0) & mixer_b_t(2 downto 0);
            end if;

         when others =>  -- (U|T)S(T|U)(B+L-5)
         
            if mix_rgb_transparent = '0' then
            
               if mixer_r_t <= 4 then
                  mixer_r_t := "0000";
               elsif mixer_r_t(3 downto 2) = "11" then
                  mixer_r_t := "0111";
               else
                  mixer_r_t := mixer_r_t + "1011";  -- minus 5
               end if;
            
               if mixer_g_t <= 4 then
                  mixer_g_t := "0000";
               elsif mixer_g_t(3 downto 2) = "11" then
                  mixer_g_t := "0111";
               else
                  mixer_g_t := mixer_g_t + "1011";  -- minus 5
               end if;
               
               if mixer_b_t <= 4 then
                  mixer_b_t := "0000";
               elsif mixer_b_t(3 downto 2) = "11" then
                  mixer_b_t := "0111";
               else
                  mixer_b_t := mixer_b_t + "1011";  -- minus 5
               end if;
            
            end if;
            
            if layer2_priority = '1' then
               rgb_out_2 <= mixer_r_t(2 downto 0) & mixer_g_t(2 downto 0) & mixer_b_t(2 downto 0);
            elsif mix_top_transparent = '0' then
               rgb_out_2 <= mix_top_rgb;
            elsif sprite_transparent = '0' then
               rgb_out_2 <= sprite_rgb;
            elsif mix_bot_transparent = '0' then
               rgb_out_2 <= mix_bot_rgb;
            elsif layer2_transparent = '0' then
               rgb_out_2 <= mixer_r_t(2 downto 0) & mixer_g_t(2 downto 0) & mixer_b_t(2 downto 0);
            end if;
         
      end case;

   end process;

   rgb_out_2a <= (others => '0') when (rgb_vblank_n_2 = '0' or rgb_hblank_n_2 = '0') else rgb_out_2;
   
   --
   -- VIDEO PIPELINE STAGE 3 - generate rgb signals
   -- Add three cycle delay so that xst can retime registers backward into stage 2
   --

   process (i_CLK_14)
   begin
      if rising_edge(i_CLK_14) then

         rgb_vsync_n_6 <= rgb_vsync_n_5;
         rgb_vsync_n_5 <= rgb_vsync_n_4;
         rgb_vsync_n_4 <= rgb_vsync_n_3;
         rgb_vsync_n_3 <= rgb_vsync_n_2;

         rgb_vblank_n_6 <= rgb_vblank_n_5;
         rgb_vblank_n_5 <= rgb_vblank_n_4;
         rgb_vblank_n_4 <= rgb_vblank_n_3;
         rgb_vblank_n_3 <= rgb_vblank_n_2;

         rgb_hblank_n_6 <= rgb_hblank_n_5;
         rgb_hblank_n_5 <= rgb_hblank_n_4;
         rgb_hblank_n_4 <= rgb_hblank_n_3;
         rgb_hblank_n_3 <= rgb_hblank_n_2;

         rgb_hsync_n_6 <= rgb_hsync_n_5;
         rgb_hsync_n_5 <= rgb_hsync_n_4;
         rgb_hsync_n_4 <= rgb_hsync_n_3;
         rgb_hsync_n_3 <= rgb_hsync_n_2;

         rgb_out_6 <= rgb_out_5;
         rgb_out_5 <= rgb_out_4;
         rgb_out_4 <= rgb_out_3;
         rgb_out_3 <= rgb_out_2a;

      end if;
   end process;

   process (i_CLK_28)
   begin
      if falling_edge(i_CLK_28) then
      
         rgb_vsync_n_7 <= rgb_vsync_n_6;
         rgb_vblank_n_7 <= rgb_vblank_n_6;
         rgb_hblank_n_7 <= rgb_hblank_n_6;
         rgb_hsync_n_7 <= rgb_hsync_n_6;
         rgb_out_7 <= rgb_out_6;
      
      end if;
   end process;
   
   rgb_vsync_n_o <= rgb_vsync_n_7;
   rgb_vblank_n_o <= rgb_vblank_n_7;
   rgb_hblank_n_o <= rgb_hblank_n_7;
   rgb_hsync_n_o <= rgb_hsync_n_7;
   rgb_out_o <= rgb_out_7;
   rgb_csync_n_o <= rgb_vsync_n_7 and rgb_hsync_n_7;

end architecture;
