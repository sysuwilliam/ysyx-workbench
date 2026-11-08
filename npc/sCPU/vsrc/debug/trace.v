`timescale 1ns/1ns

// trace —— 指令跟踪与串口输出
//
// 用途
//   每执行一条指令，把它反汇编成明文，通过 UART 输出到 NVBoard 终端。
//
// 接口
//   参数
//     GAP  每行之后的空拍数，0 表示不插入间隔
//   端口
//     clk/rst   时钟与同步复位
//     exec      当前拍执行了一条指令
//     instr     当前指令的机器码
//     uart_tx   串口输出
//     busy      正在发送或间隔中，接 CPU 的 hold
//
// 使用方法
//   exec 为高时锁存 instr 并开始发送。每行固定 16 个字符加换行，
//   不足的位置补空格，格式如下：
//     add r1, r1, r2
//     li r1, 0x08
//     io r1, LED/DEC
//     bner0 r2, -2
//   busy 期间应暂停 CPU，避免下一条指令覆盖当前行。
module trace #(
    parameter GAP = 0
) (
    input  wire       clk,
    input  wire       rst,
    input  wire       exec,
    input  wire [7:0] instr,
    output wire       uart_tx,
    output wire       busy
);

    localparam S_IDLE = 2'd0;
    localparam S_SEND = 2'd1;
    localparam S_WAIT = 2'd2;
    localparam S_GAP  = 2'd3;

    function [7:0] hex_ascii;
        input [3:0] n;
        begin
            hex_ascii = (n < 4'd10) ? (8'h30 + {4'd0, n})
                                    : (8'h37 + {4'd0, n});
        end
    endfunction

    function [7:0] line_char;
        input [4:0] i;
        input [7:0] ins;
        reg [1:0] op;
        reg [1:0] rd;
        reg [1:0] rs1;
        reg [1:0] rs2;
        reg [1:0] s;
        reg [1:0] imm;
        reg [7:0] imm8;
        reg [3:0] off;
        reg [3:0] absoff;
        reg [7:0] signc;
        reg [7:0] dev0;
        reg [7:0] dev1;
        reg [7:0] dev2;
        begin
            op = ins[7:6];
            rd = ins[5:4];
            rs1 = ins[3:2];
            rs2 = ins[1:0];
            s = ins[3:2];
            imm = ins[1:0];
            imm8 = {6'b0, imm} << {s, 1'b0};
            off = ins[5:2];
            absoff = off[3] ? (~off + 4'd1) : off;
            signc = off[3] ? 8'h2d : 8'h2b;

            if (ins[3] == 1'b0 && ins[2:0] == 3'd0) begin
                dev0 = 8'h53; dev1 = 8'h57; dev2 = 8'h20;
            end else if (ins[3] == 1'b1 && ins[2:0] == 3'd0) begin
                dev0 = 8'h4c; dev1 = 8'h45; dev2 = 8'h44;
            end else if (ins[3] == 1'b0 && ins[2:0] == 3'd1) begin
                dev0 = 8'h42; dev1 = 8'h54; dev2 = 8'h4e;
            end else if (ins[3] == 1'b1 && ins[2:0] == 3'd1) begin
                dev0 = 8'h44; dev1 = 8'h45; dev2 = 8'h43;
            end else begin
                dev0 = 8'h49; dev1 = 8'h4f;
                dev2 = hex_ascii({1'b0, ins[2:0]});
            end

            if (i == 5'd16) begin
                line_char = 8'h0a;
            end else begin
                case (op)
                    2'b00: case (i)
                        5'd0: line_char = 8'h61;
                        5'd1: line_char = 8'h64;
                        5'd2: line_char = 8'h64;
                        5'd3: line_char = 8'h20;
                        5'd4: line_char = 8'h72;
                        5'd5: line_char = hex_ascii({2'b0, rd});
                        5'd6: line_char = 8'h2c;
                        5'd7: line_char = 8'h20;
                        5'd8: line_char = 8'h72;
                        5'd9: line_char = hex_ascii({2'b0, rs1});
                        5'd10: line_char = 8'h2c;
                        5'd11: line_char = 8'h20;
                        5'd12: line_char = 8'h72;
                        5'd13: line_char = hex_ascii({2'b0, rs2});
                        default: line_char = 8'h20;
                    endcase
                    2'b01: case (i)
                        5'd0: line_char = 8'h69;
                        5'd1: line_char = 8'h6f;
                        5'd2: line_char = 8'h20;
                        5'd3: line_char = 8'h72;
                        5'd4: line_char = hex_ascii({2'b0, rd});
                        5'd5: line_char = 8'h2c;
                        5'd6: line_char = 8'h20;
                        5'd7: line_char = dev0;
                        5'd8: line_char = dev1;
                        5'd9: line_char = dev2;
                        5'd10: line_char = (ins[3] && ins[2:0] == 3'd0) ? 8'h2f : 8'h20;
                        5'd11: line_char = (ins[3] && ins[2:0] == 3'd0) ? 8'h44 : 8'h20;
                        5'd12: line_char = (ins[3] && ins[2:0] == 3'd0) ? 8'h45 : 8'h20;
                        5'd13: line_char = (ins[3] && ins[2:0] == 3'd0) ? 8'h43 : 8'h20;
                        default: line_char = 8'h20;
                    endcase
                    2'b10: case (i)
                        5'd0: line_char = 8'h6c;
                        5'd1: line_char = 8'h69;
                        5'd2: line_char = 8'h20;
                        5'd3: line_char = 8'h72;
                        5'd4: line_char = hex_ascii({2'b0, rd});
                        5'd5: line_char = 8'h2c;
                        5'd6: line_char = 8'h20;
                        5'd7: line_char = 8'h30;
                        5'd8: line_char = 8'h78;
                        5'd9: line_char = hex_ascii(imm8[7:4]);
                        5'd10: line_char = hex_ascii(imm8[3:0]);
                        default: line_char = 8'h20;
                    endcase
                    default: case (i)
                        5'd0: line_char = 8'h62;
                        5'd1: line_char = 8'h6e;
                        5'd2: line_char = 8'h65;
                        5'd3: line_char = 8'h72;
                        5'd4: line_char = 8'h30;
                        5'd5: line_char = 8'h20;
                        5'd6: line_char = 8'h72;
                        5'd7: line_char = hex_ascii({2'b0, rs2});
                        5'd8: line_char = 8'h2c;
                        5'd9: line_char = 8'h20;
                        5'd10: line_char = signc;
                        5'd11: line_char = hex_ascii(absoff);
                        default: line_char = 8'h20;
                    endcase
                endcase
            end
        end
    endfunction

    wire [1:0]  state;
    wire [4:0]  idx;
    wire [7:0]  instr_lat;
    wire [31:0] gap_cnt;
    wire        uart_busy;
    wire        uart_done;

    wire uart_send = (state == S_SEND) && !uart_busy;
    wire [7:0] char_data = line_char(idx, instr_lat);

    uart_tx #(.CLK_PER_BIT(16)) u_uart (
        .clk(clk),
        .rst(rst),
        .send(uart_send),
        .data(char_data),
        .tx(uart_tx),
        .busy(uart_busy),
        .done(uart_done)
    );

    wire exec_start = (state == S_IDLE) && exec;
    wire line_done = (state == S_WAIT) && uart_done;
    wire last_char = (idx == 5'd16);
    wire to_gap = line_done && last_char && (GAP != 0);
    wire gap_end = (state == S_GAP) && (gap_cnt == 0);

    wire [1:0] state_next =
        exec_start ? S_SEND :
        (state == S_SEND) ? (uart_send ? S_WAIT : S_SEND) :
        (state == S_WAIT) ? (line_done ?
            (last_char ? ((GAP != 0) ? S_GAP : S_IDLE) : S_SEND) : S_WAIT) :
        (state == S_GAP) ? (gap_end ? S_IDLE : S_GAP) : S_IDLE;

    Reg #(.WIDTH(2), .RESET_VAL(S_IDLE)) u_state (
        .clk(clk),
        .rst(rst),
        .wen(1'b1),
        .din(state_next),
        .dout(state)
    );

    wire [4:0] idx_next = exec_start ? 5'd0 :
                          (line_done && !last_char) ? idx + 5'd1 : idx;

    Reg #(.WIDTH(5), .RESET_VAL(5'd0)) u_idx (
        .clk(clk),
        .rst(rst),
        .wen(1'b1),
        .din(idx_next),
        .dout(idx)
    );

    Reg #(.WIDTH(8), .RESET_VAL(8'd0)) u_instr (
        .clk(clk),
        .rst(rst),
        .wen(exec_start),
        .din(instr),
        .dout(instr_lat)
    );

    wire [31:0] gap_next = to_gap ? (GAP - 1) :
                           (state == S_GAP && gap_cnt != 0) ? gap_cnt - 1 : gap_cnt;
    wire gap_wen = to_gap || (state == S_GAP && gap_cnt != 0);

    Reg #(.WIDTH(32), .RESET_VAL(32'd0)) u_gap (
        .clk(clk),
        .rst(rst),
        .wen(gap_wen),
        .din(gap_next),
        .dout(gap_cnt)
    );

    assign busy = (state != S_IDLE);

endmodule
