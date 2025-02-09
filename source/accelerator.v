`include "PE.v"
`include "In_controller.v"
`include "Out_controller.v"
module accelerator #(
    parameter integer INPUT_DATA_WIDTH  = 64,   //输入的数据位宽
    parameter integer INPUT_ADDR_WIDTH  = 23,   //输入的地址位宽
    parameter integer RESULT_DATA_WIDTH = 64,   //输出的数据位宽
    parameter integer RESULT_ADDR_WIDTH = 23,   //输出的地址位宽
    parameter integer MAC_SIZE = 512,            //决定矩阵的大小
    parameter integer BIG_MAC_SIZE = 512
) (
    input clk,                                  //时钟信号  
    input comp_enb,  
    output [INPUT_ADDR_WIDTH-1:0] mem_addr,     //内存地址
    input [INPUT_DATA_WIDTH-1:0] mem_data,      //内存数据
    output mem_read_enb,                        //内存读使能
    output mem_write_enb,                       //内存写使能
    output [RESULT_ADDR_WIDTH-1:0] res_addr,    //结果地址
    output [RESULT_DATA_WIDTH-1:0] res_data,    //结果数据
    output busyb,                               //忙信号
    output done                                 //完成信号
);

parameter BUFFER_DATA_WIDTH = 8;                                    //缓存数据位宽
parameter PE_DATA_WIDTH = 24;                                       //PE的数据位宽
parameter B_AHEAD = $clog2(BIG_MAC_SIZE)+$clog2(BIG_MAC_SIZE)-3;    //缓存的地址位宽

wire done_in_enb;                                       //PE和Out_controller的完成信号
wire [BUFFER_DATA_WIDTH-1:0] buffer_A [0:MAC_SIZE-1];   //缓存A
wire [BUFFER_DATA_WIDTH-1:0] buffer_B [0:MAC_SIZE-1];   //缓存B

In_controller #(
    .DATA_WIDTH(INPUT_DATA_WIDTH),
    .ADDR_WIDTH(INPUT_ADDR_WIDTH),
    .BUFFER_DATA_WIDTH(8),
    .TOP_BUFFER_RANGE(8),
    .MAC_SIZE(MAC_SIZE),
    .B_ADDR_HEAD(B_AHEAD),
    .BIG_MAC_SIZE(BIG_MAC_SIZE)
) in_controller (
    .clk(clk),
    .comp_enb(comp_enb),
    .data_in(mem_data),
    .done_in_enb(done_in_enb),
    .mem_read_enb(mem_read_enb),
    .mem_address(mem_addr),
    .copy_enb(copy_enb),
    .buffer_A(buffer_A),
    .buffer_B(buffer_B)
);

reg [1:0] state;                                            //状态机状态
parameter S_RST = 0, S_WORK = 1, S_DONE = 2;                //状态机的三种状态
parameter integer BUFFER_ADDR_WIDTH = $clog2(MAC_SIZE) + 1; //缓存地址位宽

always @(posedge clk) begin
    if(comp_enb) begin
        state <= S_RST;
        done_finish <= 0;
    end else begin
        case(state)
            S_RST: begin
                if(~comp_enb) begin
                    state <= S_WORK;
                    counter <= 0;
                end
            end
            S_WORK: begin
                if(done_finish) begin
                    state <= S_DONE;
                end
            end
            default: begin
                if(comp_enb) begin
                    state <= S_RST;
                end
            end
        endcase
    end
end

wire [BUFFER_DATA_WIDTH-1:0] up [0:MAC_SIZE-1][0:MAC_SIZE-1];           //缓存数据
wire [BUFFER_DATA_WIDTH-1:0] left [0:MAC_SIZE-1][0:MAC_SIZE-1];         //缓存数据
wire [BUFFER_DATA_WIDTH-1:0] down [0:MAC_SIZE-1][0:MAC_SIZE-1];         //缓存数据
wire [BUFFER_DATA_WIDTH-1:0] right [0:MAC_SIZE-1][0:MAC_SIZE-1];        //缓存数据
wire [PE_DATA_WIDTH-1:0] pe_result [0:MAC_SIZE-1][0:MAC_SIZE-1];        //PE的结果
wire done_out [0:MAC_SIZE-1][0:MAC_SIZE-1];                             //PE的完成信号
reg [PE_DATA_WIDTH-1:0] pe_result_store [0:MAC_SIZE-1][0:MAC_SIZE-1];   //PE的结果


wire copy_enb;
reg copy_enb_reg;

always @(posedge clk) begin
    copy_enb_reg <= copy_enb;
end



genvar t;
for (t = 0; t < MAC_SIZE; t = t + 1) begin
    assign left[t][0] = buffer_A[t];
    assign up[0][t] = buffer_B[t];
end

genvar i, j;
generate
    for (i = 0; i < MAC_SIZE; i = i + 1) begin : PE_GEN_ROW
        for (j = 0; j < MAC_SIZE; j = j + 1) begin: PE_GEN_COL
            PE #(
                .DATA_WIDTH(PE_DATA_WIDTH),
                .BUFFER_DATA_WIDTH(BUFFER_DATA_WIDTH),
                .MAC_SIZE(MAC_SIZE)
            ) pe (
                .clk(clk),
                .up(up[i][j]),
                .left(left[i][j]),
                .enable_b(done_in_enb),
                .comp_enb(comp_enb),
                .reset_b(copy_enb),
                .right(right[i][j]),
                .down(down[i][j]),
                .out_data(pe_result[i][j])
            );
            if(i != MAC_SIZE - 1) begin
                assign up[i + 1][j] = down[i][j];
            end
            if(j != MAC_SIZE - 1) begin
                assign left[i][j + 1] = right[i][j];
            end
        end
    end
endgenerate

reg done_finish;
always @(posedge clk) begin
    if(copy_enb)begin
        done_finish <= 1;
        for(int i = 0; i < MAC_SIZE; i = i + 1) begin
            for(int j = 0; j < MAC_SIZE; j = j + 1) begin
                pe_result_store[i][j] <= pe_result[i][j];
            end
        end
    end
    else begin
        done_finish <= 0;
    end
end

Out_controller #(
    .DATA_IN_WIDTH(24),
    .ADDR_IN_WIDTH(18),
    .DATA_OUT_WIDTH(64),
    .ADDR_OUT_WIDTH(23),
    .MAC_SIZE(MAC_SIZE)
) Out_controller (
    .clk(clk),
    .comp_enb(comp_enb),
    .pe_result(pe_result_store),
    .done_out(done_out),
    .done_finish(done_finish),
    .mem_write_enb(mem_write_enb),
    .busyb(busyb),
    .done(done),
    .res_out_addr(res_addr),
    .res_data(res_data)
);

endmodule