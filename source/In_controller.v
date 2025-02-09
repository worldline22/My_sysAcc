/*
    buffer_top_counter
            |
            V
----------------------
｜1｜2｜3｜4｜5｜6｜7｜8｜
----------------------
*/

//buffer输入到时候需要干3件事：
/*
1. buffer2-->buffer_data
2. buffer_data-->PE
3. mem-->buffer2
其中必做的事情为：1
if(buffer2[left].size() < buffer_data[left].size()) {
    2
}
else if(buffer2[left].size() > buffer_data[left].size()) {
    3
}
else (buffer2[left].size() == buffer_data[left].size()) {
    2 + 3
}
*/

module In_controller#(
    parameter integer DATA_WIDTH = 64,          //mem的数据位宽
    parameter integer ADDR_WIDTH = 23,          //mem的地址位宽
    parameter integer BUFFER_DATA_WIDTH = 8,    //内部buffer的数据位宽
    parameter integer TOP_BUFFER_RANGE = 8,     //top buffer的大小
    parameter integer MAC_SIZE = 32,
    parameter integer B_ADDR_HEAD = 15,
    parameter integer BIG_MAC_SIZE  = 512
)(
    input clk, comp_enb,                        //时钟和使能信号
    input [DATA_WIDTH-1:0] data_in,             //外部输入数据
    output reg done_in_enb,                     // 低有效
    output wire [ADDR_WIDTH-1:0] mem_address,   // mem的地址，和inputmem进行交互的内容
    output reg mem_read_enb,                     // mem的读使能
    output reg copy_enb                         // 复制使能
);


assign  mem_address = (state == S_TMP) ? mem_addr_B + (1 << B_ADDR_HEAD) : mem_addr_A;


reg [ADDR_WIDTH-1:0] mem_addr_A;                                             // mem的地址，和inputmem进行交互的内容
reg [ADDR_WIDTH-1:0] mem_addr_B;                                           // A,B矩阵的buffer地址

parameter integer BUFFER_ADDR_WIDTH = $clog2(MAC_SIZE);                    //buffer的地址位宽
parameter integer TOP_BUFFER_ADDR = $clog2(TOP_BUFFER_RANGE);              //top buffer的地址位宽
parameter integer COUNTER_ADDR_WIDTH = $clog2(BIG_MAC_SIZE-MAC_SIZE) + 1;  //计数器的地址位宽
parameter integer DIVIDE = BIG_MAC_SIZE / MAC_SIZE;                        //用来表示平行四边形矩阵的大小
parameter integer HEAD_ADDR_SHIFT = B_ADDR_HEAD - $clog2(DIVIDE);       //用来表示buffer的头地址
output reg [BUFFER_DATA_WIDTH-1:0] buffer_A [0:MAC_SIZE-1];                // A矩阵的buffer
output reg [BUFFER_DATA_WIDTH-1:0] buffer_B [0:MAC_SIZE-1];                // B矩阵的buffer
reg [BUFFER_ADDR_WIDTH-1:0] buffer_addr;                                   // A,B矩阵的buffer地址


reg [BUFFER_DATA_WIDTH-1:0] buffer_top_A [0:TOP_BUFFER_RANGE-1];           // A矩阵的top buffer
reg [BUFFER_DATA_WIDTH-1:0] buffer_top_B [0:TOP_BUFFER_RANGE-1];           // B矩阵的top buffer
reg [TOP_BUFFER_ADDR-1:0] buffer_top_addr;                                 // A,B矩阵的top buffer地址

reg [2:0] state;
parameter S_RST = 0, S_UPPER = 1, S_LOWER = 2, S_TMP = 3, S_DONE_1 = 5, S_MIDDLE = 4, S_DONE_2 = 6, S_DONE_3 = 7;//状态机的5种状态
                                                                            //S_TMP主要用来处理（读取）buffer_B的数据

reg [MAC_SIZE-1:0] buffer_cycle;                                            //表示是第几层的平行四边形矩阵输入

