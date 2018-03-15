`default_nettype none

module tb;
  reg clk, reset;
  wire [20:0] AB_21;
  wire [7:0]  DI, DO;
  wire        RE, WE, IRQ1_n, IRQ2_n, NMI, HSM, RDY_n;
  
  cpu_HuC6280 CPU(.*);
  memory mem(.clk, .re(RE), .we(WE), .addr(AB_21), .dIn(DO), .dOut(DI));

  assign {IRQ1_n, IRQ2_n} = 2'b11;
  assign NMI  = 1'b0;
  assign RDY_n  = 1'b0;


  initial begin
    /*$monitor("AB: %x, DI: %x, PC: %x, State: %s, ,
             CPU.AB, CPU.DI, CPU.PC, CPU.statename, CPU.A, CPU.X, CPU.Y, CPU.S);*/
    
    $monitor({"AB_21: %x, AB: %x, PC: %x, State: %s, Segment: %x, Base: %x\n",
              "A: %x, X: %x, Y: %x, S: %x, IR: %x, DIMUX: %x, count: %x\n",
              "DIMUX_IO: %b, latched_read: %x, cur_read: %x, read_delay: %b\n"},
             AB_21, CPU.AB, CPU.PC, CPU.statename, AB_21[20:13], AB_21[12:0],
             CPU.A, CPU.X, CPU.Y, CPU.S, CPU.IR, CPU.DIMUX, CPU.clk72.count, 
             CPU.DIMUX_IO, CPU.latched_read, CPU.cur_read, CPU.read_delay);
     
    clk            = 1'b0;
    reset          = 1'b1;
    #10 reset     <= 1'b0;
    //#2000;
    /*
    while(1) begin
      $display("%x, %x, %b", CPU.itimer.div, CPU.itimer.counter,
               CPU.itimer.timer_en);
      #10 continue;
    end
     */
    
    //while(1) #10 continue;
    //This runs until the end of 1 iteration of the IRQ wait loop in TKF
    /*
    while(1) begin
      if(CPU.AB == 16'hE226 && RE)
        $stop;
      #10 continue;
    end
     */
    while(CPU.AB != 16'hbeef || ~RE) #10 continue;
    //$display("IRQ enable state: %3b", CPU.ictrl.IRQ_en);
    $display("A: %x, X: %x, Y: %x, S: %x",
             CPU.A, CPU.X, CPU.Y, CPU.S);
    $display("$20: %x, $21: %x", mem.RAM[21'h20], mem.RAM[21'h21]);
    #10 $finish;
    //#50000 $finish;
  end

  initial begin
    forever #10 clk = ~clk;
  end

endmodule
