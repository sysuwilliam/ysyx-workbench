`timescale 1ns/1ns

`ifndef SYNTHESIS
import "DPI-C" function void npc_halt();
`endif

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
    wire [2:0]  wb_sel;
    wire        idu_mem_re;
    wire        idu_mem_we;
    wire [1:0]  mem_size;
    wire        jump;
    wire        ebreak;
    wire        illegal;
    wire [11:0] csr_addr;
    wire        csr_we;
    wire [31:0] csr_rdata;
    wire        csr_wen;

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
        .csr_addr(csr_addr),
        .csr_we(csr_we),
        .mem_re(idu_mem_re),
        .mem_we(idu_mem_we),
        .mem_size(mem_size),
        .jump(jump),
        .ebreak(ebreak),
        .illegal(illegal)
    );

    assign csr_wen = csr_we & commit_valid & ~trap;

    CSR u_csr (
        .clk(clock),
        .rst(reset),
        .csr_addr(csr_addr),
        .csr_we(csr_wen),
        .csr_wdata(rs1_data),
        .csr_rdata(csr_rdata)
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
        .csr_rdata(csr_rdata),
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

`ifndef SYNTHESIS
    wire [31:0] dbg_a0 = dbg_gpr[351:320];
    reg [63:0] dbg_instret;
    reg [63:0] dbg_cycles;
    reg [63:0] dbg_prog_instret;
    reg [63:0] dbg_prog_cycles;
    reg        dbg_started;
    always @(posedge clock) begin
        if (reset) begin
            dbg_instret      <= 64'd0;
            dbg_cycles       <= 64'd0;
            dbg_prog_instret <= 64'd0;
            dbg_prog_cycles  <= 64'd0;
            dbg_started      <= 1'b0;
        end else begin
            dbg_cycles <= dbg_cycles + 64'd1;
            if (commit_valid)
                dbg_instret <= dbg_instret + 64'd1;
            if (!dbg_started && pc[31]) begin
                dbg_started      <= 1'b1;
                dbg_prog_instret <= 64'd0;
                dbg_prog_cycles  <= 64'd0;
            end else if (dbg_started) begin
                dbg_prog_cycles <= dbg_prog_cycles + 64'd1;
                if (commit_valid)
                    dbg_prog_instret <= dbg_prog_instret + 64'd1;
            end
        end
    end
    always @(posedge clock) begin
        if (!reset && commit_valid && halt) begin
            $display("%s", dbg_a0 == 32'b0 ? "HIT GOOD TRAP" : "HIT BAD TRAP");
            $display("SoC IPC: instret=%0d cycles=%0d IPC=%0d.%03d",
                     dbg_instret, dbg_cycles,
                     ((dbg_instret * 1000) / dbg_cycles) / 1000,
                     ((dbg_instret * 1000) / dbg_cycles) % 1000);
            if (dbg_prog_cycles != 0)
                $display("SoC program IPC: instret=%0d cycles=%0d IPC=%0d.%03d",
                         dbg_prog_instret, dbg_prog_cycles,
                         ((dbg_prog_instret * 1000) / dbg_prog_cycles) / 1000,
                         ((dbg_prog_instret * 1000) / dbg_prog_cycles) % 1000);
            npc_halt();
        end
        if (!reset && commit_valid && trap) begin
            $display("TRAP pc=%08x", pc);
            npc_halt();
        end
    end
`endif

`ifdef YSYX_DEBUG
    reg [31:0] dbg_count;
    always @(posedge clock) begin
        if (reset)
            dbg_count <= 32'b0;
        else if (commit_valid) begin
            dbg_count <= dbg_count + 32'd1;
            if (dbg_count < 64 || (dbg_count % 1000 == 0))
                $fwrite(32'h80000002, "DBG pc=%08x inst=%08x n=%0d\n", pc, inst, dbg_count);
        end
    end
`endif

endmodule
