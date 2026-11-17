`timescale 1ns/1ns

// EXU —— 执行单元
//
// 纯组合，无时钟。选择立即数与操作数 B，做加法或直通，
// 输出 ALU 结果、访存地址、jalr 目标与目标对齐错误。
// 九条指令共用这一套通路。

module EXU (
    input  wire [31:0] rs1_data,
    input  wire [31:0] rs2_data,
    input  wire [31:0] imm_i,
    input  wire [31:0] imm_s,
    input  wire [31:0] imm_u,
    input  wire [6:0]  opcode,
    input  wire [1:0]  alu_op,

    output wire [31:0] alu_result,
    output wire [31:0] mem_addr,
    output wire [31:0] jump_target,
    output wire        jump_misalign
);

    localparam [6:0] OP_REG   = 7'b0110011;
    localparam [1:0] ALU_PASS = 2'b01;

    // 立即数选择：00 imm_i，01 imm_s，10 imm_u，11 保留为 0
    // 按 opcode 选择：lui 用 imm_u，store 用 imm_s，其余用 imm_i
    wire [1:0]  imm_sel;
    wire [31:0] imm_chosen;

    localparam [6:0] OP_LUI   = 7'b0110111;
    localparam [6:0] OP_STORE = 7'b0100011;

    assign imm_sel = (opcode == OP_LUI)   ? 2'b10 :
                     (opcode == OP_STORE) ? 2'b01 : 2'b00;

    mux #(.WIDTH(32), .NR_IN(4)) u_imm_sel (
        .din({32'b0, imm_u, imm_s, imm_i}),
        .dout(imm_chosen),
        .sel(imm_sel)
    );

    // 操作数 B：R 型取 rs2，其余取立即数
    wire        is_reg;
    wire [31:0] op_b;

    assign is_reg = (opcode == OP_REG);

    mux #(.WIDTH(32), .NR_IN(2)) u_op_b (
        .din({rs2_data, imm_chosen}),
        .dout(op_b),
        .sel(is_reg)
    );

    // 加法：rs1 + op_b，进位丢弃
    wire [31:0] sum;
    wire        unused_cout;

    adder #(.WIDTH(32)) u_add (
        .a(rs1_data),
        .b(op_b),
        .cin(1'b0),
        .cout(unused_cout),
        .sum(sum)
    );

    // 结果选择：alu_op 为 01 时直通 op_b（lui），否则用求和结果
    wire alu_pass;

    assign alu_pass = (alu_op == ALU_PASS);

    mux #(.WIDTH(32), .NR_IN(2)) u_result (
        .din({op_b, sum}),
        .dout(alu_result),
        .sel(alu_pass)
    );

    assign mem_addr      = alu_result;
    assign jump_target   = alu_result & 32'hffff_fffe;

    // 目标已清 bit0，bit1 为 1 表示不是 4 的倍数；是否跳转由顶层用 jump 门控
    assign jump_misalign = jump_target[1];

endmodule
