`timescale 1ns/1ns

// Instruction_Decoder —— sISA 指令译码
//
// 用途
//   把 ROM 输出的 8 位指令拆成字段，产生各模块需要的控制信号。
//
// 接口
//   端口
//     instr      8 位指令
//     add_en     add 指令使能
//     io_en      io 指令使能
//     li_en      li 指令使能
//     bner0_en   bner0 指令使能
//     raddr1     GPR 读端口 1 地址
//     raddr2     GPR 读端口 2 地址
//     waddr      GPR 写地址
//     gpr_wen    GPR 写使能
//     imm8       li 的 8 位立即数
//     offset     bner0 的 4 位补码偏移
//     io_dir     io 方向，1 输出、0 输入
//     idx        io 设备编号
//
// 使用方法
//   字段：add [5:4]rd [3:2]rs1 [1:0]rs2；io [5:4]rd [3]dir [2:0]idx；
//         li [5:4]rd [3:2]s [1:0]imm；bner0 [5:2]off [1:0]rs2。
//   bner0 的读端口 1 固定为 r0；io 输出从读端口 2 取 rd。
//   输入型 io 写 GPR，输出型 io 不写；branch_taken 由 bner0_en 与 neq
//   在上层相与产生，不在本模块里。
module Instruction_Decoder (
    input  wire [7:0] instr,
    output wire       add_en,
    output wire       io_en,
    output wire       li_en,
    output wire       bner0_en,
    output wire [1:0] raddr1,
    output wire [1:0] raddr2,
    output wire [1:0] waddr,
    output wire       gpr_wen,
    output wire [7:0] imm8,
    output wire [3:0] offset,
    output wire       io_dir,
    output wire [2:0] idx
);

    wire [1:0] opcode = instr[7:6];
    wire [1:0] rd     = instr[5:4];
    wire [1:0] rs1    = instr[3:2];
    wire [1:0] rs2    = instr[1:0];
    wire [1:0] s      = instr[3:2];
    wire [1:0] imm    = instr[1:0];

    assign add_en   = (opcode == 2'b00);
    assign io_en    = (opcode == 2'b01);
    assign li_en    = (opcode == 2'b10);
    assign bner0_en = (opcode == 2'b11);

    assign raddr1 = bner0_en ? 2'd0 : rs1;
    assign raddr2 = io_en ? rd : rs2;
    assign waddr  = rd;

    assign gpr_wen = add_en | li_en | (io_en & ~io_dir);

    assign imm8 = {6'b0, imm} << {s, 1'b0};

    assign offset = instr[5:2];
    assign io_dir = instr[3];
    assign idx    = instr[2:0];

endmodule
