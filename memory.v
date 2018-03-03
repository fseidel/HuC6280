//thanks to https://stackoverflow.com/a/30442903

`default_nettype none


module memory(input wire [20:0] addr,
              input wire [7:0]  dIn,
              output reg [7:0] dOut,
              input wire       re, we, clk);
  
  reg [7:0]                    mem[2**16-1:0];
  
  initial begin
    $readmemh("test.hex", mem);
  end

  
  always @(posedge clk) begin
    //if(re & we) $display("ERROR! RE AND WE ASSERTED");
    if(addr < 21'h1F0000) begin
      if(we) mem[addr] <= dIn;
      else if(re) dOut <= mem[addr];
    end
  end

  
endmodule
