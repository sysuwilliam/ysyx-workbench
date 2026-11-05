`timescale 1ns/1ns

module sw (
    input  wire a,
    input  wire b,
    output wire f
);
    assign f = a ^ b;
endmodule
