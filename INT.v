`default_nettype none

/*
 * Interrupt Controller
 */

module INT_ctrl(input wire        clk, reset,
                input wire        RDY,
                input wire        re, we,
                input wire        CECG_n, 
                input wire  [1:0] addr,
                input wire  [7:0] dIn,
                input wire        TIQ_n,
                input wire        IRQ1_n,
                input wire        IRQ2_n,
                output reg  [7:0] dOut,
                output wire       TIQ,
                output wire       IRQ1,
                output wire       IRQ2,
                output wire       TIQ_ack);

  //storage for IRQ state
  reg [2:0] IRQ_en;


  /* Interrupt signals output to CPU.
   * Despite the name, IRQ_en is really an interrupt DISABLE register.
   * Setting a bit in the register disables the respective interrupt.
   */
  assign TIQ  = ~TIQ_n  & ~IRQ_en[2];
  assign IRQ1 = ~IRQ1_n & ~IRQ_en[1];
  assign IRQ2 = ~IRQ2_n & ~IRQ_en[0];
  

  //TIQ acknowledged on write or reset
  assign TIQ_ack = ~CECG_n & we & addr | reset; //TODO: do we care about RDY?
  
  //READ IS COMBINATIONAL!
  always @* begin
    dOut = 0;
    if(~CECG_n & re) begin
      if(addr == 2) dOut = IRQ_en; //read from enable reg.
      else if(addr == 3) dOut = {5'b00000, ~TIQ_n, ~IRQ1_n, ~IRQ2_n}; //status
    end
  end
 
  always @(posedge clk) begin
    if(reset) begin
      IRQ_en <= 3'b000;
    end
    else if((RDY & ~CECG_n & we) && (addr == 2)) begin
      IRQ_en <= dIn; //write to enable reg.
    end
  end

  
  
endmodule
