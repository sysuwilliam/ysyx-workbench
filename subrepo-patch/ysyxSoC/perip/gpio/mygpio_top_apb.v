module mygpio_top_apb(
  input         clock,
  input         reset,
  input  [31:0] in_paddr,
  input         in_psel,
  input         in_penable,
  input  [2:0]  in_pprot,
  input         in_pwrite,
  input  [31:0] in_pwdata,
  input  [3:0]  in_pstrb,
  output        in_pready,
  output [31:0] in_prdata,
  output        in_pslverr,

  output [15:0] gpio_out,
  input  [15:0] gpio_in,
  output [7:0]  gpio_seg_0,
  output [7:0]  gpio_seg_1,
  output [7:0]  gpio_seg_2,
  output [7:0]  gpio_seg_3,
  output [7:0]  gpio_seg_4,
  output [7:0]  gpio_seg_5,
  output [7:0]  gpio_seg_6,
  output [7:0]  gpio_seg_7
);

  reg [15:0] led;
  reg [31:0] seg;

  wire wr = in_psel && !in_penable && in_pwrite;

  always @(posedge clock) begin
    if (reset) begin
      led <= 16'b0;
      seg <= 32'b0;
    end else if (wr) begin
      case (in_paddr[3:2])
        2'b00: led <= in_pwdata[15:0];
        2'b10: seg <= in_pwdata[31:0];
        default: ;
      endcase
    end
  end

  assign gpio_out = led;

  assign in_pready = in_psel && in_penable;
  assign in_pslverr = 1'b0;
  assign in_prdata = (in_paddr[3:2] == 2'b00) ? {16'b0, led} :
                     (in_paddr[3:2] == 2'b01) ? {16'b0, gpio_in} :
                     (in_paddr[3:2] == 2'b10) ? seg :
                                                32'b0;

  function [6:0] hex7;
    input [3:0] d;
    begin
      case (d)
        4'h0: hex7 = 7'b0111111;
        4'h1: hex7 = 7'b0000110;
        4'h2: hex7 = 7'b1011011;
        4'h3: hex7 = 7'b1001111;
        4'h4: hex7 = 7'b1100110;
        4'h5: hex7 = 7'b1101101;
        4'h6: hex7 = 7'b1111101;
        4'h7: hex7 = 7'b0000111;
        4'h8: hex7 = 7'b1111111;
        4'h9: hex7 = 7'b1101111;
        4'hA: hex7 = 7'b1110111;
        4'hB: hex7 = 7'b1111100;
        4'hC: hex7 = 7'b0111001;
        4'hD: hex7 = 7'b1011110;
        4'hE: hex7 = 7'b1111001;
        4'hF: hex7 = 7'b1110001;
        default: hex7 = 7'b0;
      endcase
    end
  endfunction

  function [7:0] seg8;
    input [3:0] d;
    reg [6:0] h;
    begin
      h = hex7(d);
      seg8 = {h[0], h[1], h[2], h[3], h[4], h[5], h[6], 1'b0};
    end
  endfunction

  assign gpio_seg_0 = seg8(seg[3:0]);
  assign gpio_seg_1 = seg8(seg[7:4]);
  assign gpio_seg_2 = seg8(seg[11:8]);
  assign gpio_seg_3 = seg8(seg[15:12]);
  assign gpio_seg_4 = seg8(seg[19:16]);
  assign gpio_seg_5 = seg8(seg[23:20]);
  assign gpio_seg_6 = seg8(seg[27:24]);
  assign gpio_seg_7 = seg8(seg[31:28]);

  wire unused_pprot = &{1'b0, in_pprot, in_pstrb};

endmodule
