`timescale 1ns/1ns

`ifndef SYNTHESIS
import "DPI-C" function void npc_ebreak_halt();
import "DPI-C" function int  pmem_read(input int raddr);
import "DPI-C" function void pmem_write(input int waddr, input int wdata, input byte wmask);
`endif

module minirv_top (
    // ---- 时钟与复位 ----
    input  wire         clk,      // 系统时钟，测试台手动翻转
    input  wire         rst,      // 同步复位，高有效

    // ---- 取指地址 ----
    output wire [31:0]  pc,       // 当前指令地址，也是取指地址

    // ---- 综合用存储器接口（仿真时不使用） ----
    input  wire [31:0]  inst_rdata, // 取指读回的对齐字
    input  wire [31:0]  data_rdata, // 数据读回的对齐字
    output wire [31:0]  mem_addr,   // 数据访存地址
    output wire [31:0]  mem_wdata,  // 写数据（已移位）
    output wire [3:0]   mem_be,     // 字节写使能
    output wire         mem_re,     // 数据读请求
    output wire         mem_we,     // 数据写请求

    // ---- 调试端口 ----
    output wire [511:0] dbg_gpr,  // gpr[i] 位于 dbg_gpr[i*32 +: 32]
    output wire         dbg_exec, // 本拍处理了一条指令（沿前组合信号）
    output wire         dbg_halt, // ebreak 停机（沿后有效）
    output wire         dbg_trap  // 非法指令、跳转未对齐或访存未对齐（沿后有效）
);

    // ---- IDU 输出：指令字段、立即数、控制 ----
    wire [6:0]  opcode;    // inst[6:0]，决定指令大类
    wire [2:0]  funct3;    // inst[14:12]，指令功能字段
    wire [6:0]  funct7;    // inst[31:25]，R 型功能字段
    wire [4:0]  rd5;       // 5 位目标下标，只用于合法性检查
    wire [4:0]  rs1_5;     // 5 位源下标 1，只用于合法性检查
    wire [4:0]  rs2_5;     // 5 位源下标 2，只用于合法性检查
    wire [3:0]  rd;        // 截断后的目标下标，送 RegisterFile 与 WBU
    wire [3:0]  rs1;       // 截断后的源下标 1，送 RegisterFile 读口 1
    wire [3:0]  rs2;       // 截断后的源下标 2，送 RegisterFile 读口 2
    wire [31:0] imm_i;     // I 型立即数（已符号扩展）
    wire [31:0] imm_s;     // S 型立即数
    wire [31:0] imm_u;     // U 型立即数
    wire        gpr_we;    // 这条指令是否要写 rd
    wire [1:0]  alu_op;    // ALU 操作：00 加法，01 直通
    wire [1:0]  wb_sel;    // 写回来源：00 ALU，01 MEM，10 IMM，11 PC+4
    wire        idu_mem_re;// 读访存请求
    wire        idu_mem_we;// 写访存请求
    wire [1:0]  mem_size;  // 访存宽度，送 LSU
    wire        jump;      // jalr 的跳转请求
    wire        ebreak;    // ebreak 停机请求
    wire        illegal;   // 非法指令标志

    // ---- IFU / RegisterFile / EXU / WBU 之间的连线 ----
    wire [31:0] pc_plus4;  // 当前 pc + 4，jalr 的链接值
    wire [31:0] rs1_data;  // RegisterFile 读口 1 的数据
    wire [31:0] rs2_data;  // RegisterFile 读口 2 的数据
    wire [31:0] alu_result;// EXU 的主结果，写回来源 00
    wire [31:0] exu_mem_addr; // EXU 算出的访存地址
    wire [31:0] jump_target;  // jalr 目标，最低位已清零
    wire        jump_misalign;// jalr 目标不是 4 的倍数
    wire [31:0] rf_wdata;  // WBU 选出的写回数据
    wire [3:0]  rf_waddr;  // WBU 的写地址（等于 rd）
    wire        rf_we;     // WBU 的写使能（已挡掉 x0）
    wire        rf_wen;    // rf_we 再与 ~trap，接 RegisterFile
    wire [31:0] lsu_load_data;  // LSU 选好宽度并扩展后的读回值
    wire [31:0] lsu_mem_wdata;  // LSU 移位后的写数据
    wire        lsu_mem_re;     // LSU 门控后的读请求
    wire        lsu_mem_we;     // LSU 门控后的写请求
    wire [3:0]  lsu_mem_be;     // LSU 生成的字节写使能
    wire        lsu_error;      // 字访问但地址未对齐

    // ---- 控制汇总 ----
    // trap：非法指令、jalr 目标未对齐或访存未对齐。
    // halt：本实现只把 ebreak 当停机。
    // stop_now：任一停机原因成立就冻结 pc。
    // jump_en：只有合法且对齐的 jalr 才真正跳转。
    wire trap;
    wire halt;
    wire stop_now;
    wire jump_en;

    assign trap     = exec_valid & (illegal | (jump & jump_misalign) | lsu_error);
    assign halt     = exec_valid & ebreak;
    assign stop_now = trap | halt;
    assign jump_en  = exec_valid & jump & ~illegal & ~jump_misalign;
    assign rf_wen   = rf_we & ~trap & commit_valid;

    wire [31:0] ifu_raddr;
    wire [31:0] ifu_rdata;
    wire [31:0] inst;
    wire        exec_valid;
    wire        commit_valid;

`ifdef SYNTHESIS
    assign ifu_rdata = inst_rdata;
