`timescale 1ns/1ns

// LSU —— 访存单元
//
// 纯组合。把 32 位数据通路与按字节寻址的存储器对接：
//   - 读通道：从读回的整字里按 addr[1:0] 挑出字节并零扩展
//   - 写通道：把 rs2 的数据挪到正确的字节通道，并生成字节使能
//   - 对齐检查：lw / sw 要求地址是 4 的倍数，未对齐时屏蔽访存并报错
// 存储器在 C++ 测试台里（csrc/pmem.h），本模块不保存数据、不算地址。

module LSU (
    input  wire [31:0] addr,      // EXU 算出的访存地址
    input  wire [31:0] rs2_data,  // store 的源数据
    input  wire [31:0] mem_rdata, // 顶层读回的对齐字
    input  wire [1:0]  size,      // 00 字，01 字节
    input  wire        mem_re,    // 读请求（未门控）
    input  wire        mem_we,    // 写请求（未门控）

    output wire [31:0] mem_wdata, // 移位到正确字节通道的写数据
    output wire [3:0]  mem_be,    // 字节写使能
    output wire        mem_re_o,  // 门控后的读请求
    output wire        mem_we_o,  // 门控后的写请求
    output wire [31:0] load_data, // 选好宽度并零扩展的读回值
    output wire        error      // 字访问但地址未对齐
);

    localparam [1:0] SIZE_WORD = 2'b00;
    localparam [1:0] SIZE_BYTE = 2'b01;

    wire [1:0] lane;
    wire       is_byte;
    wire       is_word;
    wire       misaligned;

    assign lane       = addr[1:0];
    assign is_byte    = (size == SIZE_BYTE);
    assign is_word    = (size == SIZE_WORD);
    assign misaligned = (lane != 2'b00);

    // ---- 读通道：整字 -> 字节 -> 零扩展 -> 按宽度选择 ----
    wire [7:0]  byte_sel;
    wire [31:0] byte32;

    // 第 i 路是 mem_rdata 的第 i 个字节，addr[1:0] 决定取哪个
    mux #(.WIDTH(8), .NR_IN(4)) u_byte_sel (
        .din(mem_rdata),
        .dout(byte_sel),
        .sel(lane)
    );

    // lbu 是零扩展；lw 不经过这一步
    ext #(.IN_W(8), .OUT_W(32), .SIGNED(0)) u_ext (
        .din(byte_sel),
        .dout(byte32)
    );

    // 第 0 路整字，第 1 路字节；is_byte 为 1 时取字节
    mux #(.WIDTH(32), .NR_IN(2)) u_load (
        .din({byte32, mem_rdata}),
        .dout(load_data),
        .sel(is_byte)
    );

    // ---- 写通道：数据移位 + 字节使能 ----
    wire [4:0]  shift;
    wire [3:0]  lane_oh;

    assign shift     = {lane, 3'b000};
    assign mem_wdata = rs2_data << shift;

    dec_onehot #(.IN_W(2), .OUT_W(4)) u_be (
        .en(1'b1),
        .sel(lane),
        .onehot(lane_oh)
    );

    assign mem_be = is_byte ? lane_oh : 4'b1111;

    // ---- 对齐检查与门控 ----
    // 只有字宽访问才要求对齐；非法指令时 IDU 已把 re/we 清零，不会误报
    assign error    = (mem_re | mem_we) & is_word & misaligned;
    assign mem_re_o = mem_re & ~error;
    assign mem_we_o = mem_we & ~error;

    // 地址高位不参与选字节；越界由 DPI-C 的 pmem 检查
    wire unused_addr_hi = &{1'b0, addr[31:2]};

endmodule
