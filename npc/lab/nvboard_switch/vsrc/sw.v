`timescale 1ns/1ns

// 双控开关：SW0/SW1 控制 LD0
module sw (
    input  wire a,
    input  wire b,
    output wire f
);
    assign f = a ^ b;
endmodule
