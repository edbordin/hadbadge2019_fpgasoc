/*
 * Copyright (C) 2019  Jeroen Domburg <jeroen@spritesmods.com>
 * All rights reserved.
 *
 * BSD 3-clause, see LICENSE.bsd
 *
 * Redistribution and use in source and binary forms, with or without
 * modification, are permitted provided that the following conditions are met:
 *     * Redistributions of source code must retain the above copyright
 *       notice, this list of conditions and the following disclaimer.
 *     * Redistributions in binary form must reproduce the above copyright
 *       notice, this list of conditions and the following disclaimer in the
 *       documentation and/or other materials provided with the distribution.
 *     * Neither the name of the <organization> nor the
 *       names of its contributors may be used to endorse or promote products
 *       derived from this software without specific prior written permission.
 *
 * THIS SOFTWARE IS PROVIDED BY THE COPYRIGHT HOLDERS AND CONTRIBUTORS "AS IS" AND
 * ANY EXPRESS OR IMPLIED WARRANTIES, INCLUDING, BUT NOT LIMITED TO, THE IMPLIED
 * WARRANTIES OF MERCHANTABILITY AND FITNESS FOR A PARTICULAR PURPOSE ARE
 * DISCLAIMED. IN NO EVENT SHALL <COPYRIGHT HOLDER> BE LIABLE FOR ANY
 * DIRECT, INDIRECT, INCIDENTAL, SPECIAL, EXEMPLARY, OR CONSEQUENTIAL DAMAGES
 * (INCLUDING, BUT NOT LIMITED TO, PROCUREMENT OF SUBSTITUTE GOODS OR SERVICES;
 * LOSS OF USE, DATA, OR PROFITS; OR BUSINESS INTERRUPTION) HOWEVER CAUSED AND
 * ON ANY THEORY OF LIABILITY, WHETHER IN CONTRACT, STRICT LIABILITY, OR TORT
 * (INCLUDING NEGLIGENCE OR OTHERWISE) ARISING IN ANY WAY OUT OF THE USE OF THIS
 * SOFTWARE, EVEN IF ADVISED OF THE POSSIBILITY OF SUCH DAMAGE.
 */
`timescale 1us/1ns

module stimulus();

reg clk, rst;
reg do_read, do_write;
wire next_word;
reg [24:0] addr;
wire [31:0] rdata;
reg [31:0] wdata;

wire spi_clk, spi_ncs, is_idle;
wire [3:0] spi_sout;
wire [3:0] spi_sin;
wire spi_oe, spi_bus_qpi;

reg [7:0] spi_xfer_wdata;
wire [7:0] spi_xfer_rdata;
reg do_spi_xfer;
wire spi_xfer_idle;
reg spi_xfer_claim;

`define USE_SDRAM

