
module audio_out
#(
	parameter CLK_RATE = 50000000
)
(
	input        reset,
	input        clk,

	//0 - 48KHz, 1 - 96KHz
	input        sample_rate,

	input [15:0] left_in,
	input [15:0] right_in,

	// I2S
	output       i2s_mclk,
	output       i2s_bclk,
	output       i2s_lrclk,
	output       i2s_data,

	// SPDIF
   output       spdif,

	// Sigma-Delta DAC
	output       dac_l,
	output       dac_r
);


assign i2s_mclk = clk;

localparam AUDIO_RATE = 48000;
localparam AUDIO_DW = 16;

localparam CE_RATE = AUDIO_RATE*AUDIO_DW*8;
localparam FILTER_DIV = (CE_RATE/(AUDIO_RATE*32))-1;

wire [31:0] real_ce = sample_rate ? {CE_RATE[30:0],1'b0} : CE_RATE[31:0];
wire [15:0] al, ar;

reg mclk_ce;
reg [31:0] cnt;
always @(posedge clk) begin

	mclk_ce <= 0;
	cnt = cnt + real_ce;
	if(cnt >= CLK_RATE) begin
		cnt = cnt - CLK_RATE;
		mclk_ce <= 1;
	end
end

reg i2s_ce;
reg div1;
always @(posedge clk) begin

	i2s_ce <= 0;
	if(mclk_ce) begin
		div1 <= ~div1;
		i2s_ce <= div1;
	end
end

reg lpf_ce;
integer div2;
always @(posedge clk) begin
	lpf_ce <= 0;
	if(mclk_ce) begin
		div2 <= div2 + 1;
		if(div2 == FILTER_DIV) begin
			div2 <= 0;
			lpf_ce <= 1;
		end
	end
end

//i2s_mister i2s_mister
//(
//	.reset(reset),
//
//	.clk(clk),
//	.ce(i2s_ce),
//
//	.sclk(i2s_bclk),
//	.lrclk(i2s_lrclk),
//	.sdata(i2s_data),
//
//	.left_chan(al),
//	.right_chan(ar)
//);

//spdif toslink
//(
//	.rst_i(reset),
//
//	.clk_i(clk),
//	.bit_out_en_i(mclk_ce),
//
//	.sample_i({ar,al}),
//	.spdif_o(spdif)
//);

sigma_delta_dac #(15) sd_l
(
	.CLK(clk),
	.RESET(reset),
	.DACin({~al[15], al[14:0]}),
	.DACout(dac_l)
);

sigma_delta_dac #(15) sd_r
(
	.CLK(clk),
	.RESET(reset),
	.DACin({~ar[15], ar[14:0]}),
	.DACout(dac_r)
);


lpf_aud lpf_l
(
   .CLK(clk),
   .CE(lpf_ce),
   .IDATA(left_in),
   .ODATA(al)
);

lpf_aud lpf_r
(
   .CLK(clk),
   .CE(lpf_ce),
   .IDATA(right_in),
   .ODATA(ar)
);

endmodule

module lpf_aud
(
   input         CLK,
   input         CE,
   input  [15:0] IDATA,
   output reg [15:0] ODATA
);

reg [511:0] acc;
reg [20:0] sum;

integer i;
always @(*) begin
	sum = 0;
	for (i = 0; i < 32; i = i+1) sum = sum + {{5{acc[(i*16)+15]}}, acc[i*16 +:16]};
end

always @(posedge CLK) begin
	if(CE) begin
		acc <= {acc[495:0], IDATA};
		ODATA <= sum[20:5];
	end
end

endmodule