wire [BUFFER_DATA_WIDTH-1:0] res_state_1;                                   //表示buffer_A中还有多少个数据
wire [BUFFER_DATA_WIDTH-1:0] res_state_2;                                   //表示buffer_B中还有多少个数据
wire [BUFFER_DATA_WIDTH-1:0] res_state_3;                                   //表示buffer_top_A中还有多少个数据

wire [BUFFER_DATA_WIDTH-1:0] num_iter_1;                                    //表示比较buffer_A和buffer_top_A的大小
wire [BUFFER_DATA_WIDTH-1:0] num_iter_2;                                    //表示比较buffer_B和buffer_top_B的大小
wire [BUFFER_DATA_WIDTH-1:0] num_iter_3;                                    //表示比较buffer_A和buffer_top_B的大小

assign res_state_1 = buffer_cycle + 1 - buffer_addr;
assign res_state_2 = MAC_SIZE - buffer_addr;
assign res_state_3 = TOP_BUFFER_RANGE - buffer_top_addr;

assign num_iter_1 = (res_state_1 < res_state_3) ? res_state_1 : res_state_3;
assign num_iter_2 = (res_state_2 < res_state_3) ? res_state_2 : res_state_3;

reg [2:0] next_state;
reg [COUNTER_ADDR_WIDTH + 1:0] counter_cycle;                                 //计数器
integer i;


//为了实现整体矩阵的乘法，需要再加一个状态机，用来控制buffer的输入和输出

reg [$clog2(DIVIDE) - 1:0] row_A;
reg [$clog2(DIVIDE) - 1:0] col_B;

