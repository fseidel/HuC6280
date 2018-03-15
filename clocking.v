`default_nettype none
/*
 * Module for handling clock enable generation
 * Divides by div
 */
module clock_divider(input  wire clk, reset,
                     output wire clk_en);
  parameter div  = 2;
  reg [$clog2(div)-1:0] count;

  assign clk_en = (count == 0);
  
  always @(posedge clk) begin
    if(reset)
      count <= 0;
    else if(count == 0)
      count <= div - 1;
    else
      count <= count - 1;
  end
endmodule
