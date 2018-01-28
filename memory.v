//thanks to https://stackoverflow.com/a/30442903

`default_nettype none


module memory(input wire [15:0] addr,
              input wire [7:0]  dIn,
              output reg [7:0] dOut,
              input wire        we, clk);
  
  reg [7:0]                    mem[2**16-1:0];
  
  initial begin
    $readmemh("test.hex", mem);
  end

  
  always @(posedge clk) begin
    if(we) mem[addr] <= dIn;
    dOut <= mem[addr]; 
  end

  
endmodule
