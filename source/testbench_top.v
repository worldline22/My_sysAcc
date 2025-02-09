`timescale 1ns / 1ns  // Syntax: time-unit / time-precision
`include "accelerator.v"
`include "mem.v"

`define T 2                   // Clock period
`define SIMULATION_CYCLE  300000  // Clock cycle number needed for a simulation
`define INPUT_DATA_WIDTH  64   // Data width for input memory
`define INPUT_ADDR_WIDTH  23  // Address width for input memory
`define RESULT_DATA_WIDTH 64   // Data width for result memory
`define RESULT_ADDR_WIDTH 23  // Address width for result memory
`define MAC_SIZE 128            // MAC size
`define BIG_MAC_SIZE 512        // Big MAC size

module testbench_top;

  initial begin
    $dumpfile("wave.vcd");  //  the dumpfile
    $dumpvars(0);  // Dump everything into the dumpfile
  end

  reg clk = 0;
  initial begin
    clk = 0;
    forever #(`T/2) clk = ~clk;  // 100 MHz clock
  end
  reg comp_enb;
  wire [`INPUT_ADDR_WIDTH-1:0] mem_addr;
  wire [`INPUT_DATA_WIDTH-1:0] mem_data;
  wire mem_read_enb;
  wire mem_write_enb;
  wire [`RESULT_ADDR_WIDTH-1:0] res_addr;
  wire [`RESULT_DATA_WIDTH-1:0] res_data;
  wire busyb, done;

  // Accelerator
  accelerator #(
      .INPUT_DATA_WIDTH (`INPUT_DATA_WIDTH),
      .INPUT_ADDR_WIDTH (`INPUT_ADDR_WIDTH),
      .RESULT_DATA_WIDTH(`RESULT_DATA_WIDTH),
      .RESULT_ADDR_WIDTH(`RESULT_ADDR_WIDTH),
      .MAC_SIZE        (`MAC_SIZE),
      .BIG_MAC_SIZE    (`BIG_MAC_SIZE)
  ) inst_accelerator (
        .clk          (clk)
      , .comp_enb     (comp_enb)
      , .mem_addr     (mem_addr)
      , .mem_data     (mem_data)
      , .mem_read_enb (mem_read_enb)
      , .mem_write_enb(mem_write_enb)
      , .res_addr     (res_addr)
      , .res_data     (res_data)
      , .busyb        (busyb)
      , .done         (done)
  );

  // Input memory
  ram #(
      .DATA_WIDTH(`INPUT_DATA_WIDTH),
      .ADDR_WIDTH(`INPUT_ADDR_WIDTH)
  ) inst_input_mem (
        .clk    (clk)
      , .web    (~mem_read_enb)
      , .address(mem_addr)
      , .d      ()
      , .q      (mem_data)
      , .cs     (1'b1)
  );

  // Result memory
  ram #(
      .DATA_WIDTH(`RESULT_DATA_WIDTH),
      .ADDR_WIDTH(`RESULT_ADDR_WIDTH)
  ) inst_res_mem (
        .clk    (clk)
      , .web    (mem_write_enb)
      , .address(res_addr)
      , .d      (res_data)
      , .q      (),
        .cs     (1'b1)
  );

  integer i, result_file;
  initial begin
    $readmemh("input_mem_rebuilt.csv", inst_input_mem.mem);
    
    comp_enb = 1;
    #(`T) comp_enb = 0;

    // Finish simulation
    #(`SIMULATION_CYCLE * `T) begin
      // Write result memory content to "result_mem.csv"
      result_file = $fopen("result_mem.csv", "w");
      for (i = 0; i < (1 << (`RESULT_ADDR_WIDTH-3)); i++) begin
        $fwrite(result_file, "%64b\n", inst_res_mem.mem[i]);
      end
      $fclose(result_file);
      $finish;
    end
  end
endmodule
