`timescale 1ns/1ns

// ROM —— 256×8 指令存储器
//
// 用途
//   按 PC 的地址提供 8 位指令，组合读出，不做时序锁存。
//
// 接口
//   参数
//     ADDR_W  地址位宽，默认 8
//     DATA_W  数据位宽，默认 8
//   端口
//     addr    指令地址，接 PC 输出
//     instr   该地址的指令，接指令译码
//
// 使用方法
//   指令集（8 位，opcode = instr[7:6]）
//     add    00 rd rs1 rs2    R[rd] <- R[rs1] + R[rs2]
//     io     01 rd dir idx    dir=0 读设备到 R[rd]；dir=1 把 R[rd] 写到设备
//                             idx=000 拨码/LED，idx=001 按钮/DEC
//     li     10 rd s imm      R[rd] <- imm << (s*2)
//     bner0  11 off rs2       R[rs2] != R[0] 时 PC += sign_ext(off)，否则 PC+1
//
//     位布局：
//       add    [5:4]rd [3:2]rs1 [1:0]rs2
//       io     [5:4]rd [3]dir   [2:0]idx
//       li     [5:4]rd [3:2]s   [1:0]imm
//       bner0  [5:2]off [1:0]rs2
//     rd/rs1/rs2 对应 r0~r3，off 是 4 位补码。
//
//   addr 每个时钟周期由 PC 给出，instr 当拍有效，不需要时钟。
//   当前程序在循环内每累加一次就把结果同时写到 LED 和十进制数码管，再判断是否继续。
//   换程序时按上面的格式编码，直接改对应地址的 mem[] 行；
//   未列出的地址是全 0，会译码成 add r0,r0,r0，不是停机。
//   若要读外部 hex，可把 initial 换成 $readmemh，注意运行目录是 sCPU/。
module ROM #(
    parameter ADDR_W = 8,
    parameter DATA_W = 8
) (
    input  wire [ADDR_W-1:0] addr,
    output wire [DATA_W-1:0] instr
);

    reg [DATA_W-1:0] mem [0:(1<<ADDR_W)-1];
    integer i;

    initial begin
        for (i = 0; i < (1 << ADDR_W); i = i + 1) mem[i] = {DATA_W{1'b0}};
        mem[0]  = 8'b0100_0000;    // io    r0, SW
        mem[1]  = 8'b1001_0000;    // li    r1, 0
        mem[2]  = 8'b1010_0001;    // li    r2, 1
        mem[3]  = 8'b1011_0001;    // li    r3, 1
        mem[4]  = 8'b0000_0011;    // add   r0, r0, r3
        mem[5]  = 8'b1011_0001;    // li    r3, 1
        mem[6]  = 8'b0001_0110;    // add   r1, r1, r2
        mem[7]  = 8'b0101_1000;    // io    r1, LED（同时更新 DEC）
        mem[8]  = 8'b0010_1011;    // add   r2, r2, r3
        mem[9]  = 8'b1111_0110;    // bner0 r2, -3
        mem[10] = 8'b1100_0011;    // bner0 r3, 0（自循环）
    end

    assign instr = mem[addr];

endmodule
