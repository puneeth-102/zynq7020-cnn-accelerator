`timescale 1ns/10ps
  
module ReLU(
        input clk,
        input en,
        input [22:0] in,
        output reg [22:0] out,
        output reg write
);

reg [22:0] in_r;
reg write_r;  // Intermediate register for write signal timing

always @(posedge clk) begin
        if (en) begin
                in_r <= in;  // Capture input when `en` is high
                write_r <= 1'b1;  // Assert write signal on the next cycle
        end
        else begin
                write_r <= 1'b0;  // De-assert write after 1 cycle
        end
end

always @(posedge clk) begin
        if (write_r) begin
                if (in_r[22]) begin
                        out <= 23'd0;  // Apply ReLU (negative input → 0)
                end
                else begin
                        out <= in_r;  // Pass positive value through
                end
                write <= 1'b1;  // Assert write when output is updated
        end
        else begin
                write <= 1'b0;
        end
end

endmodule

