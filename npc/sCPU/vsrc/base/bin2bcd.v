`timescale 1ns/1ns

// bin2bcd —— 二进制转 BCD
//
// 用途
//   把二进制数转换成十进制各位，供数码管按十进制显示。
//
// 接口
//   参数
//     BIN_W   输入位宽
//     DIGITS  十进制位数，输出宽 DIGITS*4
//   端口
//     bin     二进制输入
//     bcd     BCD 输出，最高位在前
//
// 使用方法
//   DIGITS 要满足 10^DIGITS > 2^BIN_W，8 位输入用 3 位；
//   纯组合、无除法。十六进制显示不需要它，直接切 nibble 即可。

module bin2bcd #(
    parameter BIN_W  = 8,
    parameter DIGITS = 3
) (
    input  wire [BIN_W-1:0]    bin,
    output wire [DIGITS*4-1:0] bcd
);

    function [DIGITS*4-1:0] to_bcd;
        input [BIN_W-1:0] value;
        integer i;
        integer d;
        reg [DIGITS*4-1:0] acc;
        begin
            acc = {DIGITS*4{1'b0}};
            for (i = BIN_W-1; i >= 0; i = i - 1) begin
                for (d = 0; d < DIGITS; d = d + 1) begin
                    if (acc[d*4 +: 4] >= 4'd5)
                        acc[d*4 +: 4] = acc[d*4 +: 4] + 4'd3;
                end
                acc = {acc[DIGITS*4-2:0], value[i]};
            end
            to_bcd = acc;
        end
    endfunction

    assign bcd = to_bcd(bin);

endmodule
