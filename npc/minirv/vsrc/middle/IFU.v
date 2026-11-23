`timescale 1ns/1ns

module IFU (
    input  wire        clk,
    input  wire        rst,
    input  wire        jump_en,
    input  wire [31:0] jump_target,
    input  wire        stop_now,
    input  wire [31:0] ifu_rdata,
    input  wire        ifu_respValid,
    input  wire        lsu_re,
    input  wire        lsu_we,
    input  wire        lsu_respValid,
    output wire        ifu_reqValid,
    output wire [31:0] ifu_addr,
    output wire        lsu_reqValid,
    output wire [31:0] pc,
    output wire [31:0] pc_plus4,
    output wire [31:0] inst,
    output wire        exec_valid,
    output wire        commit_valid
);

    localparam [1:0] S_IDLE  = 2'b00;
    localparam [1:0] S_FETCH = 2'b01;
    localparam [1:0] S_DWAIT = 2'b10;

    wire [1:0]  state;
    reg  [1:0]  state_next;
    reg  [31:0] ir;
    reg         stopped;

    wire fetch_hit    = (state == S_FETCH) & ifu_respValid;
    wire mem_op       = lsu_re | lsu_we;
    wire mem_go       = fetch_hit & mem_op & ~stop_now;
    wire fetch_commit = fetch_hit & ~mem_go;
    wire data_commit  = (state == S_DWAIT) & lsu_respValid;

    assign ifu_reqValid = (state == S_IDLE) & ~stopped;
    assign ifu_addr     = pc;
    assign exec_valid   = fetch_hit;
    assign lsu_reqValid = mem_go;
    assign commit_valid = fetch_commit | data_commit;

    assign inst = (state == S_FETCH) ? (ifu_respValid ? ifu_rdata : 32'h0000_0013)
                : (state == S_DWAIT) ? ir
                : 32'h0000_0013;

    always @(*) begin
        case (state)
            S_IDLE:  state_next = stopped ? S_IDLE : S_FETCH;
            S_FETCH: state_next = fetch_hit ? (mem_go ? S_DWAIT : S_IDLE) : S_FETCH;
            S_DWAIT: state_next = lsu_respValid ? S_IDLE : S_DWAIT;
            default: state_next = S_IDLE;
        endcase
    end

    always @(posedge clk) begin
        if (rst)
            ir <= 32'b0;
        else if (fetch_hit)
            ir <= ifu_rdata;
    end

    always @(posedge clk) begin
        if (rst)
            stopped <= 1'b0;
        else if (fetch_commit && stop_now)
            stopped <= 1'b1;
    end

    Reg #(.WIDTH(2), .RESET_VAL(S_IDLE)) u_state (
        .din(state_next),
        .dout(state),
        .wen(1'b1),
        .rst(rst),
        .clk(clk)
    );

    wire [31:0] next_pc;
    wire unused_cout;

    mux #(.WIDTH(32), .NR_IN(2)) u_target_sel (
        .din({jump_target, pc_plus4}),
        .sel(jump_en),
        .dout(next_pc)
    );

    wire pc_commit = fetch_commit | data_commit;
    wire pc_en     = pc_commit & ~stop_now;

    Reg #(.WIDTH(32), .RESET_VAL(32'h8000_0000)) u_PC (
        .din(next_pc),
        .dout(pc),
        .wen(pc_en),
        .rst(rst),
        .clk(clk)
    );

    adder #(.WIDTH(32)) u_pc_plus4 (
        .a(pc),
        .b(32'd4),
        .sum(pc_plus4),
        .cin(1'b0),
        .cout(unused_cout)
    );

endmodule
