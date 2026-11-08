`timescale 1ns/1ns

// seg7 —— 四位码到七段字形
//
// 用途
//   把一位十六进制码转换成七段数码管的段码。
//
// 接口
//   参数
//     ACTIVE_LOW  1 低电平点亮，0 高电平点亮
//   端口
//     bin  4 位码
//     seg  7 段码，位序 {G,F,E,D,C,B,A}
//
// 使用方法
//   ACTIVE_LOW=1 与实验二、实验七的 bcd.v 一致；
//   只负责一位字形，进制换算放在 mid/display 里做。

module seg7 #(
    parameter ACTIVE_LOW = 1
) (
    input  wire [3:0] bin,
    output wire [6:0] seg
);

    function [6:0] seg_code;
        input [3:0] b;
        begin
            case (b)
                4'h0: seg_code = 7'b011_1111;
                4'h1: seg_code = 7'b000_0110;
                4'h2: seg_code = 7'b101_1011;
                4'h3: seg_code = 7'b100_1111;
                4'h4: seg_code = 7'b110_0110;
                4'h5: seg_code = 7'b110_1101;
                4'h6: seg_code = 7'b111_1101;
                4'h7: seg_code = 7'b000_0111;
                4'h8: seg_code = 7'b111_1111;
                4'h9: seg_code = 7'b110_1111;
                4'hA: seg_code = 7'b111_0111;
                4'hB: seg_code = 7'b111_1100;
                4'hC: seg_code = 7'b011_1001;
                4'hD: seg_code = 7'b101_1110;
                4'hE: seg_code = 7'b111_1001;
                4'hF: seg_code = 7'b111_0001;
                default: seg_code = 7'b000_0000;
            endcase
        end
    endfunction

    assign seg = ACTIVE_LOW ? ~seg_code(bin) : seg_code(bin);

endmodule
