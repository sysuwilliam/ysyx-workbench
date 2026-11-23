`timescale 1ns/1ns

module IFU (
    input  wire        clk,
    input  wire        rst,
    input  wire        jump_en,
    input  wire [31:0] jump_target,
    input  wire        stop_now,
    input  wire [31:0] ifu_rdata,
    input  wire        lsu_re,
    output wire [31:0] pc,
    output wire [31:0] pc_plus4,
    output wire [31:0] ifu_raddr,
    output wire [31:0] inst,
    output wire        exec_valid,
    output wire        commit_valid
);

    localparam [1:0] S_IDLE = 2'b00;
    localparam [1:0] S_WAIT = 2'b01;
    localparam [1:0] S_LOAD = 2'b10;

    wire [1:0] state;
    reg  [1:0] state_next;
    wire       lsu_load;

    assign lsu_load = (state == S_WAIT) & lsu_re;

    always @(*) begin
        case (state)
            S_IDLE: state_next = S_WAIT;
            S_WAIT: state_next = (lsu_load & ~stop_now) ? S_LOAD : S_IDLE;
            S_LOAD: state_next = S_IDLE;
            default: state_next = S_IDLE;
        endcase
    end

    Reg #(.WIDTH(2), .RESET_VAL(S_IDLE)) u_state (
        .din(state_next),
        .dout(state),
        .wen(1'b1),
        .rst(rst),
        .clk(clk)
    );

    assign exec_valid   = (state == S_WAIT);
    assign commit_valid = ((state == S_WAIT) & ~lsu_load) | (state == S_LOAD);
    assign inst         = (state == S_IDLE) ? 32'h0000_0013 : ifu_rdata;
    assign ifu_raddr    = pc;

    wire [31:0] next_pc;
    wire unused_cout;

    mux #(.WIDTH(32), .NR_IN(2)) u_target_sel (
        .din({jump_target, pc_plus4}),
        .sel(jump_en),
        .dout(next_pc)
    );

    wire pc_en = (((state == S_WAIT) & ~lsu_load) | (state == S_LOAD)) & ~stop_now;

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
