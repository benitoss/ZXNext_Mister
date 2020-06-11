///////////////////////////////////////////////////////////////////////////////
//    
//    Company:          Xilinx
//    Engineer:         Karl Kurbjun and Carl Ribbing
//    Date:             2/19/2009
//    Design Name:      PLL DRP
//    Module Name:      top.v
//    Version:          1.0
//    Target Devices:   Spartan 6 Family
//    Tool versions:    L.68 (lin)
//    Description:      This is a basic demonstration of the PLL_DRP 
//                      connectivity to the PLL_ADV.
// 
//    Disclaimer:  XILINX IS PROVIDING THIS DESIGN, CODE, OR
//                 INFORMATION "AS IS" SOLELY FOR USE IN DEVELOPING
//                 PROGRAMS AND SOLUTIONS FOR XILINX DEVICES.  BY
//                 PROVIDING THIS DESIGN, CODE, OR INFORMATION AS
//                 ONE POSSIBLE IMPLEMENTATION OF THIS FEATURE,
//                 APPLICATION OR STANDARD, XILINX IS MAKING NO
//                 REPRESENTATION THAT THIS IMPLEMENTATION IS FREE
//                 FROM ANY CLAIMS OF INFRINGEMENT, AND YOU ARE
//                 RESPONSIBLE FOR OBTAINING ANY RIGHTS YOU MAY
//                 REQUIRE FOR YOUR IMPLEMENTATION.  XILINX
//                 EXPRESSLY DISCLAIMS ANY WARRANTY WHATSOEVER WITH
//                 RESPECT TO THE ADEQUACY OF THE IMPLEMENTATION,
//                 INCLUDING BUT NOT LIMITED TO ANY WARRANTIES OR
//                 REPRESENTATIONS THAT THIS IMPLEMENTATION IS FREE
//                 FROM CLAIMS OF INFRINGEMENT, IMPLIED WARRANTIES
//                 OF MERCHANTABILITY AND FITNESS FOR A PARTICULAR
//                 PURPOSE.
// 
//                 (c) Copyright 2008 Xilinx, Inc.
//                 All rights reserved.
// 
///////////////////////////////////////////////////////////////////////////////

