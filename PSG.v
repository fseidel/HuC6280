`default_nettype none

`define SIM

module mult(output wire [OUTWIDTH-1:0] out,
            input  wire [INWIDTH-1:0]  A, B);
  parameter OUTWIDTH  = 16;
  parameter INWIDTH   = 8;
`ifdef SIM
  assign out = A * B; //no special hardware needed
`else
  assign out = A * B; //TODO: use FPGA's built-in multipliers
`endif
endmodule

//LUT for computing log10 of a 5-bit number
module log10(output [7:0] out,
             input [4:0] in);
  always @* begin
    case(in)
      0: out = 0;
      1: out = 51;
      2: out = 80;
      3: out = 102;
      4: out = 118;
      5: out = 131;
      6: out = 143;
      7: out = 152;
      8: out = 161;
      9: out = 169;
      10: out = 176;
      11: out = 182;
      12: out = 188;
      13: out = 194;
      14: out = 199;
      15: out = 204;
      16: out = 208;
      17: out = 212;
      18: out = 216;
      19: out = 220;
      20: out = 224;
      21: out = 227;
      22: out = 230;
      23: out = 233;
      24: out = 236;
      25: out = 239;
      26: out = 242;
      27: out = 245;
      28: out = 247;
      29: out = 250;
      30: out = 252;
      31: out = 255;
    endcase
  end
endmodule


/*
 * HUC6280 PSG
 * Thanks to Charles MacDonald for figuring out the LFSR properties.
 * Names are based on those in the MagicKit docs. This means that
 * some values which should really be referred to as periods are called
 * frequencies for the sake of consistency. Blame the MagicKit guys.
 */

typedef struct packed {
  reg [7:0]    fine_freq;
  reg [3:0]    rough_freq;
  reg          chan_on;
  reg          DDA_on;
  reg [4:0]    vol;
  reg [9:0]    bal;
  reg          noise_en;
  reg [4:0]    noise_freq;
  wire         wave_write;        
} PSG_state_t;

module PSG();
  reg [2:0] chan_sel;
  reg [9:0] global_bal;

  PSG_state_t [4:0] states;
  
  PSG_state_t cur_state;
  assign cur_state = states[chan_sel];

  for(int i = 0; i < 6; i++) begin
    assign states[i].wave_write = (we & (addr == 6) & (chan_sel == i));
  end
  
  always @(posedge clk) begin //data writes
    if(clk_en) begin //run at 7.5MHz
      if(we) begin
        case(addr)
          0: chan_sel <= dIn[2:0];
          1: global_bal <= {5'h1f - (dIn[7:4] << 1), 5'h1f - (dIn[3:0] << 1)};
          2: if(chan_sel < 6) cur_state.fine_freq <= dIn;
          3: if(chan_sel < 6) cur_state.rough_freq <= dIn[3:0];
          4: if(chan_sel < 6) begin
            cur_state.chan_on <= dIn[7];
            cur_state.DDA_on  <= dIn[6];
            cur_state.vol     <= 5'h1f - dIn[4:0];
          end
          5: if(chan_sel < 6)
            cur_state.bal <= {5'h1f - (dIn[7:4] << 1), 5'h1f - (dIn[3:0] << 1)};
          6: ;//wave data writes handled elsewhere
          7: if(chan_sel < 6) begin //values ignored for channels 0-3
            cur_state.noise_en   <= dIn[7];
            cur_state.noise_freq <= ~dIn[4:0]; //inverted for some reason
          end
          8: LFO_freq <= dIn;
          9: begin
            LFO_trig <= dIn[7];
            LFO_ctrl <= dIn[1:0];
          end
        endcase
      end
    end
  end


  //volume mixing
  
  reg [5:0][4:0]  chan_out; //left and right output per channel 
  reg [5:0][4:0]  vol_l, vol_r;   //each channel has separate l and r volume
  reg [15:0]      out_l, out_r;   //TODO: make output

  reg [5:0][12:0] mixed_l, mixed_r;
  reg [5:0][12:0] log_l, log_r;
   
  always @(posedge clk) begin
    if(clk35_en) begin
      for(int i = 0; i < 6; i++) begin //sum the volumes, with saturation
        integer temp_l  = states[i].vol + states[i].bal[9:5] + global_bal[9:5];
        integer temp_r  = states[i].vol + states[i].bal[4:0] + global_bal[4:0];
        vol_l[i]       <= (temp_l > 16'h1f) ? 16'h1f : temp_l;
        vol_r[i]       <= (temp_r > 16'h1f) ? 16'h1f : temp_r;
      end
    end
  end

  generate
    for(int i = 0; i < 6; i++) begin
      log10(log_l[i], vol_l[i]);
      log10(log_r[i], vol_r[i]);
      multiply(mixed_l[i], log_l[i], chan_out[i]);
      multiply(mixed_r[i], log_r[i], chan_out[i]);
    end
  endgenerate

  //final output
  always @* begin
    log_l  = 0;
    log_r  = 0;
    for(int i = 0; i < 6; i++) begin
      out_l += mixed_l[i];
      out_r += mixed_r[i];
    end
  end
  
endmodule

/* one channel of the PSG
 * clk35_en MUST BE IN PHASE WITH clk75_en
 */
module PSG_chan (input  wire           clk, reset,
                 input  wire           clk35_en,
                 input  wire           clk75_en,
                 input  PSG_state_t    state,
                 input  wire [7:0]     dIn,
                 input  wire [4:0]     LFO_in,
                 output wire [4:0]     LFO_out,
                 output wire [RES-1:0] aOut);
  
  parameter RES = 16;    //audio output bit width
  parameter CH_NUM = 0;  //channel number (determines capabilities)

  reg [4:0]  audio_ptr;  //sample playback pointer
  reg [11:0] period_ctr; //counter for sample period  
  
  wire       period_en;  //wire to indicate when period value has elapsed
  assign period_en = period_ctr == 0;


  reg [4:0]  wave[32];   //waveform to play
  reg [4:0]  wave_ptr;   //pointer into waveform


  wire [5:0] wave_mux;     //mux between noise and sample


  wire       ch_on, DDA_on;
  assign {ch_on, DDA_on} = {state.ch_on, state.DDA_on};
  
  //wave pointer management
  always @(posedge clk) begin
    if(reset)
      wave_ptr <= 0;
    else if(clk75_en) begin
      if(DDA_on) //DDA mode forces the pointer to 0
        wave_ptr <= 0;
      else if(state.wave_write & ~ch_on)
        wave_ptr <= wave_ptr + 1;
      else if(clk35_en) //why we need the phase alignment
        if(period_en & ch_on)
          wave_ptr <= wave_ptr + 1;
    end
  end

  //wave buffer management
  always @(posedge clk) begin
    if(clk75_en) begin
      //no reset, just leave garbage in there
      if(state.wave_write)
        wave[wave_ptr] <= dIn;
    end
  end

  //period counter management
  always @(posedge clk) begin
    if(reset) period_ctr <= 0;
    else if(period_ctr == 0) period_ctr <= period;
  end
  
  generate //generate white noise hardware if we need it
    if(CH_NUM < 4)
      assign wave_mux = wave[wave_ptr];
    else begin//channels 4 and 5 get white noise
      assign wave_mux  = (~state.noise_en) ? wave[wave_ptr] :
                         (LFSR[0]) ? 31 : 0; //LFSR toggles 0 or 31
      
      reg [12:0] noise_cnt;

      //noise counter frequency management
      always @(posedge clk) begin
        if(reset)
          noise_cnt <= 0;
        else if(noise_cnt == 0)
          noise_cnt <= state.noise_period << 5;
        else
          noise_cnt <= noise_cnt - 1;
      end
      
      reg [17:0] LFSR;
      always @(posedge clk) begin
        if(reset)
          LFSR <= 18'b1; //only bit 0 set
        else if(clk_en) begin
          if(noise_cnt == 0) begin
            LFSR[16:0] <= LFSR[17:1];
            LFSR[17]   <= ^{LFSR[0], LFSR[1], LFSR[11], LFSR[12], LFSR[17]};
          end
        end
      end
    end
  endgenerate
  
endmodule
