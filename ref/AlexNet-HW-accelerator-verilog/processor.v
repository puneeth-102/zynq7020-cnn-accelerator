`timescale 1ns/10ps

module processor(clk, rst, go, mem0, mem1, mem2, mem3, mem4, mem5, mem6, mem7, mem8, mem9, mem10, filter_col,
		 read0, read1, read2, read3, read4, read5, read6, read7, read8, read9, read10, readfilter, out_addr_rr, out_data, write_out);

	input clk, rst, go;
	input [87:0] filter_col;
	input [7:0] mem0, mem1, mem2, mem3, mem4, mem5, mem6, mem7, mem8, mem9, mem10;
	output reg [7:0] read0, read1, read2, read3, read4, read5, read6, read7, read8, read9, read10;
	output reg [3:0] readfilter;

	output reg [3:0] out_addr_rr;
	output reg [22:0] out_data;
	output reg write_out;


	reg go_r;
	wire go_fsm;
	reg [7:0] mem_in[0:10];	
	wire [7:0] mem_conv[0:10];
	wire [87:0] f_col;
	reg [87:0] filter_col_r;


	reg [22:0] conv_results[0:48];
	//reg [22:0] final_out[0:8];

	wire [7:0] addr1, addr2, addr3, addr4, addr5, addr6, addr7, addr8, addr9, addr10, addr11;
	wire [3:0] conv_filter_addr;

	wire [22:0] acc;

	wire acc_clear;
	wire acc_reset;
	wire acc_ready;
	wire [22:0] relu_result;
	wire [5:0] row_index;
	
	wire write_relu;
	reg [5:0] res_addr;
	wire out_ready;

	reg [5:0] mp_idx1_r;
	wire [5:0] mp_idx1, mp_idx2, mp_idx3, mp_idx4, mp_idx5, mp_idx6, mp_idx7, mp_idx8, mp_idx9;
	wire mp_signal;
	reg mp_signal_r;
	wire [22:0] mp_result;
	wire write_mp;
	wire [3:0] out_addr;
	reg [3:0] out_addr_r;

	assign mp_idx1 = mp_idx1_r;
	assign mp_idx2 = mp_idx1 + 1;
	assign mp_idx3 = mp_idx1 + 2;
	assign mp_idx4 = mp_idx1 + 7;
	assign mp_idx5 = mp_idx1 + 8;
	assign mp_idx6 = mp_idx1 + 9;
	assign mp_idx7 = mp_idx1 + 14;
	assign mp_idx8 = mp_idx1 + 15;
	assign mp_idx9 = mp_idx1 + 16;
	assign mp_signal = mp_signal_r;
	assign out_addr = out_addr_r;

	assign mem_conv[0] = mem_in[row_index % 11];
	assign mem_conv[1] = mem_in[(row_index + 1) % 11];
	assign mem_conv[2] = mem_in[(row_index + 2) % 11];
	assign mem_conv[3] = mem_in[(row_index + 3) % 11];
	assign mem_conv[4] = mem_in[(row_index + 4) % 11];
	assign mem_conv[5] = mem_in[(row_index + 5) % 11];
	assign mem_conv[6] = mem_in[(row_index + 6) % 11];
	assign mem_conv[7] = mem_in[(row_index + 7) % 11];
	assign mem_conv[8] = mem_in[(row_index + 8) % 11];
	assign mem_conv[9] = mem_in[(row_index + 9) % 11];
	assign mem_conv[10] = mem_in[(row_index + 10) % 11];
	assign f_col = filter_col_r;
	
	assign go_fsm = go_r;


	always@(posedge clk) begin
		// outputs
		read0 <= addr1;
		read1 <= addr2;
		read2 <= addr3;
		read3 <= addr4;
		read4 <= addr5;
		read5 <= addr6;
		read6 <= addr7;
		read7 <= addr8;
		read8 <= addr9;
		read9 <= addr10;
		read10 <= addr11;
		readfilter <= conv_filter_addr;
		// inputs
		mem_in[0] <= mem0;	
		mem_in[1] <= mem1;
		mem_in[2] <= mem2;
		mem_in[3] <= mem3;
		mem_in[4] <= mem4;
		mem_in[5] <= mem5;
		mem_in[6] <= mem6;
		mem_in[7] <= mem7;
		mem_in[8] <= mem8;
		mem_in[9] <= mem9;
		mem_in[10] <= mem10;
		filter_col_r <= filter_col;
		go_r <= go;
	end

	always @(posedge clk) begin
	    	if(out_ready) begin
			if(write_relu) begin
				case(res_addr)
					16: begin mp_signal_r <= 1'b1; mp_idx1_r <= 0; out_addr_r <= 0; end
					18: begin mp_signal_r <= 1'b1; mp_idx1_r <= 2; out_addr_r <= 1; end
					20: begin mp_signal_r <= 1'b1; mp_idx1_r <= 4; out_addr_r <= 2; end
					30: begin mp_signal_r <= 1'b1; mp_idx1_r <= 14; out_addr_r <= 3; end
					32: begin mp_signal_r <= 1'b1; mp_idx1_r <= 16; out_addr_r <= 4; end
					34: begin mp_signal_r <= 1'b1; mp_idx1_r <= 18; out_addr_r <= 5; end
					44: begin mp_signal_r <= 1'b1; mp_idx1_r <= 28; out_addr_r <= 6; end
					46: begin mp_signal_r <= 1'b1; mp_idx1_r <= 30; out_addr_r <= 7; end
					48: begin mp_signal_r <= 1'b1; mp_idx1_r <= 32; out_addr_r <= 8; end
					default: mp_signal_r <= 1'b0;
				endcase
  				conv_results[res_addr] <= relu_result;
		    		res_addr <= res_addr + 6'b00_0001;
			end
	    	end
	    	else begin
			res_addr <= 6'b00_0000;
	    		mp_signal_r <= 1'b0;
		end
	end

	always@(posedge clk) begin
		if(write_mp) begin
			//final_out[out_addr] <= mp_result;
			out_addr_rr <= out_addr;
			out_data <= mp_result;
			write_out <= write_mp;
		end
	end

	fsm main_controller(
	 	.clk(clk), 
		.rst(rst), 
		.go(go_fsm), 
		.addr1(addr1), 
		.addr2(addr2), 
		.addr3(addr3), 
		.addr4(addr4), 
		.addr5(addr5), 
		.addr6(addr6), 
		.addr7(addr7), 
		.addr8(addr8), 
		.addr9(addr9), 
		.addr10(addr10), 
		.addr11(addr11), 
		.filter_addr(conv_filter_addr), 
		.acc_clear(acc_clear), 
		.acc_reset(acc_reset), 
		.acc_ready(acc_ready), 
		.row(row_index),
		.out_ready(out_ready)
	);

	conv_col conv_module(
		.clk(clk), 
		.rst(acc_reset), 
		.mem1(mem_conv[0]), 
		.mem2(mem_conv[1]), 
		.mem3(mem_conv[2]), 
		.mem4(mem_conv[3]),
		.mem5(mem_conv[4]), 
		.mem6(mem_conv[5]), 
		.mem7(mem_conv[6]), 
		.mem8(mem_conv[7]),
		.mem9(mem_conv[8]), 
		.mem10(mem_conv[9]), 
		.mem11(mem_conv[10]), 
		.filter_col(f_col), 
		.acc(acc), 
		.acc_clear(acc_clear)
	);

	ReLU relu_module(
		.clk(clk), 
		.en(acc_ready), 
		.in(acc), 
		.out(relu_result),
		.write(write_relu)
	);
	
	max_pool mp_module(
		.clk(clk),
		.en(mp_signal),
		.num1(conv_results[mp_idx1]),
		.num2(conv_results[mp_idx2]),
		.num3(conv_results[mp_idx3]),
		.num4(conv_results[mp_idx4]),
		.num5(conv_results[mp_idx5]),
		.num6(conv_results[mp_idx6]),
		.num7(conv_results[mp_idx7]),
		.num8(conv_results[mp_idx8]),
		.num9(conv_results[mp_idx9]),
		.out(mp_result),
		.write_ready(write_mp)
	);

endmodule
