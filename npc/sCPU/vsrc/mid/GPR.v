`timescale 1ns/1ns

// GPR —— 4×8 通用寄存器堆
//
// 用途
//   提供两个组合读端口和一个时钟写端口，对应 Logisim 里的 GPR_4。
//
// 接口
//   参数
//     DATA_W  寄存器位宽，默认 8
//   端口
//     clk      时钟
//     rst      同步复位，所有寄存器清 0
//     raddr1   读端口 1 地址
//     raddr2   读端口 2 地址
//     rdata1   读端口 1 数据
//     rdata2   读端口 2 数据
//     waddr    写地址
//     wdata    写数据
//     wen      写使能
//     r0~r3    四个寄存器的当前值，供调试与波形观察
//
// 使用方法
//   raddr1/raddr2/waddr 接指令译码输出，wen 接 gpr_wen。
//   写口在上升沿按 waddr 选一个寄存器写入，两个读口是组合读、当拍有效；
//   同一拍先写后读时，读口看到的是旧值。
//   Logisim 的寄存器上电即为 0，这里用 rst 把四个寄存器清 0。
module GPR #(
    parameter DATA_W = 8
) (
    input  wire              clk,
    input  wire              rst,
    input  wire [1:0]        raddr1,
    input  wire [1:0]        raddr2,
    output wire [DATA_W-1:0] rdata1,
    output wire [DATA_W-1:0] rdata2,
    input  wire [1:0]        waddr,
    input  wire [DATA_W-1:0] wdata,
    input  wire              wen,
    output wire [DATA_W-1:0] r0,
    output wire [DATA_W-1:0] r1,
    output wire [DATA_W-1:0] r2,
    output wire [DATA_W-1:0] r3
);

    wire [3:0] we_dec;
    wire [3:0] we;

    dec_onehot #(.IN_W(2), .OUT_W(4)) u_wdec (
        .en(1'b1),
        .sel(waddr),
        .onehot(we_dec)
    );

    assign we = we_dec & {4{wen}};

    Reg #(.WIDTH(DATA_W), .RESET_VAL({DATA_W{1'b0}})) u_r0 (
        .clk(clk), .rst(rst), .wen(we[0]), .din(wdata), .dout(r0)
    );

    Reg #(.WIDTH(DATA_W), .RESET_VAL({DATA_W{1'b0}})) u_r1 (
        .clk(clk), .rst(rst), .wen(we[1]), .din(wdata), .dout(r1)
    );

    Reg #(.WIDTH(DATA_W), .RESET_VAL({DATA_W{1'b0}})) u_r2 (
        .clk(clk), .rst(rst), .wen(we[2]), .din(wdata), .dout(r2)
    );

    Reg #(.WIDTH(DATA_W), .RESET_VAL({DATA_W{1'b0}})) u_r3 (
        .clk(clk), .rst(rst), .wen(we[3]), .din(wdata), .dout(r3)
    );

    mux #(.WIDTH(DATA_W), .NR_IN(4)) u_rd1 (
        .din({r3, r2, r1, r0}),
        .sel(raddr1),
        .dout(rdata1)
    );

    mux #(.WIDTH(DATA_W), .NR_IN(4)) u_rd2 (
        .din({r3, r2, r1, r0}),
        .sel(raddr2),
        .dout(rdata2)
    );

endmodule
