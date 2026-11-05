`timescale 1ns/10ps

module fsm(
	input clk,
	input rst,
	input go,
	output reg [7:0] addr1, addr2, addr3, addr4, addr5, addr6, addr7, addr8, addr9, addr10, addr11,
	output reg [3:0] filter_addr,
	output reg acc_reset,
	output reg acc_clear,
	output reg acc_ready,
	output reg [5:0] row,
	output reg out_ready
);

parameter IDLE = 4'h0;   
parameter PREP = 4'h1; 
parameter CONV1 = 4'h2; 
parameter CONV2 = 4'h3;
parameter CONV3 = 4'h4;
parameter CONV4 = 4'h5;
parameter CONV5 = 4'h6;
parameter CONV6 = 4'h7;
parameter CONV7 = 4'h8;
parameter DONE = 4'h9;


reg [3:0] state, state_c;
reg [7:0] addr1_c, addr2_c, addr3_c, addr4_c, addr5_c, addr6_c, addr7_c, addr8_c, addr9_c, addr10_c, addr11_c;
reg [5:0] row_c;
reg [3:0] filter_addr_c;
reg [6:0] count, count_c;
reg [2:0] wait_count, wait_count_c;
reg [3:0] col_count, col_count_c;
reg acc_reset_c, acc_clear_c, acc_ready_c;
reg out_ready_c;

always @(state or go or rst or count or col_count) begin
	state_c = state;
	count_c = count - 7'b000_0001;
	col_count_c = col_count - 4'b0001;
	wait_count_c = wait_count - 3'b001;
	filter_addr_c = filter_addr + 4'b0001;

	addr1_c = addr1 + 8'd1;
	addr2_c = addr2 + 8'd1;
	addr3_c = addr3 + 8'd1;
	addr4_c = addr4 + 8'd1;
	addr5_c = addr5 + 8'd1;
	addr6_c = addr6 + 8'd1;
	addr7_c = addr7 + 8'd1;
	addr8_c = addr8 + 8'd1;
	addr9_c = addr9 + 8'd1;
	addr10_c = addr10 + 8'd1;
	addr11_c = addr11 + 8'd1;

	if(col_count == 4'b0000) begin
		col_count_c = 4'd10;
		filter_addr_c = 4'd0;
		
		addr1_c = addr1 - 8'd6;
		addr2_c = addr2 - 8'd6;
		addr3_c = addr3 - 8'd6;
		addr4_c = addr4 - 8'd6;
		addr5_c = addr5 - 8'd6;
		addr6_c = addr6 - 8'd6;
		addr7_c = addr7 - 8'd6;
		addr8_c = addr8 - 8'd6;
		addr9_c = addr9 - 8'd6;
		addr10_c = addr10 - 8'd6;
		addr11_c = addr11 - 8'd6;
	end
		
	case (state)
		IDLE: begin
			acc_clear_c = 1'b0;
			acc_reset_c = 1'b0;
			if(go == 1'b1) begin
				state_c = PREP;
				acc_reset_c = 1'b1;
			end
		end
		PREP: begin
			acc_reset_c = 1'b1;
			state_c = CONV1;
			count_c = 7'd76;
			col_count_c = 4'd10;
			out_ready_c = 1'b0;
			filter_addr_c = 4'd0;
			addr1_c = 8'd0;
			addr2_c = 8'd0;
			addr3_c = 8'd0;
			addr4_c = 8'd0;
			addr5_c = 8'd0;
			addr6_c = 8'd0;
			addr7_c = 8'd0;
			addr8_c = 8'd0;
			addr9_c = 8'd0;
			addr10_c = 8'd0;
			addr11_c = 8'd0;
			row_c = 5'd0;
		end
		CONV1: begin
			if(count == 7'd74) begin
				acc_reset_c = 1'b0;
			end
			if(count == 7'b000_0000) begin
				state_c = CONV2;
				count_c = 7'd76;
				
				filter_addr_c = 4'd0;	
				addr1_c = 8'd35;
				addr2_c = 8'd35;
				addr3_c = 8'd35;
				addr4_c = 8'd35;
				addr5_c = 8'd0;
				addr6_c = 8'd0;
				addr7_c = 8'd0;
				addr8_c = 8'd0;
				addr9_c = 8'd0;
				addr10_c = 8'd0;
				addr11_c = 8'd0;
				row_c = 5'd4;
			end
			if(col_count == 4'b0000) begin
				out_ready_c = 1'b1;
			end
		end
		CONV2: begin
			if(count == 7'b000_0000) begin
				state_c = CONV3;
				count_c = 7'd76;
				
				filter_addr_c = 4'd0;
				addr1_c = 8'd35;
				addr2_c = 8'd35;
				addr3_c = 8'd35;
				addr4_c = 8'd35;
				addr5_c = 8'd35;
				addr6_c = 8'd35;
				addr7_c = 8'd35;
				addr8_c = 8'd35;
				addr9_c = 8'd35;
				addr10_c = 8'd0;
				addr11_c = 8'd0;
				row_c = 5'd8;
			end
		end			
		CONV3: begin
			if(count == 7'b000_0000) begin
				state_c = CONV4;
				count_c = 7'd76;
				
				filter_addr_c = 4'd0;
				addr1_c = 8'd70;
				addr2_c = 8'd35;
				addr3_c = 8'd35;
				addr4_c = 8'd35;
				addr5_c = 8'd35;
				addr6_c = 8'd35;
				addr7_c = 8'd35;
				addr8_c = 8'd35;
				addr9_c = 8'd35;
				addr10_c = 8'd35;
				addr11_c = 8'd35;
				row_c = 5'd12;
			end
		end			
		CONV4: begin
			if(count == 7'b000_0000) begin
				state_c = CONV5;
				count_c = 7'd76;
				
				filter_addr_c = 4'd0;
				addr1_c = 8'd70;
				addr2_c = 8'd70;
				addr3_c = 8'd70;
				addr4_c = 8'd70;
				addr5_c = 8'd70;
				addr6_c = 8'd35;
				addr7_c = 8'd35;
				addr8_c = 8'd35;
				addr9_c = 8'd35;
				addr10_c = 8'd35;
				addr11_c = 8'd35;
				row_c = 5'd16;
			end
		end		
		CONV5: begin
			if(count == 7'b000_0000) begin
				state_c = CONV6;
				count_c = 7'd76;
				
				filter_addr_c = 4'd0;
				addr1_c = 8'd70;
				addr2_c = 8'd70;
				addr3_c = 8'd70;
				addr4_c = 8'd70;
				addr5_c = 8'd70;
				addr6_c = 8'd70;
				addr7_c = 8'd70;
				addr8_c = 8'd70;
				addr9_c = 8'd70;
				addr10_c = 8'd35;
				addr11_c = 8'd35;
				row_c = 5'd20;
			end
		end			
		CONV6: begin
			if(count == 7'b000_0000) begin
				state_c = CONV7;
				count_c = 7'd76;
				
				filter_addr_c = 4'd0;
				addr1_c = 8'd105;
				addr2_c = 8'd105;
				addr3_c = 8'd70;
				addr4_c = 8'd70;
				addr5_c = 8'd70;
				addr6_c = 8'd70;
				addr7_c = 8'd70;
				addr8_c = 8'd70;
				addr9_c = 8'd70;
				addr10_c = 8'd70;
				addr11_c = 8'd70;
				row_c = 5'd24;
			end
		end			
		CONV7: begin
			if(count == 7'b000_0000) begin
				state_c = DONE;
				addr1_c = 8'dx;
				addr2_c = 8'dx;
				addr3_c = 8'dx;
				addr4_c = 8'dx;
				addr5_c = 8'dx;
				addr6_c = 8'dx;
				addr7_c = 8'dx;
				addr8_c = 8'dx;
				addr9_c = 8'dx;
				addr10_c = 8'dx;
				addr11_c = 8'dx;
				filter_addr_c = 4'dx;		
				wait_count_c = 3'b111;				
			end
		end
		DONE: begin
			if(wait_count == 3'b000) begin
				state_c = IDLE;
			
			end
		end
	endcase
	
	if(col_count == 4'b0110) begin
		acc_clear_c = 1'b1;
		acc_ready_c = 1'b1;

	end
	else begin
		acc_clear_c = 1'b0;
		acc_ready_c = 1'b0;
	end
	

	if(rst) begin
		state_c = IDLE;
		acc_reset_c = 1'b1;
	end
end

always@(posedge clk) begin
	state <= #1 state_c;
	count <= #1 count_c;
	col_count <= #1 col_count_c;
	wait_count <= #1 wait_count_c;
	filter_addr <= #1 filter_addr_c;	
	addr1 <= #1 addr1_c;
	addr2 <= #1 addr2_c;
	addr3 <= #1 addr3_c;
	addr4 <= #1 addr4_c;
	addr5 <= #1 addr5_c;
	addr6 <= #1 addr6_c;
	addr7 <= #1 addr7_c;
	addr8 <= #1 addr8_c;
	addr9 <= #1 addr9_c;
	addr10 <= #1 addr10_c;
	addr11 <= #1 addr11_c;

	row <= #1 row_c;

	acc_clear <= #1 acc_clear_c;
	acc_reset <= #1 acc_reset_c;
	acc_ready <= #1 acc_ready_c;

	out_ready <= #1 out_ready_c;
end

endmodule
