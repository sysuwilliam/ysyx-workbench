`timescale 1ns/1ns

// 模板电路：与门。替换成自己的实验模块，并同步修改文件名与模块名。
module template (
    input  wire a,
    input  wire b,
    output wire y
);
    assign y = a & b;
endmodule
