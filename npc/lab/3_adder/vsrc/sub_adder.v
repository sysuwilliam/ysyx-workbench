`timescale 1ns/1ns

// 可参数化的加减法器：sub_add=0 做加法，sub_add=1 做减法（A + ~B + 1）
module sub_adder #(
    parameter WIDTH = 32
) (
    input  wire [WIDTH-1:0] A,
    input  wire [WIDTH-1:0] B,
    input  wire             sub_add,
    output wire [WIDTH-1:0] Result,
    output wire             Carry,
    output wire             Zero,
    output wire             Overflow
);
    wire [WIDTH-1:0] A1;
    wire [WIDTH-1:0] B1;
    wire             Cin;

    assign A1  = A;
    assign B1  = B ^ {WIDTH{sub_add}};
    assign Cin = sub_add;

    assign {Carry, Result} = A1 + B1 + Cin;

    assign Zero = ~(|Result);

    assign Overflow = (A1[WIDTH-1] == B1[WIDTH-1]) &&
                      (Result[WIDTH-1] != A1[WIDTH-1]);

endmodule
