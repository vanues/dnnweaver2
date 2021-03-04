`timescale 1ns/1ps
/*
输入和输出数据总线宽度不一致的同步fifo（非对称同步fifo）

//这里好像没有做到同步，仅仅是非对称

module sum:
compare wirte_data_width with read_data_width
generate corresponding number of fifos to makeup the difference of width quantity 
e.g:
WRITE_DATA_WIDTH=2,READ_DATA_WIDTH=1
should generate 2 fifos, which (R/W)data width is READ_DATA_WIDTH, 2*READ_DATA_WIDTH will make a batch to read

WRITE_DATA_WIDTH=1,READ_DATA_WIDTH=2
should generate 2 fifos, which (R/W)data width is WRITE_DATA_WIDTH 

extra:
fifo_count seems to be useless
*/
module fifo_asymmetric
#(  // Parameters
    parameter integer  WR_DATA_WIDTH                = 64,
    parameter integer  RD_DATA_WIDTH                = 64,
    parameter integer  WR_ADDR_WIDTH                = 4,//makes 2^4 data space
    parameter integer  RD_ADDR_WIDTH                = 4
)(  // Ports
    input  wire                                         clk,
    input  wire                                         reset,
    input  wire                                         s_write_req,
    input  wire                                         s_read_req,
    input  wire  [ WR_DATA_WIDTH        -1 : 0 ]        s_write_data,
    output wire  [ RD_DATA_WIDTH        -1 : 0 ]        s_read_data,
    output wire                                         s_read_ready,
    output wire                                         s_write_ready,
    output wire                                         almost_full,
    output wire                                         almost_empty
);

    localparam          NUM_FIFO                     = RD_DATA_WIDTH < WR_DATA_WIDTH ? WR_DATA_WIDTH / RD_DATA_WIDTH : RD_DATA_WIDTH / WR_DATA_WIDTH;//ratio
    localparam          FIFO_ID_W                    = $clog2(NUM_FIFO);//FIFO_ID_WIDTH
    localparam          ADDR_WIDTH                   = RD_DATA_WIDTH < WR_DATA_WIDTH ? WR_ADDR_WIDTH : RD_ADDR_WIDTH;//bigger width

    //arrays to connect fifo(s)
    wire [ NUM_FIFO             -1 : 0 ]        local_s_write_ready;
    wire [ NUM_FIFO             -1 : 0 ]        local_almost_full;
    wire [ NUM_FIFO             -1 : 0 ]        local_s_read_ready;
    wire [ NUM_FIFO             -1 : 0 ]        local_almost_empty;

    wire [ ADDR_WIDTH              : 0 ]        fifo_count;//one fifo counter

genvar i;

generate
if (WR_DATA_WIDTH > RD_DATA_WIDTH)
begin: WR_GT_RD//WRITE > READ (WIDTH)


    reg  [ FIFO_ID_W            -1 : 0 ]        rd_ptr;
    reg  [ FIFO_ID_W            -1 : 0 ]        rd_ptr_dly;

    assign fifo_count = FIFO_INST[NUM_FIFO-1].u_fifo.fifo_count;//TODO: meaning?
    assign s_read_ready = local_s_read_ready[rd_ptr];//READ WIDTH is less, so unit is one
    assign s_write_ready = &local_s_write_ready;//Every fifo is write-ready, assign output ready
    assign almost_empty = local_almost_empty[rd_ptr];//set almost_empty if now is almost_empty
    assign almost_full = |local_almost_full;//single almost full will set output almost full 1

  always @(posedge clk)
  begin
    if (reset)
      rd_ptr <= 0;
    else if (s_read_req && s_read_ready)
    begin
      if (rd_ptr == NUM_FIFO-1)//end of range, ptr start over
        rd_ptr <= 0;
      else
        rd_ptr <= rd_ptr + 1'b1;//ok to read
    end
  end

  always @(posedge clk)
  begin
    if (s_read_req && s_read_ready)
      rd_ptr_dly <= rd_ptr;//rd_ptr_dly = old rd_ptr?
  end

for (i=0; i<NUM_FIFO; i=i+1)
begin: FIFO_INST
    wire [ RD_DATA_WIDTH        -1 : 0 ]        _s_write_data;
    wire                                        _s_write_req;
    wire                                        _s_write_ready;//output
    wire                                        _almost_full;//output

    wire [ RD_DATA_WIDTH        -1 : 0 ]        _s_read_data;//output
    wire                                        _s_read_req;
    wire                                        _s_read_ready;//output
    wire                                        _almost_empty;//output

    //fifo write part
    assign _s_write_req = s_write_req;//send input write req to fifo_inst
    assign _s_write_data = s_write_data[i*RD_DATA_WIDTH+:RD_DATA_WIDTH];//send input write data(splited) to fifo_inst
    assign local_s_write_ready[i] = _s_write_ready;//set ready if fifo ouput ready;
    assign local_almost_full[i] = _almost_full;//set almost full if fifo ouput almost full;
    //fifo read part
    assign _s_read_req = s_read_req && (rd_ptr == i);//send read req to fifo inst
    assign s_read_data = rd_ptr_dly == i ? _s_read_data : 'bz;//TODO: ? what time
    assign local_s_read_ready[i] = _s_read_ready;//send back inst status to array
    assign local_almost_empty[i] = _almost_empty;//send back inst status to array

    fifo #(
    .DATA_WIDTH                     ( RD_DATA_WIDTH                  ),
    .ADDR_WIDTH                     ( ADDR_WIDTH                     )
    ) u_fifo (
    .clk                            ( clk                            ), //input
    .reset                          ( reset                          ), //input
    .s_write_req                    ( _s_write_req                   ), //input
    .s_write_data                   ( _s_write_data                  ), //input
    .s_write_ready                  ( _s_write_ready                 ), //output
    .s_read_req                     ( _s_read_req                    ), //input
    .s_read_ready                   ( _s_read_ready                  ), //output
    .s_read_data                    ( _s_read_data                   ), //output
    .almost_full                    ( _almost_full                   ), //output
    .almost_empty                   ( _almost_empty                  )  //output
    );
end
end
else//if (WR_DATA_WIDTH > RD_DATA_WIDTH)
begin: RD_GT_WR//READ > WRITE (WIDTH)

    reg  [ FIFO_ID_W            -1 : 0 ]        wr_ptr;//digital range fifo_0 -> fifo_last
    assign fifo_count = FIFO_INST[0].u_fifo.fifo_count;//TODO: ? meaning?

  always @(posedge clk)//every clock will make a wr_ptr
  begin
    if (reset)
      wr_ptr <= 0;//return to fifo_0
    else if (s_write_req && s_write_ready)
    begin
      if (wr_ptr == NUM_FIFO-1)//end of fifo range, assign 0 to start again
        wr_ptr <= 0;
      else
        wr_ptr <= wr_ptr + 1'b1;//ptr select next fifo
    end
  end//always

    assign s_read_ready = &local_s_read_ready;//assign 1 if every fifo s_read is ready(because once read need every fifo ready?)
    assign s_write_ready = local_s_write_ready[wr_ptr];//write width is less, only need one ready?
    assign almost_empty = |local_almost_empty;//if any single fifo is almost empty, assign 1
    assign almost_full = local_almost_full[wr_ptr];//only assign now wr_ptr fifo is almost full

for (i=0; i<NUM_FIFO; i=i+1)//make NUM_FIFO fifos to catch up the diff
begin: FIFO_INST
    wire [ WR_DATA_WIDTH        -1 : 0 ]        _s_write_data;//WRITE width is smaller, so here is WR_DATA_WIDTH
    wire                                        _s_write_req;
    wire                                        _s_write_ready;//fifo output
    wire                                        _almost_full;//fifo output

    wire [ WR_DATA_WIDTH        -1 : 0 ]        _s_read_data;//WRITE width is smaller, so here is WR_DATA_WIDTH,fifo output
    wire                                        _s_read_req;
    wire                                        _s_read_ready;//fifo output
    wire                                        _almost_empty;//fifo output

    //connect fifo write
    assign _s_write_req = s_write_req && (wr_ptr == i);//send input write_req to fifo
    assign _s_write_data = s_write_data;//send input write_data to fifo
    assign local_s_write_ready[i] = _s_write_ready;//trans write ready from fifo
    assign local_almost_full[i] = _almost_full;//trans almost_full from fifo

    //connect fifo read
    assign _s_read_req = s_read_req;//send input read_req to fifo
    assign s_read_data[i*WR_DATA_WIDTH+:WR_DATA_WIDTH] = _s_read_data;//collect every fifo read_data
    assign local_s_read_ready[i] = _s_read_ready;//trans fifo's read_ready out to arrays
    assign local_almost_empty[i] = _almost_empty;//trans fifo's almost_empty out to arrays

    fifo #(
    .DATA_WIDTH                     ( WR_DATA_WIDTH                  ),
    .ADDR_WIDTH                     ( ADDR_WIDTH                     )
    ) u_fifo (
    .clk                            ( clk                            ), //input
    .reset                          ( reset                          ), //input
    .s_write_req                    ( _s_write_req                   ), //input
    .s_write_data                   ( _s_write_data                  ), //input
    .s_write_ready                  ( _s_write_ready                 ), //output
    .s_read_req                     ( _s_read_req                    ), //input
    .s_read_ready                   ( _s_read_ready                  ), //output
    .s_read_data                    ( _s_read_data                   ), //output
    .almost_full                    ( _almost_full                   ), //output
    .almost_empty                   ( _almost_empty                  )  //output
    );
end//begin:FIFO_INST



end
endgenerate

endmodule
