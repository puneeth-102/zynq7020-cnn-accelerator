`timescale 1ns/10ps

module conv_col(
	input [7:0] mem1,mem2,mem3,mem4,mem5,mem6,mem7,mem8,mem9,mem10,mem11,
	input clk, rst, acc_clear,
	input [87:0] filter_col,
	output reg [22:0] acc
);

reg [7:0] mem1_r,mem2_r,mem3_r,mem4_r,mem5_r,mem6_r,mem7_r,mem8_r,mem9_r,mem10_r,mem11_r;
reg [87:0] filter_col_r;

reg [15:0] prod1, prod2, prod3, prod4, prod5, prod6, prod7, prod8, prod9, prod10, prod11;

always@(posedge clk) begin 
  if(rst) begin
    filter_col_r <= 88'd0;
    
    mem1_r <= 8'h00;
    mem2_r <= 8'h00;
    mem3_r <= 8'h00;
    mem4_r <= 8'h00;
    mem5_r <= 8'h00;
    mem6_r <= 8'h00;
    mem7_r <= 8'h00;
    mem8_r <= 8'h00;
    mem9_r <= 8'h00;
    mem10_r <= 8'h00;
    mem11_r <= 8'h00;
    
    prod1 <= 16'h0000;
    prod2 <= 16'h0000;
    prod3 <= 16'h0000;
    prod4 <= 16'h0000;
    prod5 <= 16'h0000;
    prod6 <= 16'h0000;
    prod7 <= 16'h0000;
    prod8 <= 16'h0000;
    prod9 <= 16'h0000;
    prod10 <= 16'h0000;
    prod11 <= 16'h0000;
    
    acc <= 23'b000_0000_0000_0000_0000_0000;
  end
  else begin
    filter_col_r <= filter_col;
    
    mem1_r <= mem1;
    mem2_r <= mem2;
    mem3_r <= mem3;
    mem4_r <= mem4;
    mem5_r <= mem5;
    mem6_r <= mem6;
    mem7_r <= mem7;
    mem8_r <= mem8;
    mem9_r <= mem9;
    mem10_r <= mem10;
    mem11_r <= mem11;
    
    prod1 <= {8'h00, mem1_r} * {{8{filter_col_r[87]}}, filter_col_r[87:80]};
    prod2 <= {8'h00, mem2_r} * {{8{filter_col_r[79]}}, filter_col_r[79:72]};
    prod3 <= {8'h00, mem3_r} * {{8{filter_col_r[71]}}, filter_col_r[71:64]};
    prod4 <= {8'h00, mem4_r} * {{8{filter_col_r[63]}}, filter_col_r[63:56]};
    prod5 <= {8'h00, mem5_r} * {{8{filter_col_r[55]}}, filter_col_r[55:48]};
    prod6 <= {8'h00, mem6_r} * {{8{filter_col_r[47]}}, filter_col_r[47:40]};
    prod7 <= {8'h00, mem7_r} * {{8{filter_col_r[39]}}, filter_col_r[39:32]};
    prod8 <= {8'h00, mem8_r} * {{8{filter_col_r[31]}}, filter_col_r[31:24]};
    prod9 <= {8'h00, mem9_r} * {{8{filter_col_r[23]}}, filter_col_r[23:16]};
    prod10 <= {8'h00, mem10_r} * {{8{filter_col_r[15]}}, filter_col_r[15:8]};
    prod11 <= {8'h00, mem11_r} * {{8{filter_col_r[7]}}, filter_col_r[7:0]};
    
    if(acc_clear) begin
	acc <=  {{7{prod1[15]}},prod1} + 
	      	{{7{prod2[15]}},prod2} + 
	      	{{7{prod3[15]}},prod3} + 
	      	{{7{prod4[15]}},prod4} + 
	      	{{7{prod5[15]}},prod5} + 
	      	{{7{prod6[15]}},prod6} + 
	      	{{7{prod7[15]}},prod7} + 
	        {{7{prod8[15]}},prod8} + 
	      	{{7{prod9[15]}},prod9} +
	      	{{7{prod10[15]}},prod10} +
	      	{{7{prod11[15]}},prod11}; 
    end
    else begin
	acc <= acc +
	{{7{prod1[15]}},prod1} + 
	{{7{prod2[15]}},prod2} + 
	{{7{prod3[15]}},prod3} + 
	{{7{prod4[15]}},prod4} + 
	{{7{prod5[15]}},prod5} + 
	{{7{prod6[15]}},prod6} + 
	{{7{prod7[15]}},prod7} + 
	{{7{prod8[15]}},prod8} + 
	{{7{prod9[15]}},prod9} +
	{{7{prod10[15]}},prod10} +
	{{7{prod11[15]}},prod11}; 
    end
    end
  end
endmodule
