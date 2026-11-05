`timescale 1ns/10ps

module main(mem_data, mem_addr, mem_select, mem_wr_en, filter_data, filter_addr, filter_offset, filter_wr_en,
clk, rst, go);

input clk, rst, go;

input [7:0] mem_data;
input [7:0] mem_addr;
input [3:0] mem_select;
input mem_wr_en;

input [7:0] filter_data;
input [3:0] filter_addr;
input [3:0] filter_offset;
input filter_wr_en;

wire mem_wr_en_0, mem_wr_en_1, mem_wr_en_2, mem_wr_en_3, mem_wr_en_4;
wire mem_wr_en_5, mem_wr_en_6, mem_wr_en_7, mem_wr_en_8, mem_wr_en_9, mem_wr_en_10;
wire [7:0] mem_addr_0, mem_addr_1, mem_addr_2, mem_addr_3, mem_addr_4;
wire [7:0] mem_addr_5, mem_addr_6, mem_addr_7, mem_addr_8, mem_addr_9, mem_addr_10;
wire [7:0] proc_mem_addr_0, proc_mem_addr_1, proc_mem_addr_2, proc_mem_addr_3, proc_mem_addr_4;
wire [7:0] proc_mem_addr_5, proc_mem_addr_6, proc_mem_addr_7, proc_mem_addr_8, proc_mem_addr_9, proc_mem_addr_10;

wire [3:0] fltr_addr;
wire [87:0] filter_col;
wire [3:0] proc_filter_addr;
wire [3:0] proc_offset;

wire [7:0] mem_out0, mem_out1, mem_out2, mem_out3, mem_out4, mem_out5, mem_out6, mem_out7, mem_out8, mem_out9, mem_out10;

wire [3:0] out_addr;
wire [22:0] out_data;
wire write_out;
wire [22:0] get_res;

assign mem_wr_en_0  = mem_wr_en && (mem_select == 4'd0);
assign mem_wr_en_1  = mem_wr_en && (mem_select == 4'd1);
assign mem_wr_en_2  = mem_wr_en && (mem_select == 4'd2);
assign mem_wr_en_3  = mem_wr_en && (mem_select == 4'd3);
assign mem_wr_en_4  = mem_wr_en && (mem_select == 4'd4);
assign mem_wr_en_5  = mem_wr_en && (mem_select == 4'd5);
assign mem_wr_en_6  = mem_wr_en && (mem_select == 4'd6);
assign mem_wr_en_7  = mem_wr_en && (mem_select == 4'd7);
assign mem_wr_en_8  = mem_wr_en && (mem_select == 4'd8);
assign mem_wr_en_9  = mem_wr_en && (mem_select == 4'd9);
assign mem_wr_en_10 = mem_wr_en && (mem_select == 4'd10);

assign mem_addr_0  = mem_wr_en ? ((mem_select == 4'd0)  ? mem_addr : 8'b0) : proc_mem_addr_0;
assign mem_addr_1  = mem_wr_en ? ((mem_select == 4'd1)  ? mem_addr : 8'b0) : proc_mem_addr_1;
assign mem_addr_2  = mem_wr_en ? ((mem_select == 4'd2)  ? mem_addr : 8'b0) : proc_mem_addr_2;
assign mem_addr_3  = mem_wr_en ? ((mem_select == 4'd3)  ? mem_addr : 8'b0) : proc_mem_addr_3;
assign mem_addr_4  = mem_wr_en ? ((mem_select == 4'd4)  ? mem_addr : 8'b0) : proc_mem_addr_4;
assign mem_addr_5  = mem_wr_en ? ((mem_select == 4'd5)  ? mem_addr : 8'b0) : proc_mem_addr_5;
assign mem_addr_6  = mem_wr_en ? ((mem_select == 4'd6)  ? mem_addr : 8'b0) : proc_mem_addr_6;
assign mem_addr_7  = mem_wr_en ? ((mem_select == 4'd7)  ? mem_addr : 8'b0) : proc_mem_addr_7;
assign mem_addr_8  = mem_wr_en ? ((mem_select == 4'd8)  ? mem_addr : 8'b0) : proc_mem_addr_8;
assign mem_addr_9  = mem_wr_en ? ((mem_select == 4'd9)  ? mem_addr : 8'b0) : proc_mem_addr_9;
assign mem_addr_10 = mem_wr_en ? ((mem_select == 4'd10) ? mem_addr : 8'b0) : proc_mem_addr_10;

assign fltr_addr = filter_wr_en ? filter_addr : proc_filter_addr;

mem8_140 mem0(.clk(clk), .addr(mem_addr_0), .data_in(mem_data), .data_out(mem_out0), .wr_en(mem_wr_en_0));
mem8_140 mem1(.clk(clk), .addr(mem_addr_1), .data_in(mem_data), .data_out(mem_out1), .wr_en(mem_wr_en_1));
mem8_105 mem2(.clk(clk), .addr(mem_addr_2), .data_in(mem_data), .data_out(mem_out2), .wr_en(mem_wr_en_2));
mem8_105 mem3(.clk(clk), .addr(mem_addr_3), .data_in(mem_data), .data_out(mem_out3), .wr_en(mem_wr_en_3));
mem8_105 mem4(.clk(clk), .addr(mem_addr_4), .data_in(mem_data), .data_out(mem_out4), .wr_en(mem_wr_en_4));
mem8_105 mem5(.clk(clk), .addr(mem_addr_5), .data_in(mem_data), .data_out(mem_out5), .wr_en(mem_wr_en_5));
mem8_105 mem6(.clk(clk), .addr(mem_addr_6), .data_in(mem_data), .data_out(mem_out6), .wr_en(mem_wr_en_6));
mem8_105 mem7(.clk(clk), .addr(mem_addr_7), .data_in(mem_data), .data_out(mem_out7), .wr_en(mem_wr_en_7));
mem8_105 mem8(.clk(clk), .addr(mem_addr_8), .data_in(mem_data), .data_out(mem_out8), .wr_en(mem_wr_en_8));
mem8_105 mem9(.clk(clk), .addr(mem_addr_9), .data_in(mem_data), .data_out(mem_out9), .wr_en(mem_wr_en_9));
mem8_105 mem10(.clk(clk), .addr(mem_addr_10), .data_in(mem_data), .data_out(mem_out10), .wr_en(mem_wr_en_10));

mem88_11 filter(.clk(clk), .addr(fltr_addr), .offset(filter_offset), .data_in(filter_data), .data_out(filter_col), .wr_en(filter_wr_en));

processor processor_module(
	.clk(clk), 
	.rst(rst), 
	.go(go), 
	.mem0(mem_out0), 
	.mem1(mem_out1), 
	.mem2(mem_out2), 
	.mem3(mem_out3), 
  	.mem4(mem_out4), 
	.mem5(mem_out5), 
	.mem6(mem_out6), 
	.mem7(mem_out7), 
	.mem8(mem_out8), 
	.mem9(mem_out9), 
  	.mem10(mem_out10), 
  	.filter_col(filter_col),
	.read0(proc_mem_addr_0), 
    	.read1(proc_mem_addr_1), 
    	.read2(proc_mem_addr_2), 
    	.read3(proc_mem_addr_3), 
    	.read4(proc_mem_addr_4), 
    	.read5(proc_mem_addr_5), 
    	.read6(proc_mem_addr_6), 
    	.read7(proc_mem_addr_7), 
    	.read8(proc_mem_addr_8), 
    	.read9(proc_mem_addr_9), 
    	.read10(proc_mem_addr_10),
	.readfilter(proc_filter_addr),
	.out_addr_rr(out_addr),
	.out_data(out_data),
	.write_out(write_out)
);

mem23_9 output_mem(.clk(clk), .addr(out_addr), .data_in(out_data), .data_out(get_res), .wr_en(write_out));

endmodule
