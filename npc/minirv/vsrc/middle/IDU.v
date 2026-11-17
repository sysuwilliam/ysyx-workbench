`timescale 1ns/1ns

// IDU —— 译码单元
//
// 纯组合，无状态。字段拆分、三种立即数、九条指令的控制与合法性检查。
// 寄存器下标先按 5 位检查，再截成 4 位送寄存器堆。
// 支持 addi / add / lui / lw / lbu / sw / sb / jalr / ebreak。
// 控制顺序：先给默认值，再按 opcode 覆盖，最后统一清掉非法指令的副作用。

module IDU (
    // 待译码的指令
    input  wire [31:0] inst,

    // 指令字段原样输出
    output wire [6:0]  opcode,
    output wire [2:0]  funct3,
    output wire [6:0]  funct7,

    // 5 位下标只用于合法性检查，4 位下标送寄存器堆
    output wire [4:0]  rd5,
    output wire [4:0]  rs1_5,
    output wire [4:0]  rs2_5,

    output wire [3:0]  rd,
    output wire [3:0]  rs1,
    output wire [3:0]  rs2,

    // 三种立即数
    output wire [31:0] imm_i,
    output wire [31:0] imm_s,
    output wire [31:0] imm_u,

    // 控制信号
    output reg         gpr_we,   // 写回时是否写通用寄存器
    output reg  [1:0]  alu_op,   // ALU 操作
    output reg  [1:0]  wb_sel,   // 写回源选择

    output reg         mem_re,   // 读存储器
    output reg         mem_we,   // 写存储器
    output reg  [1:0]  mem_size, // 访问宽度

    output reg         jump,     // 跳转
    output reg         ebreak,   // 停机
    output reg         illegal   // 非法指令
);

    // 各类指令的 opcode
    localparam [6:0] OP_LOAD   = 7'b0000011;
    localparam [6:0] OP_STORE  = 7'b0100011;
    localparam [6:0] OP_IMM    = 7'b0010011;
    localparam [6:0] OP_REG    = 7'b0110011;
    localparam [6:0] OP_LUI    = 7'b0110111;
    localparam [6:0] OP_JALR   = 7'b1100111;
    localparam [6:0] OP_SYSTEM = 7'b1110011;

    // 各指令用到的 funct3
    localparam [2:0] F3_LW   = 3'b010;
    localparam [2:0] F3_LBU  = 3'b100;
    localparam [2:0] F3_SW   = 3'b010;
    localparam [2:0] F3_SB   = 3'b000;
    localparam [2:0] F3_ADDI = 3'b000;
    localparam [2:0] F3_ADD  = 3'b000;
    localparam [2:0] F3_JALR = 3'b000;

    // add 的 funct7，其它取值视为非法
    localparam [6:0] F7_ADD = 7'b0000000;

    // ebreak 的完整机器码
    localparam [31:0] INSN_EBREAK = 32'h00100073;

    // ALU 操作编码
    localparam [1:0] ALU_ADD  = 2'b00;
    localparam [1:0] ALU_PASS = 2'b01;

    // 写回来源编码
    localparam [1:0] WB_ALU = 2'b00;
    localparam [1:0] WB_MEM = 2'b01;
    localparam [1:0] WB_IMM = 2'b10;
    localparam [1:0] WB_PC4 = 2'b11;

    // 访存宽度编码
    localparam [1:0] SIZE_WORD = 2'b00;
    localparam [1:0] SIZE_BYTE = 2'b01;

    // 字段拆分
    assign opcode = inst[6:0];
    assign funct3 = inst[14:12];
    assign funct7 = inst[31:25];

    assign rd5   = inst[11:7];
    assign rs1_5 = inst[19:15];
    assign rs2_5 = inst[24:20];

    assign rd  = rd5[3:0];
    assign rs1 = rs1_5[3:0];
    assign rs2 = rs2_5[3:0];

    // 立即数生成：I 型、S 型符号扩展，U 型低位补零
    assign imm_i = {{20{inst[31]}}, inst[31:20]};
    assign imm_s = {{20{inst[31]}}, inst[31:25], inst[11:7]};
    assign imm_u = {inst[31:12], 12'b0};

    // 先给控制信号默认值，再由 case 按需覆盖，避免推断锁存器
    always @(*) begin
        gpr_we   = 1'b0;
        alu_op   = ALU_ADD;
        wb_sel   = WB_ALU;
        mem_re   = 1'b0;
        mem_we   = 1'b0;
        mem_size = SIZE_WORD;
        jump     = 1'b0;
        ebreak   = 1'b0;
        illegal  = 1'b0;

        case (opcode)

        // addi rd, rs1, imm
        OP_IMM: begin
            if ((funct3 != F3_ADDI) || rd5[4] || rs1_5[4]) begin
                illegal = 1'b1;
            end else begin
                gpr_we = 1'b1;
                alu_op = ALU_ADD;
                wb_sel = WB_ALU;
            end
        end

        // R 型：funct3 + funct7 共同判别 add，三个寄存器下标都要在 x0..x15
        OP_REG: begin
            if ((funct3 != F3_ADD) || (funct7 != F7_ADD) ||
                rd5[4] || rs1_5[4] || rs2_5[4]) begin
                illegal = 1'b1;
            end else begin
                gpr_we = 1'b1;
                alu_op = ALU_ADD;
                wb_sel = WB_ALU;
            end
        end

        // U 型：bits 14:12 属于立即数，不查 funct3；只查 rd
        OP_LUI: begin
            if (rd5[4]) begin
                illegal = 1'b1;
            end else begin
                gpr_we = 1'b1;
                alu_op = ALU_PASS;
                wb_sel = WB_IMM;
            end
        end

        // I 型 load：funct3 区分 lw / lbu；rs2 字段是立即数，不查
        OP_LOAD: begin
            if (rd5[4] || rs1_5[4]) begin
                illegal = 1'b1;
            end else if (funct3 == F3_LW) begin
                gpr_we   = 1'b1;
                alu_op   = ALU_ADD;
                wb_sel   = WB_MEM;
                mem_re   = 1'b1;
                mem_size = SIZE_WORD;
            end else if (funct3 == F3_LBU) begin
                gpr_we   = 1'b1;
                alu_op   = ALU_ADD;
                wb_sel   = WB_MEM;
                mem_re   = 1'b1;
                mem_size = SIZE_BYTE;
            end else begin
                illegal = 1'b1;
            end
        end

        // S 型 store：funct3 区分 sw / sb；rs1、rs2 都是寄存器，rd 字段是 imm[4:0]
        OP_STORE: begin
            if (rs1_5[4] || rs2_5[4]) begin
                illegal = 1'b1;
            end else if (funct3 == F3_SW) begin
                alu_op   = ALU_ADD;
                mem_we   = 1'b1;
                mem_size = SIZE_WORD;
            end else if (funct3 == F3_SB) begin
                alu_op   = ALU_ADD;
                mem_we   = 1'b1;
                mem_size = SIZE_BYTE;
            end else begin
                illegal = 1'b1;
            end
        end

        // jalr：目标由 EXU 加法并清 bit0，未对齐由 EXU 与顶层判
        OP_JALR: begin
            if ((funct3 != F3_JALR) || rd5[4] || rs1_5[4]) begin
                illegal = 1'b1;
            end else begin
                gpr_we = 1'b1;
                alu_op = ALU_ADD;
                wb_sel = WB_PC4;
                jump   = 1'b1;
            end
        end

        // SYSTEM：只认整字 ebreak，其余 SYSTEM 编码非法
        OP_SYSTEM: begin
            if (inst == INSN_EBREAK) begin
                ebreak = 1'b1;
            end else begin
                illegal = 1'b1;
            end
        end

        default: illegal = 1'b1;

        endcase

        // 非法指令不产生任何副作用
        if (illegal) begin
            gpr_we = 1'b0;
            mem_re = 1'b0;
            mem_we = 1'b0;
            jump   = 1'b0;
            ebreak = 1'b0;
        end
    end

endmodule