`else
    reg [31:0] ifu_rdata_r;
    assign ifu_rdata = ifu_rdata_r;

    always @(posedge clk) begin
        if (rst)
            ifu_rdata_r <= 32'b0;
        else
            ifu_rdata_r <= pmem_read(ifu_raddr);
    end
`endif

    IFU u_ifu (
        .clk(clk),
        .rst(rst),
        .jump_en(jump_en),
        .jump_target(jump_target),
        .stop_now(stop_now),
        .ifu_rdata(ifu_rdata),
        .lsu_re(lsu_mem_re),
        .pc(pc),
        .pc_plus4(pc_plus4),
        .ifu_raddr(ifu_raddr),
        .inst(inst),
        .exec_valid(exec_valid),
        .commit_valid(commit_valid)
    );

    // 译码：字段拆分、三种立即数、控制信号、非法检查
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

    // 寄存器堆：两个组合读口 + 一个时钟沿写口，x0 的读与写在内部与 WBU 分别处理
    RegisterFile u_rf (
        .clk(clk),
        .wen(rf_wen),
        .waddr(rf_waddr),
        .wdata(rf_wdata),
        .raddr1(rs1),
        .raddr2(rs2),
        .rdata1(rs1_data),
        .rdata2(rs2_data),
        .dbg_gpr(dbg_gpr)
    );

    // 执行：按 opcode 选操作数 B，加法或直通，输出结果与跳转目标
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

    // 写回：按 wb_sel 选来源，挡掉 rd=x0 的写入
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
        .mem_rdata(mem_rdata),
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

    // 数据读：仿真走 DPI-C，综合走顶层输入 data_rdata
`ifdef SYNTHESIS
    wire [31:0] lsu_rdata;
    wire [31:0] mem_rdata;
    assign lsu_rdata = data_rdata;
    assign mem_rdata = lsu_rdata;
`else
    reg [31:0] lsu_rdata_r;
    wire [31:0] lsu_rdata;
    wire [31:0] mem_rdata;
    assign lsu_rdata = lsu_rdata_r;
    assign mem_rdata = lsu_rdata;

    always @(posedge clk) begin
        if (rst)
            lsu_rdata_r <= 32'b0;
        else if (exec_valid && lsu_mem_re)
            lsu_rdata_r <= pmem_read(exu_mem_addr);
        else if (exec_valid && lsu_mem_we)
            lsu_rdata_r <= 32'b0;
    end
`endif

    // 综合时把访存信号拉到顶层；仿真时这些输出不使用
    assign mem_addr  = exu_mem_addr;
    assign mem_wdata = lsu_mem_wdata;
    assign mem_be    = lsu_mem_be;
    assign mem_re    = lsu_mem_re & exec_valid;
    assign mem_we    = lsu_mem_we & exec_valid;

    // 数据写：仿真时只在 store 且对齐检查通过时于时钟沿写入 pmem
`ifndef SYNTHESIS
    always @(posedge clk) begin
        if (!rst && exec_valid && lsu_mem_we)
            pmem_write(exu_mem_addr, lsu_mem_wdata, {4'b0000, lsu_mem_be});
    end
`endif

    // ---- 调试输出 ----
    assign dbg_exec = commit_valid;

    // dbg_halt / dbg_trap 必须是寄存器：测试台在时钟沿之后才读它们判断停机原因。
    Reg #(.WIDTH(1)) u_dbg_halt (
        .din(halt),
        .dout(dbg_halt),
        .wen(exec_valid),
        .rst(rst),
        .clk(clk)
    );

    Reg #(.WIDTH(1)) u_dbg_trap (
        .din(trap),
        .dout(dbg_trap),
        .wen(exec_valid),
        .rst(rst),
        .clk(clk)
    );

`ifndef SYNTHESIS
    always @(posedge clk) begin
        if (!rst && exec_valid && halt)
            npc_ebreak_halt();
    end
`endif

    // IDU 的字段目前没人用：用一根归约线吃掉，避免 -Wall 报未使用。
    wire unused_fields = &{1'b0, funct3, funct7, rd5, rs1_5, rs2_5};

`ifndef SYNTHESIS
    // 综合接口在仿真中不驱动，用归约线吃掉，避免 lint 报未使用。
    wire unused_synth_inputs = &{1'b0, inst_rdata, data_rdata};
`endif

endmodule
