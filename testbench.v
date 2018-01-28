`default_nettype none

module tb;
  reg clk, reset;
  wire [15:0] AB;
  wire [7:0]  DI, DO;
  wire        WE, IRQ, NMI, RDY;
  
  cpu_65c02 CPU(.*);
  memory mem(.clk, .we(WE), .addr(AB), .dIn(DO), .dOut(DI));

  assign IRQ  = 1'b0;
  assign NMI  = 1'b0;
  assign RDY = 1'b1;

  initial begin
    $monitor("AB: %x, A: %x", AB, CPU.AXYS[0]);
    clk        = 0;
    reset      = 1'b1;
    #10 reset <= 1'b0;
    #100000 $finish;
  end

  initial begin
    forever #10 clk = ~clk;
  end

endmodule
