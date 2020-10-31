module qpi_sdram_adapter #(
	parameter integer AW = 23,
	parameter integer DW = 32
)(
	// QPI memory interface
    input  wire qpi_do_read,
    input  wire qpi_do_write,
    input  wire [24:0] qpi_addr,
    output wire qpi_is_idle,

    input  wire [31:0] qpi_wdata,
    output [31:0] qpi_rdata,
    output reg qpi_next_word,

	// Wishbone master for sdram controller
	output reg o_wb_cyc,
	output reg o_wb_stb,
	output reg o_wb_we,
	output reg [(AW-1):0] o_wb_addr,
	
	output [(DW/8-1):0] o_wb_sel,
	input i_wb_ack,
	input i_wb_stall,
	input [(DW-1):0] i_wb_data,
	output [(DW-1):0] o_wb_data,

	// Clock
	input  wire clk,
	input  wire rst
);

	localparam
		ST_IDLE = 0,
		ST_WAIT_STALL = 1,
		ST_WAIT_ACK = 2,
		ST_END_WB = 3,
		ST_CONTINUE = 4;

	assign qpi_is_idle = (state == ST_IDLE) && (state_nxt == ST_IDLE) && !qpi_do_read && !qpi_do_write;
	assign o_wb_sel = {(DW/8) {1'b1}};

	// Main Control FSM
	reg  [ 3:0] state;
	reg  [ 3:0] state_nxt;

	reg [(AW-1):0] o_wb_addr_reg;
	reg [(AW-1):0] wb_addr_nxt;

	assign qpi_rdata = i_wb_data;
	assign o_wb_data = qpi_wdata;

	// State register
	always @(posedge clk)
		if (rst) begin
			state <= ST_IDLE;
			o_wb_addr_reg <= {AW{1'b0}};
		end else begin
			state <= state_nxt;
			o_wb_addr_reg <= wb_addr_nxt;
		end

	// Next-State logic
	always @(*)
	begin
		// Default is to stay put
		state_nxt = state;
		o_wb_stb = 1'b0;
		o_wb_we = qpi_do_write;
		qpi_next_word = 0;
		wb_addr_nxt = o_wb_addr_reg;
		o_wb_addr = o_wb_addr_reg;
		o_wb_cyc = 1'b0;

		// Transition?
		case (state)
			ST_IDLE: begin
				if (qpi_do_read | qpi_do_write) begin
					o_wb_addr = qpi_addr;
					wb_addr_nxt = qpi_addr;
					o_wb_stb = 1'b1;
					o_wb_cyc = 1'b1;
					if (~i_wb_stall) begin
						state_nxt = ST_WAIT_ACK;
					end else begin
						state_nxt = ST_WAIT_STALL;
					end
				end
			end
			ST_WAIT_STALL: begin
				o_wb_cyc = 1'b1;
				o_wb_stb = 1'b1;
				if (~i_wb_stall) begin
					state_nxt = ST_WAIT_ACK;
				end else begin
				end
			end
			ST_WAIT_ACK: begin
				o_wb_cyc = 1'b1;
				if (i_wb_ack) begin
					state_nxt = ST_END_WB;
					qpi_next_word = 1'b1;
				end
			end
			ST_END_WB: begin
				if (!qpi_do_read && !qpi_do_write) begin
					state_nxt = ST_IDLE;
				end else begin
					state_nxt = ST_CONTINUE;
					wb_addr_nxt = o_wb_addr_reg + 'd4;
				end
			end
			ST_CONTINUE: begin
				o_wb_stb = 1'b1;
				o_wb_cyc = 1'b1;
				if (~i_wb_stall) begin
					state_nxt = ST_WAIT_ACK;
				end else begin
					state_nxt = ST_WAIT_STALL;
				end
			end
		endcase
	end

endmodule
