`timescale 1ns/1ns

// 双控开关：两个开关 a、b 联合控制同一盏灯 f
module top (
    input  wire a,
    input  wire b,
    output wire f
);
    assign f = a ^ b;
endmodule
