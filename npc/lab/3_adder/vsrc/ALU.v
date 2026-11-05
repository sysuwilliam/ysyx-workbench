`timescale 1ns/1ns

// 任意位宽的有符号补码 ALU（WIDTH 默认 4）
//   op = 000 加  A+B           001 减  A-B
//        010 取反 ~A           011 与  A&B
//        100 或  A|B           101 异或 A^B
//        110 比较 A<B（有符号） 111 相等 A==B
module ALU #(
    parameter WIDTH = 4
) (
    input  wire [WIDTH-1:0] A,
    input  wire [WIDTH-1:0] B,
    input  wire [2:0]       op,
    output reg  [WIDTH-1:0] out,
    output reg              zero,
    output reg              carry,
    output reg              overflow
);

    localparam [WIDTH-1:0] ZERO = {WIDTH{1'b0}};
    localparam [WIDTH-1:0] ONE  = WIDTH'(1); 

    // 加减法直接复用 sub_adder：op=001 时 sub_add=1 做 A-B
    wire             is_sub = (op == 3'b001);
    wire [WIDTH-1:0] sum_r;
    wire             sum_c, sum_z, sum_o;

    sub_adder #(.WIDTH(WIDTH)) u_add_sub (
        .A        (A),
        .B        (B),
        .sub_add  (is_sub),
        .Result   (sum_r),
        .Carry    (sum_c),
        .Zero     (sum_z),
        .Overflow (sum_o)
    );

    // 有符号比较
    wire signed [WIDTH-1:0] a_s = A;
    wire signed [WIDTH-1:0] b_s = B;
    wire                    lt  = (a_s < b_s);

    always @(*) begin
        // 先给默认值
        out      = ZERO;
        zero     = 1'b0;
        carry    = 1'b0;
        overflow = 1'b0;

        case (op)
            3'b000: begin out = sum_r; zero = sum_z; carry = sum_c; overflow = sum_o; end
            3'b001: begin out = sum_r; zero = sum_z; carry = sum_c; overflow = sum_o; end
            3'b010: begin out = ~A;                   zero = ~(|out); end
            3'b011: begin out = A & B;                zero = ~(|out); end
            3'b100: begin out = A | B;                zero = ~(|out); end
            3'b101: begin out = A ^ B;                zero = ~(|out); end
            3'b110: begin out = lt ? ONE : ZERO;      zero = ~(|out); end
            3'b111: begin out = (A == B) ? ONE : ZERO; zero = ~(|out); end
            default: out = ZERO;
        endcase
    end

endmodule