`timescale 1ps/1ps

module pll_top 
   (
      // SSTEP is the input to start a reconfiguration.  It should only be
      // pulsed for one clock cycle.
      input    SSTEP,
      // STATE determines which state the PLL_ADV will be reconfigured to.  A 
      // value of 0 correlates to state 1, and a value of 1 correlates to state 
      // 2.
      input   [2:0] STATE,

      // RST will reset the entire reference design including the PLL_ADV
      input    RST,

      // CLKIN is the input clock that feeds the PLL_ADV CLKIN as well as the
      // clock for the PLL_DRP module
      input    CLKIN,

      // SRDY pulses for one clock cycle after the PLL_ADV is locked and the 
      // PLL_DRP module is ready to start another re-configuration
      output   SRDY,
      
      // These are the clock outputs from the PLL_ADV.
      output   CLK0OUT,
      output   CLK1OUT,
      output   CLK2OUT,
      output   CLK3OUT,
      output   CLK4OUT,
      output   CLK5OUT
   );
   
   // These signals are used as direct connections between the PLL_ADV and the
   // PLL_DRP.
   wire [15:0]    di;
// wire [6:0]     daddr;
   wire [4:0]     daddr;
   wire [15:0]    dout;
   wire           den;
   wire           dwe;
   wire           dclk;
   wire           rst_pll;
   wire           drdy;
   wire           locked;
   
   // These signals are used for the BUFG's necessary for the design.
   wire           clkin_bufgout;
   
   wire           clkfb_bufgout;
   wire           clkfb_bufgin;
   
   wire           clk0_bufgin;
   wire           clk0_bufgout;
   
   wire           clk1_bufgin;
   wire           clk1_bufgout;
   
   wire           clk2_bufgin;
   wire           clk2_bufgout;
   
   wire           clk3_bufgin;
   wire           clk3_bufgout;
   
   wire           clk4_bufgin;
   wire           clk4_bufgout;
   
   wire           clk5_bufgin;
   wire           clk5_bufgout; 

   // Global buffers used in design
//   BUFG BUFG_IN (
//      .O(clkin_bufgout),
//     .I(CLKIN) 
//   );
assign clkin_bufgout = CLKIN;
   
   BUFG BUFG_FB (
      .O(clkfb_bufgout),
      .I(clkfb_bufgin) 
   );
   
   BUFG BUFG_CLK0 (
      .O(CLK0OUT),
      .I(clk0_bufgin) 
   );
   
   BUFG BUFG_CLK1 (
      .O(CLK1OUT),
      .I(clk1_bufgin) 
   );
   
   BUFG BUFG_CLK2 (
      .O(CLK2OUT),
      .I(clk2_bufgin) 
   );
   
   BUFG BUFG_CLK3 (
      .O(CLK3OUT),
      .I(clk3_bufgin) 
   );
   
   BUFG BUFG_CLK4 (
      .O(CLK4OUT),
      .I(clk4_bufgin) 
   );
   
   BUFG BUFG_CLK5 (
      .O(CLK5OUT),
      .I(clk5_bufgin) 
   );
   
   // PLL_ADV that reconfiguration will take place on
   PLL_ADV #(
     .SIM_DEVICE("SPARTAN6"),
      .DIVCLK_DIVIDE(1), // 1 to 52
      
      .BANDWIDTH("LOW"), // "HIGH", "LOW" or "OPTIMIZED"
      
      // CLKFBOUT stuff
      .CLKFBOUT_MULT(14), 
      .CLKFBOUT_PHASE(0.0),
      
      // Set the clock period (ns) of input clocks and reference jitter
      .REF_JITTER(0.100),
      .CLKIN1_PERIOD(20.000),
      .CLKIN2_PERIOD(20.000), 

      // CLKOUT parameters:
      // DIVIDE: (1 to 128)
      // DUTY_CYCLE: (0.01 to 0.99) - This is dependent on the divide value.
      // PHASE: (0.0 to 360.0) - This is dependent on the divide value.
      .CLKOUT0_DIVIDE(25),
      .CLKOUT0_DUTY_CYCLE(0.5),
      .CLKOUT0_PHASE(0.0), 
      
      .CLKOUT1_DIVIDE(25), 
      .CLKOUT1_DUTY_CYCLE(0.5),
      .CLKOUT1_PHASE(180.0), 
      
      .CLKOUT2_DIVIDE(50),
      .CLKOUT2_DUTY_CYCLE(0.5),
      .CLKOUT2_PHASE(0.0),
      
      .CLKOUT3_DIVIDE(100),
      .CLKOUT3_DUTY_CYCLE(0.5),
      .CLKOUT3_PHASE(0.0),
      
      .CLKOUT4_DIVIDE(5),
      .CLKOUT4_DUTY_CYCLE(0.5),
      .CLKOUT4_PHASE(0.0), 
      
      .CLKOUT5_DIVIDE(5),
      .CLKOUT5_DUTY_CYCLE(0.5),
      .CLKOUT5_PHASE(180.0),
      
      // Set the compensation
      .COMPENSATION("SYSTEM_SYNCHRONOUS"),
      
      // PMCD stuff (not used)
      .EN_REL("FALSE"),
      .PLL_PMCD_MODE("FALSE"),
      .RST_DEASSERT_CLK("CLKIN1")
   ) PLL_ADV_inst (
      .CLKFBDCM(),
      .CLKFBOUT(clkfb_bufgin),
      
      // CLK outputs
      .CLKOUT0(clk0_bufgin),
      .CLKOUT1(clk1_bufgin),
      .CLKOUT2(clk2_bufgin),
      .CLKOUT3(clk3_bufgin),
      .CLKOUT4(clk4_bufgin),
      .CLKOUT5(clk5_bufgin),
      
      // CLKOUTS to DCM
      .CLKOUTDCM0(),
      .CLKOUTDCM1(),
      .CLKOUTDCM2(), 
      .CLKOUTDCM3(),
      .CLKOUTDCM4(),
      .CLKOUTDCM5(), 
      
      // DRP Ports
      .DO(dout),
      .DRDY(drdy), 
      .DADDR(daddr), 
      .DCLK(dclk),
      .DEN(den),
      .DI(di),
      .DWE(dwe),
      
      .LOCKED(locked),
      .CLKFBIN(clkfb_bufgout),
      
      // Clock inputs
      .CLKIN1(CLKIN), 
      .CLKIN2(1'b0),
      .CLKINSEL(1'b1),
      
      .REL(1'b0),
      .RST(rst_pll)
   );
   
   // PLL_DRP instance that will perform the reconfiguration operations
   pll_drp #(
   
      //***********************************************************************
      .S1_CLKFBOUT_MULT(28),
      .S1_CLKFBOUT_PHASE(0),
      .S1_BANDWIDTH("LOW"),
      .S1_DIVCLK_DIVIDE(2),

      .S1_CLKOUT0_DIVIDE(25),
      .S1_CLKOUT0_PHASE(0),
      .S1_CLKOUT0_DUTY(50000),

      .S1_CLKOUT1_DIVIDE(25),
      .S1_CLKOUT1_PHASE(180000),
      .S1_CLKOUT1_DUTY(50000),

      .S1_CLKOUT2_DIVIDE(50),
      .S1_CLKOUT2_PHASE(0),
      .S1_CLKOUT2_DUTY(50000),

      .S1_CLKOUT3_DIVIDE(100),
      .S1_CLKOUT3_PHASE(0),
      .S1_CLKOUT3_DUTY(50000),

      .S1_CLKOUT4_DIVIDE(5),
      .S1_CLKOUT4_PHASE(0),
      .S1_CLKOUT4_DUTY(50000),

      .S1_CLKOUT5_DIVIDE(5),
      .S1_CLKOUT5_PHASE(180000),
      .S1_CLKOUT5_DUTY(50000),
      //***********************************************************************

      //***********************************************************************
      .S2_CLKFBOUT_MULT(32),
      .S2_CLKFBOUT_PHASE(0),
      .S2_BANDWIDTH("LOW"),
      .S2_DIVCLK_DIVIDE(2),
          
      .S2_CLKOUT0_DIVIDE(28),
      .S2_CLKOUT0_PHASE(0),
      .S2_CLKOUT0_DUTY(50000),
          
      .S2_CLKOUT1_DIVIDE(28),
      .S2_CLKOUT1_PHASE(180000),
      .S2_CLKOUT1_DUTY(50000),
          
      .S2_CLKOUT2_DIVIDE(56),
      .S2_CLKOUT2_PHASE(0),
      .S2_CLKOUT2_DUTY(50000),
          
      .S2_CLKOUT3_DIVIDE(112),
      .S2_CLKOUT3_PHASE(0),
      .S2_CLKOUT3_DUTY(50000),
          
      .S2_CLKOUT4_DIVIDE(6),
      .S2_CLKOUT4_PHASE(0),
      .S2_CLKOUT4_DUTY(50000),
          
      .S2_CLKOUT5_DIVIDE(6),
      .S2_CLKOUT5_PHASE(180000),
      .S2_CLKOUT5_DUTY(50000),
      //***********************************************************************

      //***********************************************************************
      .S3_CLKFBOUT_MULT(33),
      .S3_CLKFBOUT_PHASE(0),
      .S3_BANDWIDTH("LOW"),
      .S3_DIVCLK_DIVIDE(2),
          
      .S3_CLKOUT0_DIVIDE(28),
      .S3_CLKOUT0_PHASE(0),
      .S3_CLKOUT0_DUTY(50000),
          
      .S3_CLKOUT1_DIVIDE(28),
      .S3_CLKOUT1_PHASE(180000),
      .S3_CLKOUT1_DUTY(50000),
          
      .S3_CLKOUT2_DIVIDE(56),
      .S3_CLKOUT2_PHASE(0),
      .S3_CLKOUT2_DUTY(50000),
          
      .S3_CLKOUT3_DIVIDE(112),
      .S3_CLKOUT3_PHASE(0),
      .S3_CLKOUT3_DUTY(50000),
          
      .S3_CLKOUT4_DIVIDE(6),
      .S3_CLKOUT4_PHASE(0),
      .S3_CLKOUT4_DUTY(50000),
          
      .S3_CLKOUT5_DIVIDE(6),
      .S3_CLKOUT5_PHASE(180000),
      .S3_CLKOUT5_DUTY(50000),
      //***********************************************************************

      //***********************************************************************
      .S4_CLKFBOUT_MULT(30),
      .S4_CLKFBOUT_PHASE(0),
      .S4_BANDWIDTH("LOW"),
      .S4_DIVCLK_DIVIDE(2),
          
      .S4_CLKOUT0_DIVIDE(25),
      .S4_CLKOUT0_PHASE(0),
      .S4_CLKOUT0_DUTY(50000),
          
      .S4_CLKOUT1_DIVIDE(25),
      .S4_CLKOUT1_PHASE(180000),
      .S4_CLKOUT1_DUTY(50000),
          
      .S4_CLKOUT2_DIVIDE(50),
      .S4_CLKOUT2_PHASE(0),
      .S4_CLKOUT2_DUTY(50000),
          
      .S4_CLKOUT3_DIVIDE(100),
      .S4_CLKOUT3_PHASE(0),
      .S4_CLKOUT3_DUTY(50000),
          
      .S4_CLKOUT4_DIVIDE(6),
      .S4_CLKOUT4_PHASE(0),
      .S4_CLKOUT4_DUTY(50000),
          
      .S4_CLKOUT5_DIVIDE(6),
      .S4_CLKOUT5_PHASE(180000),
      .S4_CLKOUT5_DUTY(50000),
      //***********************************************************************

      //***********************************************************************
      .S5_CLKFBOUT_MULT(31),
      .S5_CLKFBOUT_PHASE(0),
      .S5_BANDWIDTH("LOW"),
      .S5_DIVCLK_DIVIDE(2),
          
      .S5_CLKOUT0_DIVIDE(25),
      .S5_CLKOUT0_PHASE(0),
      .S5_CLKOUT0_DUTY(50000),
          
      .S5_CLKOUT1_DIVIDE(25),
      .S5_CLKOUT1_PHASE(180000),
      .S5_CLKOUT1_DUTY(50000),
          
      .S5_CLKOUT2_DIVIDE(50),
      .S5_CLKOUT2_PHASE(0),
      .S5_CLKOUT2_DUTY(50000),
          
      .S5_CLKOUT3_DIVIDE(100),
      .S5_CLKOUT3_PHASE(0),
      .S5_CLKOUT3_DUTY(50000),
          
      .S5_CLKOUT4_DIVIDE(6),
      .S5_CLKOUT4_PHASE(0),
      .S5_CLKOUT4_DUTY(50000),
          
      .S5_CLKOUT5_DIVIDE(6),
      .S5_CLKOUT5_PHASE(180000),
      .S5_CLKOUT5_DUTY(50000),
      //***********************************************************************

      //***********************************************************************
      .S6_CLKFBOUT_MULT(32),
      .S6_CLKFBOUT_PHASE(0),
      .S6_BANDWIDTH("LOW"),
      .S6_DIVCLK_DIVIDE(2),
          
      .S6_CLKOUT0_DIVIDE(25),
      .S6_CLKOUT0_PHASE(0),
      .S6_CLKOUT0_DUTY(50000),
          
      .S6_CLKOUT1_DIVIDE(25),
      .S6_CLKOUT1_PHASE(180000),
      .S6_CLKOUT1_DUTY(50000),
          
      .S6_CLKOUT2_DIVIDE(50),
      .S6_CLKOUT2_PHASE(0),
      .S6_CLKOUT2_DUTY(50000),
          
      .S6_CLKOUT3_DIVIDE(100),
      .S6_CLKOUT3_PHASE(0),
      .S6_CLKOUT3_DUTY(50000),
          
      .S6_CLKOUT4_DIVIDE(6),
      .S6_CLKOUT4_PHASE(0),
      .S6_CLKOUT4_DUTY(50000),
          
      .S6_CLKOUT5_DIVIDE(6),
      .S6_CLKOUT5_PHASE(180000),
      .S6_CLKOUT5_DUTY(50000),
      //***********************************************************************

      //***********************************************************************
      .S7_CLKFBOUT_MULT(33),
      .S7_CLKFBOUT_PHASE(0),
      .S7_BANDWIDTH("LOW"),
      .S7_DIVCLK_DIVIDE(2),
          
      .S7_CLKOUT0_DIVIDE(25),
      .S7_CLKOUT0_PHASE(0),
      .S7_CLKOUT0_DUTY(50000),
          
      .S7_CLKOUT1_DIVIDE(25),
      .S7_CLKOUT1_PHASE(180000),
      .S7_CLKOUT1_DUTY(50000),
          
      .S7_CLKOUT2_DIVIDE(50),
      .S7_CLKOUT2_PHASE(0),
      .S7_CLKOUT2_DUTY(50000),
          
      .S7_CLKOUT3_DIVIDE(100),
      .S7_CLKOUT3_PHASE(0),
      .S7_CLKOUT3_DUTY(50000),
          
      .S7_CLKOUT4_DIVIDE(6),
      .S7_CLKOUT4_PHASE(0),
      .S7_CLKOUT4_DUTY(50000),
          
      .S7_CLKOUT5_DIVIDE(6),
      .S7_CLKOUT5_PHASE(180000),
      .S7_CLKOUT5_DUTY(50000),
      //***********************************************************************

      //***********************************************************************
      .S8_CLKFBOUT_MULT(27),
      .S8_CLKFBOUT_PHASE(0),
      .S8_BANDWIDTH("LOW"),
      .S8_DIVCLK_DIVIDE(2),
          
      .S8_CLKOUT0_DIVIDE(25),
      .S8_CLKOUT0_PHASE(0),
      .S8_CLKOUT0_DUTY(50000),
          
      .S8_CLKOUT1_DIVIDE(25),
      .S8_CLKOUT1_PHASE(180000),
      .S8_CLKOUT1_DUTY(50000),
          
      .S8_CLKOUT2_DIVIDE(50),
      .S8_CLKOUT2_PHASE(0),
      .S8_CLKOUT2_DUTY(50000),
          
      .S8_CLKOUT3_DIVIDE(100),
      .S8_CLKOUT3_PHASE(0),
      .S8_CLKOUT3_DUTY(50000),
          
      .S8_CLKOUT4_DIVIDE(5),
      .S8_CLKOUT4_PHASE(0),
      .S8_CLKOUT4_DUTY(50000),
          
      .S8_CLKOUT5_DIVIDE(5),
      .S8_CLKOUT5_PHASE(180000),
      .S8_CLKOUT5_DUTY(50000)
      //***********************************************************************
     
   ) PLL_DRP_inst (
      // Top port connections
      .SADDR(STATE),
      .SEN(SSTEP),
      .RST(RST),
      .SRDY(SRDY),
      
      // Input from IBUFG
      .SCLK(clkin_bufgout),
      
      // Direct connections to the PLL_ADV
      .DO(dout),
      .DRDY(drdy),
      .LOCKED(locked),
      .DWE(dwe),
      .DEN(den),
      .DADDR(daddr),
      .DI(di),
      .DCLK(dclk),
      .RST_PLL(rst_pll)
   );
endmodule