`ifndef USE_SDRAM

qpimem_iface qpimem_iface(
	.clk(clk),
	.rst(rst),
	
	.do_read(do_read),
	.do_write(do_write),
	.next_word(next_word),
	.addr(addr),
	.wdata(wdata),
	.rdata(rdata),
	.is_idle(is_idle),

	.spi_xfer_wdata(spi_xfer_wdata),
	.spi_xfer_rdata(spi_xfer_rdata),
	.do_spi_xfer(do_spi_xfer),
	.spi_xfer_claim(spi_xfer_claim),
	.spi_xfer_idle(spi_xfer_idle),

	.spi_clk(spi_clk),
	.spi_ncs(spi_ncs),
	.spi_sout(spi_sout),
	.spi_sin(spi_sin),
	.spi_bus_qpi(spi_bus_qpi),
	.spi_oe(spi_oe)
);

spiram spiram (
	.spi_clk(spi_clk),
	.spi_ncs(spi_ncs),
	.spi_sin(spi_sout),
	.spi_sout(spi_sin),
	.spi_oe(spi_oe)
);

`else

	// point-to-point wishbone bus
	wire sdram_wb_cyc;
	wire sdram_wb_stb;
	wire sdram_wb_we;
	wire [22:0] sdram_wb_addr;
	wire [31:0] sdram_wb_data_ctl_out_sdram_in;
	wire [31:0] sdram_wb_data_ctl_in_sdram_out;
	wire [3:0] sdram_wb_sel;
	wire sdram_wb_ack;
	wire sdram_wb_stall;

	//sdram lines
	wire sdram_clk;
	wire sdram_cke;
	wire sdram_csn;
	wire sdram_wen;
	wire sdram_rasn;
	wire sdram_casn;
	wire [12:0] sdram_a;
	wire [1:0] sdram_ba;
	wire [1:0] sdram_dqm;
	wire sdram_d_oe;
	wire [15:0] sdram_d_out;
	wire [15:0] sdram_d_in;

	wire [15:0] sdram_d_bd;
	assign sdram_d_bd = sdram_d_oe ? sdram_d_out : 16'bZZZZZZZZ_ZZZZZZZZ;

	// Controller
	qpi_sdram_adapter qpi_sdram_adapter_I (
		.qpi_do_read(do_read),
		.qpi_do_write(do_write),
		.qpi_next_word(next_word),
		.qpi_addr(addr),
		.qpi_is_idle(is_idle),
		.qpi_wdata(wdata),
		.qpi_rdata(rdata),

		.o_wb_cyc(sdram_wb_cyc),
		.o_wb_stb(sdram_wb_stb),
		.o_wb_we(sdram_wb_we),
		.o_wb_addr(sdram_wb_addr),
		.o_wb_sel(sdram_wb_sel),
		.i_wb_ack(sdram_wb_ack),
		.i_wb_stall(sdram_wb_stall),
		.i_wb_data(sdram_wb_data_ctl_in_sdram_out),
		.o_wb_data(sdram_wb_data_ctl_out_sdram_in),
		
		.clk(clk),
		.rst(rst)
	);


	// wishbone sdram controller
	wbsdram wbsdram_I(
		.i_clk(clk),
		.i_wb_cyc(sdram_wb_cyc),
		.i_wb_stb(sdram_wb_stb),
		.i_wb_we(sdram_wb_we),
		.i_wb_addr(sdram_wb_addr),
		.i_wb_sel(sdram_wb_sel),
		.o_wb_ack(sdram_wb_ack),
		.o_wb_stall(sdram_wb_stall),
		.i_wb_data(sdram_wb_data_ctl_out_sdram_in),
		.o_wb_data(sdram_wb_data_ctl_in_sdram_out),

		.o_ram_cs_n(sdram_csn),
		.o_ram_cke(sdram_cke),
		.o_ram_ras_n(sdram_rasn),
		.o_ram_cas_n(sdram_casn),
		.o_ram_we_n(sdram_wen),
		.o_ram_bs(sdram_ba), // bank select == bank address
		.o_ram_addr(sdram_a),
		.o_ram_dmod(sdram_d_oe), // o_ram_drive_data aka o_ram_data_oe
		.i_ram_data(sdram_d_in),
		.o_ram_data(sdram_d_out),
		.o_ram_dqm(sdram_dqm),
		.o_debug()
		);

		

		// vendor SDRAM model
		`define MT48LC16M16

		mt48lc16m16a2 sdram_I (
			.Dq(sdram_d_bd),
			.Addr(sdram_a),
			.Ba(sdram_ba),
			.Clk(sdram_clk),
			.Cke(sdram_cke),
			.Cs_n(sdram_csn),
			.Ras_n(sdram_rasn),
			.Cas_n(sdram_casn),
			.We_n(sdram_wen),
			.Dqm(sdram_dqm)
		);

`endif //USE_SDRAM

//clock toggle
always #0.5 clk = !clk;

integer i;
initial begin
	$dumpfile("qpimem_iface_testbench.vcd");
	$dumpvars(0, stimulus);
	do_read <= 0;
	do_write <= 0;
	addr <= 0;
	wdata <= 0;
	clk <= 0;
	spi_xfer_wdata <= 'hfa;
	do_spi_xfer <= 0;
	spi_xfer_claim <= 0;

	rst = 1;
	#5 rst = 0;
	#5 addr <= 'h123456;
	wdata <= 'h89ABCDEF;
	do_write <= 1;
	while (!next_word) #1;
	wdata <= 'h11223344;
	while (!next_word) #1;
	wdata <= 'hF5667788;
	while (!next_word) #1;
	#1 do_write <= 0;
	while (!is_idle) #1;

	addr <= 'h123456;
	do_read <= 1;
	while (!next_word) #1;
	while (!next_word) #1;
	while (!next_word) #1;
	do_read <= 0;
	while (!is_idle) #1;

	spi_xfer_claim <= 1;
	while (!spi_xfer_idle) #1;
	do_spi_xfer <= 1;
	#1 do_spi_xfer <= 0;
	while (!spi_xfer_idle) #1;
	spi_xfer_wdata <= 'h55;
	do_spi_xfer <= 1;
	#1 do_spi_xfer <= 0;
	spi_xfer_claim <= 0;

	#10 $finish;
end



endmodule