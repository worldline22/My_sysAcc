module Out_controller #(
    parameter integer DATA_IN_WIDTH = 24,
    parameter integer ADDR_IN_WIDTH = 18,
    parameter integer DATA_OUT_WIDTH = 64,
    parameter integer ADDR_OUT_WIDTH = 23,
    parameter integer MAC_SIZE = 128
)(
    input clk, comp_enb,
    input [DATA_IN_WIDTH-1:0] pe_result [0:MAC_SIZE-1][0:MAC_SIZE-1],
    input done_out [0:MAC_SIZE-1][0:MAC_SIZE-1],
    input done_finish,
    output reg mem_write_enb,
    output reg busyb,
    output reg done,
    output reg [ADDR_OUT_WIDTH-1:0] res_out_addr,
    output reg [DATA_OUT_WIDTH-1:0] res_data
); 

parameter ADDR_WIDTH = $clog2(MAC_SIZE);
parameter S_RST = 0, S_WRT = 1, S_DONE = 2;                  //4种状态，归一化的、同时读入读出的、只读出的、完成
reg [1:0] state;
reg [ADDR_WIDTH-1:0] col;
reg [ADDR_WIDTH-1:0] row;



always @(posedge clk) begin
    if(comp_enb) begin
        state <= S_RST;
        res_out_addr <= -1;
        res_data <= 0;
        mem_write_enb <= 0;
        row <= 0;
        col <= 0;
    end
    else begin
    case(state)
        S_RST: begin
            if(~comp_enb && done_finish) begin
                state <= S_WRT;
                col <= 0;
                row <= 0;
            end
        end

        S_WRT: begin
            res_data <= { {8'b0}, pe_result[row][col], {8'b0}, pe_result[row][col + 1] };// 将四个部分连接在一起，并将结果赋值给 res_data
            res_out_addr <= res_out_addr + 1;
            if(col == MAC_SIZE - 2) begin
                if(row == MAC_SIZE-1) begin
                    state <= S_RST;
                end 
                row <= row + 1;
            end
            col <= col + 2;
        end

        default: begin                                                                  //算完力
            mem_write_enb <= 0;
        end

    endcase
    end
end

always @(posedge clk) begin
    case (state) 
        S_RST: begin
            busyb <= 1;
            done <= 0;
        end
        S_DONE: begin
            busyb <= 0;
            done <= 1;
        end
        default: begin
            busyb <= 0;
            done <= 0;
        end
    endcase
end
            
endmodule