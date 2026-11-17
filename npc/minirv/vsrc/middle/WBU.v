`timescale 1ns/1ns

// WBU —— 写回单元
//
// 纯组合。按 wb_sel 选写回来源，挡掉 x0 的写入，输出写地址与写使能。
// trap 不在这里处理，顶层再用 ~trap 与一次。

module WBU (
    input  wire [31:0] alu_result,
    input  wire [31:0] mem_rdata,
    input  wire [31:0] imm_u,
    input  wire [31:0] pc_plus4,
    input  wire [1:0]  wb_sel,
    input  wire [3:0]  rd,
    input  wire        gpr_we,

    output wire [31:0] rf_wdata,
    output wire [3:0]  rf_waddr,
    output wire        rf_we
);

    // 写回来源：00 ALU · 01 MEM · 10 IMM · 11 PC+4
    mux #(.WIDTH(32), .NR_IN(4)) u_wb_sel (
        .din({pc_plus4, imm_u, mem_rdata, alu_result}),
        .dout(rf_wdata),
        .sel(wb_sel)
    );

    // x0 的写入在这里丢弃；读 x0 由 RegisterFile 的 mux 保证
    assign rf_waddr = rd;
    assign rf_we    = gpr_we & (|rd);

endmodule
