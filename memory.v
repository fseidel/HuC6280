//thanks to https://stackoverflow.com/a/30442903

`default_nettype none


module memory(input wire [20:0] addr,
              input wire [7:0] dIn,
              output reg [7:0] dOut,
              input wire       re, we, clk,
              input wire       CE_n, CER_n);

  localparam ROMSIZE  = 512*1024;
  
  reg [7:0]                    ROM[ROMSIZE-1:0];

  localparam RAMSIZE  = 8*1024;
  
  reg [7:0]                    RAM[RAMSIZE-1:0];                 

  int                          romsize;
  
  initial begin
    $readmemh("PRG.hex", ROM);
    //hacky way to autodetect ROM size for testbench
    for(romsize = 0; romsize < ROMSIZE; romsize++)
      if(^ROM[romsize] === 1'bx) begin
        $display("romsize: %x", romsize);
        break;
      end
    
    for(int i = 0; i < RAMSIZE; i++)
      RAM[i] = 8'h0;
  end
  
  always @(posedge clk) begin
    dOut <= 8'hxx;
    if(re & we) begin
      $display("ERROR! RE AND WE ASSERTED");
      #1 $finish;
    end

    if(addr < 21'h1F0000) begin //ROM AREA mappings
      if(re & ~CE_n) begin
        case(romsize)
          21'h100000: begin //1MiB ROM
            dOut <= ROM[addr[19:0]];
          end
          21'h80000: begin //512KiB ROM
            dOut <= ROM[addr[18:0]];
          end
          21'h60000: begin //384KiB ROM
            if(addr < 21'h80000) //mirror first 256KiB twice
              dOut <= ROM[addr[17:0]];
            else                //mirror last 128KiB every 128KiB
              dOut <= ROM[{2'b10, addr[16:0]}];
          end
          21'h40000: begin //256KiB ROM
            dOut <= ROM[addr[17:0]];
          end
          default: begin  //unimplemented ROM size TODO: 768KiB
            $display("ROM SIZE UNIMPLIMENTED!");
            #1 $finish;
          end
        endcase
      end
    end
    else if(addr < 21'h1F8000) begin
      if(we & ~CER_n)
        RAM[addr[12:0]] <= dIn;
      else if(re & ~CER_n)
        dOut <= RAM[addr[12:0]];
    end
    else if(addr >= 21'h1FE000) begin
      if(addr[12:0] < 13'h400) begin
        //$display("VDC port %x access", addr[1:0]);
        /*if(re & addr[1])
          $display("non-status VDC read, this might be bad!");*/
      end
      else if(addr[12:0] < 13'h800) begin
        //$display("VCE port %x access", addr[2:0]);
      end
      else if(addr[12:0] == 13'h1000) begin // controller
        if(re) begin
          //$display("controller read");
        end
        else if(we) begin
          //$display("controller write");
        end
      end
      else if(addr[12:0] >= 13'h800 && addr[12:0] < 13'hC00) begin //PSG
        //$display("PSG access");
      end
      else if(addr[12:0] >= 13'hC00 && addr[12:0] < 13'h1000) begin //TIMER
        string str[2] = {"read", "write"};
        //$display("TIMER accessed, port %b %s", addr[0], str[~re]);
        //$display("dIn: %x", dIn);
      end
      else begin
        if(re) begin
          //$display("IO read to %x", addr);
          //$display("IO Region Unimplemented");
          //#1 $finish;
        end
        else if(we) begin
          //$display("IO write to %x", addr);
        end
      end
    end
  end
  
endmodule
