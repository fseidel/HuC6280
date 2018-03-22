`default_nettype none
/**
 * HuC6280 MMU
 * Maps 64KiB virtual address space to 2MiB physical address space
 */

module MMU(input wire        clk, reset, RDY, //self-explanatory
           input wire        RE, WE, //used for determining when to stall
           input wire        load_en, //CPU requesting MMU modify registers
           input wire        store_en, //CPU requesting MPR data
           input wire [7:0]  MPR_mask, //MPR(s) we wish to operate on
           input wire [7:0]  d_in, //data to transfer to MPRs
           input wire [15:0] VADDR, //virtual address to translate
           input wire        STx_override, //ST{0,1,2} mapping override signal
           output reg [20:0] PADDR, //physical address output
           output reg [7:0]  d_out, //data out for reading from MPR
           output wire       CE7_n, CEK_n, //VDC, VCE chip enable
           output wire       CEP_n, CET_n, //PSG, Timer chip enable
           output wire       CEIO_n, CECG_n, //IO, Interrupt chip enable
           output wire       CE_n, CER_n, //ROM, RAM chip enable
           output wire       IO_sel,      //high when IO device selected
           output reg        MMU_stall);      

  reg [7:0][7:0] MPR; //the memory paging register file
  reg [7:0]      databuf; //data for transfer from MPRs
  reg [7:0]      localmask; //a copy of the mask  

  assign CE_n   = !(PADDR <= 21'h1EFFFF);
  assign CER_n  = !(PADDR >= 21'h1F0000 && PADDR <= 21'h1F1FFF);
  assign CE7_n  = !(PADDR >= 21'h1FE000 && PADDR <= 21'h1FE3FF);
  assign CEK_n  = !(PADDR >= 21'h1FE400 && PADDR <= 21'h1FE7FF);
  assign CEP_n  = !(PADDR >= 21'h1FE800 && PADDR <= 21'h1FEBFF);
  assign CET_n  = !(PADDR >= 21'h1FEC00 && PADDR <= 21'h1FEFFF);
  assign CEIO_n = !(PADDR >= 21'h1FF000 && PADDR <= 21'h1FF3FF);
  assign CECG_n = !(PADDR >= 21'h1FF400 && PADDR <= 21'h1FF7FF);


  assign IO_sel = (PADDR >= 21'h1FE000); //is address in IO segment?

  
  assign PADDR = (STx_override) ? 
                 (21'h1FE000 | VADDR[1:0]) : 
                 {MPR[VADDR[15:13]], VADDR[12:0]};
  
  enum logic [1:0] {IDLE, LOAD, STORE} state;

  logic video_access;
  logic MMU_stall_toggle;

  assign video_access = (~CE7_n | ~CEK_n) & (RE | WE);
  assign MMU_stall = video_access & ~MMU_stall_toggle;
  
  always @(posedge clk) begin
    if(reset)
      MMU_stall_toggle <= 0;
    else if(RDY) begin
      if(video_access & ~MMU_stall_toggle)
        MMU_stall_toggle <= 1;
      else
        MMU_stall_toggle <= 0;
    end
  end

  

  always @* begin
    d_out = databuf;
    if(state == STORE) begin
      unique case(localmask) //setting multiple bits is undefined
        8'h00:; //no override required
        8'h01: d_out = MPR[0];
        8'h02: d_out = MPR[1];
        8'h04: d_out = MPR[2];
        8'h08: d_out = MPR[3];
        8'h10: d_out = MPR[4];
        8'h20: d_out = MPR[5];
        8'h40: d_out = MPR[6];
        8'h80: d_out = MPR[7];
      endcase
    end
  end
  
  always @(posedge clk) begin
    if(reset) begin
      for(int i = 0; i < 8; i++)
        MPR[i] <= 8'h00; //clearing all MPRs makes BUSY_n on VDC behave
      state <= IDLE;
    end
    else if(RDY) begin
      unique case(state)
        IDLE: begin
          if(load_en) begin
            localmask <= MPR_mask;
            if(MPR_mask) databuf <= d_in; //only transfer on nonzero mask
            state     <= LOAD;
          end
          else if(store_en) begin
            localmask <= MPR_mask;
            state     <= STORE;
          end
        end
        LOAD: begin //handle each bit in the mask, as we can set multiple
          if(localmask[0]) MPR[0] <= databuf;
          if(localmask[1]) MPR[1] <= databuf;
          if(localmask[2]) MPR[2] <= databuf;
          if(localmask[3]) MPR[3] <= databuf;
          if(localmask[4]) MPR[4] <= databuf;
          if(localmask[5]) MPR[5] <= databuf;
          if(localmask[6]) MPR[6] <= databuf;
          if(localmask[7]) MPR[7] <= databuf;
          state <= IDLE;
        end
        STORE:
          state <= IDLE;
      endcase
    end
  end
endmodule