always @(posedge clk) begin
    if(comp_enb) begin
        state <= S_RST;
        mem_addr_A <= 0;
        mem_addr_B <= 0;
        mem_read_enb <= 0;
        buffer_addr <= 0;
        buffer_top_addr <= 0;
        copy_enb <= 0;
        counter_cycle <= 0;
        done_in_enb <= 1;
        row_A <= 0;
        col_B <= 0;
        for(i = 0; i < MAC_SIZE; i = i + 1) begin
            buffer_A[i] <= 0;
            buffer_B[i] <= 0;
        end
        for(i = 0; i < TOP_BUFFER_RANGE; i = i + 1) begin
            buffer_top_A[i] <= 0;
            buffer_top_B[i] <= 0;
        end
    end else begin
        case(state) 
            S_RST: begin
                if(~comp_enb) begin
                    state <= S_TMP;
                    next_state <= S_UPPER;
                    buffer_cycle <= 0;
                    buffer_addr <= 0;
                    copy_enb <= 0;
                    done_in_enb <= 1;
                    {buffer_top_A[0], buffer_top_A[1], buffer_top_A[2], buffer_top_A[3], 
                    buffer_top_A[4], buffer_top_A[5], buffer_top_A[6], buffer_top_A[7]} <= data_in;
                    mem_addr_A <= mem_addr_A + 1;
                end
            end

            S_UPPER: begin
                for(i = 0; i < num_iter_1; i = i + 1) begin
                    buffer_A[buffer_addr + i] <= buffer_top_A[buffer_top_addr + i];
                    buffer_B[buffer_addr + i] <= buffer_top_B[buffer_top_addr + i];
                end
                buffer_top_addr <= buffer_top_addr + num_iter_1;
                if(res_state_1 == num_iter_1) begin
                    if(buffer_cycle == (MAC_SIZE - 1)) begin
                        next_state <= S_MIDDLE;                     //通过next_state来控制状态机的状态
                        buffer_cycle <= 0;
                        buffer_addr <= 0;
                        counter_cycle <= 0;
                    end else begin
                        buffer_cycle <= buffer_cycle + 1;
                        buffer_addr <= 0;
                    end
                    done_in_enb <= 0;
                end else begin
                    buffer_addr <= buffer_addr + num_iter_1;
                    done_in_enb <= 1;
                end

                if(res_state_3 == num_iter_1) begin
                    {buffer_top_A[0], buffer_top_A[1], buffer_top_A[2], buffer_top_A[3], 
                    buffer_top_A[4], buffer_top_A[5], buffer_top_A[6], buffer_top_A[7]} <= data_in;
                    mem_addr_A <= mem_addr_A + 1;
                    state <= S_TMP;
                end
            end

            S_MIDDLE: begin
                for(i = 0; i < TOP_BUFFER_RANGE; i = i + 1) begin
                    buffer_A[buffer_addr + i] <= buffer_top_A[i];
                    buffer_B[buffer_addr + i] <= buffer_top_B[i];
                end
                if(buffer_addr == MAC_SIZE - TOP_BUFFER_RANGE) begin
                    if(counter_cycle == (BIG_MAC_SIZE - MAC_SIZE) - 1) begin
                        next_state <= S_LOWER;
                        counter_cycle <= 0;
                        buffer_cycle <= 0;
                        buffer_addr <= 1;
                    end else begin
                        buffer_addr <= 0;
                        counter_cycle <= counter_cycle + 1;
                    end
                    done_in_enb <= 0;
                end else begin
                    buffer_addr <= buffer_addr + TOP_BUFFER_RANGE;
                    done_in_enb <= 1;
                end

                {buffer_top_A[0], buffer_top_A[1], buffer_top_A[2], buffer_top_A[3], 
                buffer_top_A[4], buffer_top_A[5], buffer_top_A[6], buffer_top_A[7]} <= data_in;
                mem_addr_A <= mem_addr_A + 1;
                state <= S_TMP;
            end

            S_LOWER: begin
                for(i = 0; i < num_iter_2; i = i + 1) begin
                    buffer_A[buffer_addr + i] <= buffer_top_A[buffer_top_addr + i];
                    buffer_B[buffer_addr + i] <= buffer_top_B[buffer_top_addr + i];
                end
                buffer_top_addr <= buffer_top_addr + num_iter_2;
                if(res_state_2 == num_iter_2) begin
                    buffer_A[buffer_cycle] <= 0;
                    buffer_B[buffer_cycle] <= 0;
                    buffer_cycle <= buffer_cycle + 1;
                    next_state <= (buffer_cycle == (MAC_SIZE - 2)) ? S_DONE_1 : S_LOWER;
                    buffer_addr <= buffer_cycle + 1 + 1;
                    done_in_enb <= 0;
                end else begin
                    buffer_addr <= buffer_addr + num_iter_2;
                    done_in_enb <= 1;
                end

                if(res_state_3 == num_iter_2) begin
                    {buffer_top_A[0], buffer_top_A[1], buffer_top_A[2], buffer_top_A[3], 
                    buffer_top_A[4], buffer_top_A[5], buffer_top_A[6], buffer_top_A[7]} <= data_in;
                    mem_addr_A <= mem_addr_A + 1;
                    state <= S_TMP;
                end
            end

            S_TMP: begin
                {buffer_top_B[0], buffer_top_B[1], buffer_top_B[2], buffer_top_B[3],
                buffer_top_B[4], buffer_top_B[5], buffer_top_B[6], buffer_top_B[7]} <= data_in;
                state <= next_state;
                mem_addr_B <= mem_addr_B + 1;
                done_in_enb <= 1;
            end

            S_DONE_1: begin
                done_in_enb <= 0;
                counter_cycle <= counter_cycle + 1;
                if(counter_cycle == MAC_SIZE-1)begin
                    copy_enb <= 1;
                    col_B <= col_B + 1;
                    if(col_B == DIVIDE - 1) begin
                        row_A <= row_A + 1;
                        if(row_A == DIVIDE - 1) begin
                            state <= S_DONE_3;
                        end else begin
                            state <= S_DONE_2;
                        end
                    end else begin
                        state <= S_DONE_2;
                    end
                end
                buffer_A[MAC_SIZE - 1] <= 0;
                buffer_B[MAC_SIZE - 1] <= 0;
            end

            S_DONE_2: begin
                done_in_enb <= 0;
                copy_enb <= 0;
                mem_addr_A <= row_A << HEAD_ADDR_SHIFT;
                mem_addr_B <= col_B << HEAD_ADDR_SHIFT;
                state <= S_RST;
            end

            default: begin
                done_in_enb <= 0;
                copy_enb <= 0;
                if(comp_enb) begin
                    state <= S_RST;
                end
            end
        endcase
    end
end

endmodule