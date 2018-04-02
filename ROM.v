`default_nettype none
//`define EMULATE_ROM

/**
 * PC Engine ROM (HuCard/TurboChip) emulator
 * No support for on-card memory mappers or additional RAM
 */
module ROM(input  wire [19:0] addr,
           input wire         SW[2:0],
	       output wire [19:0] SRAM_ADDR,
	       input wire [15:0]  SRAM_DQ,
           inout wire [7:0]   D,
           input wire         RD_n, CE_n);

  reg [2:0]  romsel;
  reg [19:0] mapped_addr;

  wire [7:0] dOut;
  assign D  = (~RD_n & ~CE_n) ? dOut : 8'bz;
  
  always @* begin
    mapped_addr = 20'hx;
    case(romsel)  //ROM mappings
      3'b011: begin //1MiB ROM
        mapped_addr = addr;
      end
      3'b010: begin //512KiB ROM
        mapped_addr = addr[18:0];
      end
      3'b001: begin //384KiB ROM
        if(addr < 21'h80000) //mirror first 256KiB twice
          mapped_addr = addr[17:0];
        else                //mirror last 128KiB every 128KiB
          mapped_addr = {2'b10, addr[16:0]};
      end
      3'b000: begin //256KiB ROM
        mapped_addr = addr[17:0];
      end
      default: begin  //unimplemented ROM size TODO: 768KiB
        mapped_addr = addr;
        //#10 $display("ROM SIZE UNIMPLIMENTED!");
        //#1 $finish;
      end
    endcase
  end


  
  
`ifdef EMULATE_ROM
  localparam ROMSIZE  = 512*1024;
  reg [7:0] ROM[ROMSIZE-1:0];
  
  int romsize;
  initial begin
    $readmemh("PRG.hex", ROM);
    //hacky way to autodetect ROM size for testbench
    for(romsize = 0; romsize < ROMSIZE; romsize++)
      if(^ROM[romsize] === 1'bx) begin
        $display("romsize: %dk", romsize/1024);
        break;
      end
  end

  assign dOut = ROM[mapped_addr];
  
  always @* begin
    romsel = 0;
    case(romsize)  //ROM mappings
      21'h100000: begin //1MiB ROM
        romsel = 3'b011;
      end
      21'h80000: begin //512KiB ROM
        romsel = 3'b010;
      end
      21'h60000: begin //384KiB ROM
        romsel = 3'b001;
      end
      21'h40000: begin //256KiB ROM
        romsel = 3'b000;
      end
      default: begin  //unimplemented ROM size TODO: 768KiB
        romsel = 3'b111;
      end
    endcase
  end
`else // !`ifdef EMULATE_ROM  
  assign SRAM_ADDR  = {1'b0, mapped_addr[19:1]};
  assign dOut  = (mapped_addr[0]) ? SRAM_DQ[15:8] : SRAM_DQ[7:0];
  always @* begin
    romsel = SW[2:0];
  end
`endif //  `ifdef EMULATE_ROM
  
endmodule
