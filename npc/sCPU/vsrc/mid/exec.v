`timescale 1ns/1ns

// exec —— 执行级
//
// 用途
//   计算 add 的和、bner0 的比较结果，并选择写回 GPR 的数据。
//
// 接口
//   端口
//     add_en       add 指令使能
//     li_en        li 指令使能
//     bner0_en     bner0 指令使能
//     rdata1       GPR 读端口 1
//     rdata2       GPR 读端口 2
//     imm8         li 立即数
//     io_in        io 输入数据
//     wdata        GPR 写回数据
//     branch_taken 分支是否成立
//
// 使用方法
//   rdata1/rdata2 来自 GPR；bner0 时译码器已把 raddr1 设为 0，
//   所以比较的是 R0 与 R[rs2]。wdata 按 add、li、io 三选一，
//   branch_taken 只在 bner0 且两数不等时为 1。
module exec (
    input  wire       add_en,
    input  wire       li_en,
    input  wire       bner0_en,
    input  wire [7:0] rdata1,
    input  wire [7:0] rdata2,
    input  wire [7:0] imm8,
    input  wire [7:0] io_in,
    output wire [7:0] wdata,
    output wire       branch_taken
);

    wire [7:0] sum;
    wire       equal;
    wire       unused_gt;
    wire       unused_lt;
    wire       unused_cout;

    adder #(.WIDTH(8)) u_add (
        .cin(1'b0),
        .a(rdata1),
        .b(rdata2),
        .cout(unused_cout),
        .sum(sum)
    );

    cmp #(.WIDTH(8)) u_cmp (
        .a(rdata1),
        .b(rdata2),
        .gt(unused_gt),
        .eq(equal),
        .lt(unused_lt)
    );

    assign branch_taken = bner0_en & ~equal;

    assign wdata = add_en ? sum : (li_en ? imm8 : io_in);

endmodule
