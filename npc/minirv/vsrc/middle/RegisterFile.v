`timescale 1ns/1ns

// RegisterFile —— 通用寄存器堆
//
// 16 个 32 位寄存器。两个组合读口，一个时钟沿写口。
// 读 x0 恒为 0；写 x0 由 WBU 的 rf_we 挡掉，本模块保持讲义骨架。
// dbg_gpr 把 16 个寄存器摊平成 512 位，测试台按 32 位一组读取。

module RegisterFile #(
    parameter ADDR_WIDTH = 4,
    parameter DATA_WIDTH = 32
) (
    input  wire                     clk,
    input  wire                     wen,
    input  wire [ADDR_WIDTH - 1:0]  waddr,
    input  wire [DATA_WIDTH - 1:0]  wdata,
    input  wire [ADDR_WIDTH - 1:0]  raddr1,
    input  wire [ADDR_WIDTH - 1:0]  raddr2,
    output wire [DATA_WIDTH - 1:0]  rdata1,
    output wire [DATA_WIDTH - 1:0]  rdata2,
    output wire [((2**ADDR_WIDTH)*DATA_WIDTH)-1:0] dbg_gpr
);

    reg [DATA_WIDTH - 1:0] rf [0:(1<<ADDR_WIDTH)-1];

    always @(posedge clk) begin
        if (wen) rf[waddr] <= wdata;
    end

    wire [((2**ADDR_WIDTH)*DATA_WIDTH)-1:0] rf_flat;

    genvar i;
    generate
        for (i = 0; i < (1 << ADDR_WIDTH); i = i + 1) begin : g_dbg
            assign rf_flat[i*DATA_WIDTH +: DATA_WIDTH] = rf[i];
        end
    endgenerate

    assign dbg_gpr = rf_flat;

    wire [DATA_WIDTH - 1:0] rdata1_raw;
    mux #(.WIDTH(DATA_WIDTH), .NR_IN(1<<ADDR_WIDTH)) u_rdata1_sel (
        .din(rf_flat),
        .sel(raddr1),
        .dout(rdata1_raw)
    );

    mux #(.WIDTH(DATA_WIDTH), .NR_IN(2)) u_rdata1_if_x0 (
        .din({rdata1_raw, {DATA_WIDTH{1'b0}}}),
        .sel(|raddr1),
        .dout(rdata1)
    );

    wire [DATA_WIDTH - 1:0] rdata2_raw;
    mux #(.WIDTH(DATA_WIDTH), .NR_IN(1<<ADDR_WIDTH)) u_rdata2_sel (
        .din(rf_flat),
        .sel(raddr2),
        .dout(rdata2_raw)
    );

    mux #(.WIDTH(DATA_WIDTH), .NR_IN(2)) u_rdata2_if_x0 (
        .din({rdata2_raw, {DATA_WIDTH{1'b0}}}),
        .sel(|raddr2),
        .dout(rdata2)
    );

endmodule
