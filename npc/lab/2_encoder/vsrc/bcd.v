`timescale 1ns/1ns

// 4 位二进制 -> 七段字形码，格式与题目 HEX0[6:0] 完全一致：
//   seg[6]=G  seg[5]=F  seg[4]=E  seg[3]=D  seg[2]=C  seg[1]=B  seg[0]=A
//   低电平点亮：0=该段亮，1=该段灭
// 题目例子：seg = 7'b0110000 显示 "3"
module bcd (
    input  wire [3:0] bin,
    output reg  [6:0] seg
);

    always @(*) begin
        case (bin)
            4'h0: seg = 7'b100_0000;  // a b c d e f
            4'h1: seg = 7'b111_1001;  //   b c
            4'h2: seg = 7'b010_0100;  // a b   d e   g
            4'h3: seg = 7'b011_0000;  // a b c d     g
            4'h4: seg = 7'b001_1001;  //   b c   f g
            4'h5: seg = 7'b001_0010;  // a   c d   f g
            4'h6: seg = 7'b000_0010;  // a   c d e f g
            4'h7: seg = 7'b111_1000;  // a b c
            4'h8: seg = 7'b000_0000;  // a b c d e f g
            4'h9: seg = 7'b001_0000;  // a b c d   f g
            default: seg = 7'b111_1111;  // 10~15 全灭
        endcase
    end

endmodule
