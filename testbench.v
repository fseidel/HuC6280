`default_nettype none

module tb;
  reg clk, reset;
  wire [15:0] AB;
  wire [7:0]  DI, DO;
  wire        RE, WE, IRQ, NMI, RDY;
  
  cpu_65c02 CPU(.*);
  memory mem(.clk, .re(RE), .we(WE), .addr(AB), .dIn(DO), .dOut(DI));

  assign IRQ  = 1'b0;
  assign NMI  = 1'b0;
  assign RDY = 1'b1;

  initial begin
    /*$monitor("AB: %x, DI: %x, PC: %x, State: %s, A: %x, X: %x, Y: %x, S: %x",
             CPU.AB, CPU.DI, CPU.PC, CPU.statename, CPU.A, CPU.X, CPU.Y, CPU.S);*/
    $monitor("AB: %x, PC: %x, State: %s", CPU.AB, CPU.PC, CPU.statename);
    clk           = 0;
    reset         = 1'b1;
    #10 reset    <= 1'b0;
    while(CPU.AB != 16'hbeef || ~RE) #10 continue;
    $finish;
    //#50000 $finish;
  end

  initial begin
    forever #10 clk = ~clk;
  end

endmodule
