`timescale 1ns/1ns

module ysyx_00000000 (
    input  wire        clock,
    input  wire        reset,
    output wire        io_ifu_reqValid,
    output wire [31:0] io_ifu_addr,
    input  wire        io_ifu_respValid,
    input  wire [31:0] io_ifu_rdata,
    output wire        io_lsu_reqValid,
    output wire [31:0] io_lsu_addr,
    output wire [1:0]  io_lsu_size,
    output wire        io_lsu_wen,
    output wire [31:0] io_lsu_wdata,
    output wire [3:0]  io_lsu_wmask,
    input  wire        io_lsu_respValid,
    input  wire [31:0] io_lsu_rdata
);

    wire [6:0]  opcode;
    wire [2:0]  funct3;
    wire [6:0]  funct7;
    wire [4:0]  rd5;
    wire [4:0]  rs1_5;
    wire [4:0]  rs2_5;
    wire [3:0]  rd;
    wire [3:0]  rs1;
    wire [3:0]  rs2;
    wire [31:0] imm_i;
    wire [31:0] imm_s;
    wire [31:0] imm_u;
    wire        gpr_we;
    wire [1:0]  alu_op;
    wire [1:0]  wb_sel;
    wire        idu_mem_re;
    wire        idu_mem_we;
    wire [1:0]  mem_size;
    wire        jump;
    wire        ebreak;
    wire        illegal;

    wire [31:0] pc;
    wire [31:0] pc_plus4;
    wire [31:0] rs1_data;
    wire [31:0] rs2_data;
    wire [31:0] alu_result;
    wire [31:0] exu_mem_addr;
    wire [31:0] jump_target;
    wire        jump_misalign;
    wire [31:0] rf_wdata;
    wire [3:0]  rf_waddr;
    wire        rf_we;
    wire        rf_wen;
    wire [31:0] lsu_load_data;
    wire [31:0] lsu_mem_wdata;
    wire        lsu_mem_re;
    wire        lsu_mem_we;
    wire [3:0]  lsu_mem_be;
    wire        lsu_error;
    wire [511:0] dbg_gpr;

    wire trap;
    wire halt;
    wire stop_now;
    wire jump_en;

    assign trap     = exec_valid & (illegal | (jump & jump_misalign) | lsu_error);
    assign halt     = exec_valid & ebreak;
    assign stop_now = trap | halt;
    assign jump_en  = exec_valid & jump & ~illegal & ~jump_misalign;
    assign rf_wen   = rf_we & ~trap & commit_valid;

    wire [31:0] inst;
    wire        exec_valid;
    wire        commit_valid;

    IFU #(.RESET_PC(32'h3000_0000)) u_ifu (
        .clk(clock),
        .rst(reset),
        .jump_en(jump_en),
        .jump_target(jump_target),
        .stop_now(stop_now),
        .ifu_rdata(io_ifu_rdata),
        .ifu_respValid(io_ifu_respValid),
        .lsu_re(lsu_mem_re),
        .lsu_we(lsu_mem_we),
        .lsu_respValid(io_lsu_respValid),
        .ifu_reqValid(io_ifu_reqValid),
        .ifu_addr(io_ifu_addr),
        .lsu_reqValid(io_lsu_reqValid),
        .pc(pc),
        .pc_plus4(pc_plus4),
        .inst(inst),
        .exec_valid(exec_valid),
        .commit_valid(commit_valid)
    );

    IDU u_idu (
        .inst(inst),
        .opcode(opcode),
        .funct3(funct3),
        .funct7(funct7),
        .rd5(rd5),
        .rs1_5(rs1_5),
        .rs2_5(rs2_5),
        .rd(rd),
        .rs1(rs1),
        .rs2(rs2),
        .imm_i(imm_i),
        .imm_s(imm_s),
        .imm_u(imm_u),
        .gpr_we(gpr_we),
        .alu_op(alu_op),
        .wb_sel(wb_sel),
        .mem_re(idu_mem_re),
        .mem_we(idu_mem_we),
        .mem_size(mem_size),
        .jump(jump),
        .ebreak(ebreak),
        .illegal(illegal)
    );

    RegisterFile u_rf (
        .clk(clock),
        .wen(rf_wen),
        .waddr(rf_waddr),
        .wdata(rf_wdata),
        .raddr1(rs1),
        .raddr2(rs2),
        .rdata1(rs1_data),
        .rdata2(rs2_data),
        .dbg_gpr(dbg_gpr)
    );

    EXU u_exu (
        .rs1_data(rs1_data),
        .rs2_data(rs2_data),
        .imm_i(imm_i),
        .imm_s(imm_s),
        .imm_u(imm_u),
        .opcode(opcode),
        .alu_op(alu_op),
        .alu_result(alu_result),
        .mem_addr(exu_mem_addr),
        .jump_target(jump_target),
        .jump_misalign(jump_misalign)
    );

    WBU u_wbu (
        .alu_result(alu_result),
        .mem_rdata(lsu_load_data),
        .imm_u(imm_u),
        .pc_plus4(pc_plus4),
        .wb_sel(wb_sel),
        .rd(rd),
        .gpr_we(gpr_we),
        .rf_wdata(rf_wdata),
        .rf_waddr(rf_waddr),
        .rf_we(rf_we)
    );

    LSU u_lsu (
        .addr(exu_mem_addr),
        .rs2_data(rs2_data),
        .mem_rdata(io_lsu_rdata),
        .size(mem_size),
        .mem_re(idu_mem_re),
        .mem_we(idu_mem_we),
        .mem_wdata(lsu_mem_wdata),
        .mem_be(lsu_mem_be),
        .mem_re_o(lsu_mem_re),
        .mem_we_o(lsu_mem_we),
        .load_data(lsu_load_data),
        .error(lsu_error)
    );

    assign io_lsu_addr  = exu_mem_addr;
    assign io_lsu_size  = (mem_size == 2'b00) ? 2'b10 : 2'b00;
    assign io_lsu_wen   = lsu_mem_we;
    assign io_lsu_wdata = lsu_mem_wdata;
    assign io_lsu_wmask = lsu_mem_be;

    wire unused_fields = &{1'b0, funct3, funct7, rd5, rs1_5, rs2_5};
    wire unused_gpr = &{1'b0, dbg_gpr};

endmodule
