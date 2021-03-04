`timescale 1ns/1ps
/*
module sum:
function first in first out
able to write data and read data to/from this fifo
*/
module fifo
#(  // Parameters
  parameter          DATA_WIDTH                   = 64,
  parameter          INIT                         = "init.mif",
  parameter          ADDR_WIDTH                   = 4,
  parameter          RAM_DEPTH                    = (1 << ADDR_WIDTH),
  parameter          INITIALIZE_FIFO              = "no",
  parameter          TYPE                         = "distributed"
)(  // Ports
  input  wire                                         clk,
  input  wire                                         reset,
  input  wire                                         s_write_req,
  input  wire                                         s_read_req,
  input  wire  [ DATA_WIDTH           -1 : 0 ]        s_write_data,
  output reg   [ DATA_WIDTH           -1 : 0 ]        s_read_data,
  output wire                                         s_read_ready,
  output wire                                         s_write_ready,
  output wire                                         almost_full,
  output wire                                         almost_empty
);

// Port Declarations
// ******************************************************************
// Internal variables
// ******************************************************************
  reg                                         empty;
  reg                                         full;

  reg  [ ADDR_WIDTH              : 0 ]        fifo_count;

  reg  [ ADDR_WIDTH           -1 : 0 ]        wr_pointer; //Write Pointer
  reg  [ ADDR_WIDTH           -1 : 0 ]        rd_pointer; //Read Pointer

  reg _almost_full;//near 4 free space left
  reg _almost_empty;//near 4 space used
  /*
  ||||    ...      ||||
  0  AE           AF  FULL
  */

  (* ram_style = TYPE *)
  reg     [DATA_WIDTH   -1 : 0 ]    mem[0:RAM_DEPTH-1]; //mem bits: RAM_DEPTH * DATA_WIDTH
// ******************************************************************
// FIFO Logic
// ******************************************************************
  initial begin
    if (INITIALIZE_FIFO == "yes") begin
      $readmemh(INIT, mem, 0, RAM_DEPTH-1);
    end
  end

  //Fifo status(empty or full) logic
  always @ (fifo_count)
  begin : FIFO_STATUS
    empty   = (fifo_count == 0);
    full    = (fifo_count == RAM_DEPTH);
  end

  //_almost_full reg part
  always @(posedge clk)//almost_full part (4 free space)
  begin
    if (reset)
      _almost_full <= 1'b0;//set almost full to 0
    else if (s_write_req && !s_read_req && fifo_count == RAM_DEPTH-4)//write data while 4 space left, set almost full to 1
      _almost_full <= 1'b1;
    else if (~s_write_req && s_read_req && fifo_count == RAM_DEPTH-4)//read data while 4 space left, cancel almost full
      _almost_full <= 1'b0;
  end
  assign almost_full = _almost_full;//reg output

  //_almost_empty reg part
  always @(posedge clk)//almost_empty part (4 mem space used)
  begin
    if (reset)
      _almost_empty <= 1'b0;
    else if (~s_write_req && s_read_req && fifo_count == 4)//set almost empty to 1 if (4 used and read needed)
      _almost_empty <= 1'b1;
    else if (s_write_req && ~s_read_req && fifo_count == 4)//cancel almost empty if (4 used and write in need)
      _almost_empty <= 1'b0;
  end
  assign almost_empty = _almost_empty;//reg output

  assign s_read_ready = !empty;//read is ready while not empty
  assign s_write_ready = !full;//write is ready while not full

  //fifo counters reg part
  always @ (posedge clk)
  begin : FIFO_COUNTER
    if (reset)
      fifo_count <= 0;//reset counter

    else if (s_write_req && (!s_read_req||s_read_req&&empty) && !full)//has a write req and not full and (no read req or want to read but empty[read and write both have req])
      fifo_count <= fifo_count + 1;

    else if (s_read_req && (!s_write_req||s_write_req&&full) && !empty)//both have req but write is full;
      fifo_count <= fifo_count - 1;
  end

  always @ (posedge clk)
  begin : WRITE_PTR
    if (reset) begin
      wr_pointer <= 0;
    end
    else if (s_write_req && !full) begin//has a write req and not full, able to write
      wr_pointer <= wr_pointer + 1;
    end
  end

  always @ (posedge clk)
  begin : READ_PTR
    if (reset) begin
      rd_pointer <= 0;
    end
    else if (s_read_req && !empty) begin//has a read req and not empty, able to read
      rd_pointer <= rd_pointer + 1;
    end
  end

  always @ (posedge clk)
  begin : WRITE
    if (s_write_req & !full) begin
      mem[wr_pointer] <= s_write_data;//write data to wr pointer
    end
  end

  always @ (posedge clk)
  begin : READ
    if (reset) begin
      s_read_data <= 0;
    end
    if (s_read_req && !empty) begin
      s_read_data <= mem[rd_pointer];//read data from rd ptr
    end
    else begin
      s_read_data <= s_read_data;//no read req or empty
    end
  end

endmodule
