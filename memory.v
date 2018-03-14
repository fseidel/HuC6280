//thanks to https://stackoverflow.com/a/30442903

`default_nettype none


module memory(input wire [20:0] addr,
              input wire [7:0]  dIn,
              output reg [7:0] dOut,
              input wire       re, we, clk);

  localparam ROMSIZE  = 512*1024;
  
  reg [7:0]                    ROM[ROMSIZE-1:0];

  localparam RAMSIZE  = 8*1024;
  
  reg [7:0]                    RAM[RAMSIZE-1:0];                 
  
  initial begin
    $readmemh("test.hex", ROM);
    for(int i = 0; i < RAMSIZE; i++) RAM[i] = 8'h0;
  end

  always @(posedge clk) begin
    dOut <= 8'hxx;
    if(re & we) begin
      $display("ERROR! RE AND WE ASSERTED");
      #1 $finish;
    end
    if(addr < 21'h1F0000) begin
      if(re) dOut <= ROM[addr];
      
    end
    else if(addr < 21'h1F2000) begin
      if(we) begin  
        RAM[addr[12:0]] <= dIn;
      end
      else if(re) dOut <= RAM[addr[12:0]];
    end
    else if(addr >= 21'h1FE000) begin
      if(addr[12:0] < 13'h400) begin
        $display("VDC port %x access", addr[1:0]);
      end
      else if(addr[12:0] == 13'h1000) begin // controller
        if(re) begin
          $display("controller read");
          dOut <= 8'b0100_0000; // Region bit == Japan
        end
        else if(we) begin
          $display("controller write");
        end
      end
      else if(addr[12:0] >= 13'h800 && addr[12:0] < 13'hC00) begin //PSG
        $display("PSG access");
      end
      else if(addr[12:0] >= 13'hC00 && addr[12:0] < 13'h1000) begin //TIMER
        string str[2] = {"read", "write"};
        $display("TIMER accessed, port %b %s", addr[0], str[~re]);
        $display("dIn: %x", dIn);
      end
      else begin
        if(re) begin
          $display("IO read to %x", addr);
          $display("IO Region Unimplemented");
          #1 $finish;
        end
        else if(we) begin
          $display("IO write to %x", addr);
        end
      end
    end
  end
  
endmodule
