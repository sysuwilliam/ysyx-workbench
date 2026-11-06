// ============================================================================
// key_ctrl —— 键盘字节流解释器
//
//   单个码字         “我按下了这个键”
//   F0 打头，跟码字   “我松开了这个键”
//   E0 打头          “接下来是方向键那类扩展键”
//   E0 F0 打头       “扩展键松开了”
//
// 本实验只验收字符和数字键，扩展键整段跳过去：不显示、不计数。
//
// 敲一下 A 再松开，FIFO 依次吐出 1C、F0、1C：
//   第 1 件 1C  正常状态收到码字 → 按下：code=1C，show=1，count 加一
//   第 2 件 F0  正常状态收到 F0   → 进入松手状态，别的都不动
//   第 3 件 1C  松手状态收到码字 → 松开的正是 A → show=0，回到正常
//
// 四个状态：
//   S_NORMAL     正常，等一个码字
//   S_BREAK      刚收到 F0，下一帧是松手码
//   S_EXT        刚收到 E0，下一帧是扩展键的码
//   S_EXT_BREAK  刚收到 E0 F0，下一帧是扩展键的松手码
//
//   S_NORMAL --F0--> S_BREAK --任意码--> S_NORMAL
//   S_NORMAL --E0--> S_EXT   --F0--> S_EXT_BREAK --任意码--> S_NORMAL
//                             --其它码--> S_NORMAL
// ============================================================================
module key_ctrl (
    input        clk,
    input        clrn,
    input  [7:0] data,
    input        ready,
    output reg   nextdata_n,
    output reg [7:0] code,
    output reg [7:0] count,
    output reg   show
);

    localparam [1:0] S_NORMAL    = 2'd0,
                     S_BREAK     = 2'd1,
                     S_EXT       = 2'd2,
                     S_EXT_BREAK = 2'd3;

    reg [7:0] cur_byte;       // 手里的字节，下一拍解码；不能叫 byte，SV 保留字
    reg [1:0] state;
    reg       taking;         // 本拍已签收，下一拍拆包

    always @(posedge clk) begin
        if (clrn == 0) begin
            nextdata_n <= 1'b1;
            cur_byte   <= 8'h00;
            state      <= S_NORMAL;
            taking     <= 1'b0;
            code       <= 8'h00;
            count      <= 8'h00;
            show       <= 1'b0;
        end
        else begin
            nextdata_n <= 1'b1;

            if (!taking && ready) begin
                // 签收拍：同一拍存下 data，FIFO 下一拍前移读指针，data 会变
                cur_byte   <= data;
                nextdata_n <= 1'b0;
                taking     <= 1'b1;
            end
            else if (taking) begin
                // 拆包拍：只看 cur_byte
                taking <= 1'b0;

                case (state)
                    S_NORMAL: begin
                        if (cur_byte == 8'hF0) begin
                            state <= S_BREAK;
                        end
                        else if (cur_byte == 8'hE0) begin
                            state <= S_EXT;
                        end
                        else if (show && (cur_byte == code)) begin
                            // 按住重复发码，忽略
                        end
                        else begin
                            code <= cur_byte;
                            show <= 1'b1;
                            if (count < 8'd99)
                                count <= count + 1'b1;
                        end
                    end

                    S_BREAK: begin
                        // 松开的正是当前键才熄灯
                        if (cur_byte == code)
                            show <= 1'b0;
                        state <= S_NORMAL;
                    end

                    S_EXT: begin
                        // 扩展键一律忽略
                        if (cur_byte == 8'hF0)
                            state <= S_EXT_BREAK;
                        else
                            state <= S_NORMAL;
                    end

                    S_EXT_BREAK: begin
                        state <= S_NORMAL;
                    end
                endcase
            end
        end
    end

endmodule
