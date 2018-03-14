`default_nettype none

/*
 * HuC6280 timer
 */

module TIMER(input wire        clk, reset,
             input wire        re, we,
             input wire        clk_en,
             input wire        CET_n,
             input wire        addr,
             input wire        TIQ_ack,
             input wire  [7:0] dIn,
             output wire [7:0] dOut,
             output reg        TIQ_n);

  wire restart;
  
  reg timer_en;
  reg [9:0] div;
  reg [6:0] counter, reset_val;                       


  //HIGH when timer should be restarted
  assign restart  = (~CET_n & we & addr & dIn[0] & ~timer_en);
  
  //MMIO read
  assign dOut  = (~CET_n & re & ~addr) ? counter : 0;
 
  //MMIO write
  always @(posedge clk) begin
    if(clk_en) begin
      if(reset)
        timer_en <= 0;
      else if(~CET_n & we) begin
        if(~addr) //counter
          reset_val <= dIn[6:0];
        else //control
          timer_en <= dIn[0];
      end
    end
  end
  
  always @(posedge clk) begin
    if(clk_en) begin
      if(reset)
        div <= 1023;
      else if(restart) //timer is being started
        div <= 1023;
      else if(timer_en)
        div <= div - 1;
    end
  end
  
  
  always @(posedge clk) begin
    if(clk_en) begin
      if(reset)
        counter <= 0;
      else if(timer_en && div == 0) begin
        if(counter != 0)
          counter <= counter - 1;
        else
          counter <= reset_val;
      end
      else if(restart)
        counter <= reset_val;
    end
  end


  always @(posedge clk) begin
    if(clk_en) begin
      if(reset)
        TIQ_n <= 1;
      else if(timer_en && div == 0 && counter == 0)
        TIQ_n <= 0;
      else if(TIQ_ack)
        TIQ_n <= 1;
    end
  end
endmodule
