//
// WBUF
//
// Hardik Sharma
// (hsharma@gatech.edu)

/*
module sum:
读:
  当GROUP_SIZE==0 时,会生成[ARRAY_N]个RAM,每个RAM读出的数据位宽为MEM_DATA_WIDTH,整合起来一共有BUF_DATA_WIDTH位读出数据
  当GROUP_SIZE> 0 时,会生成[GROUP_SIZE * ARRAY_N]个RAM,读取的时候,RAM_M[0-n-1]N[0]作为一个整体一起读

写:
  ID会首先区分M[i],再区分当前M[i]里的ARRAY_N个RAM,最后选定一个RAM进行写数据操作


EXTRA:
  N每多1,CLK指令就越晚来一个周期,会不会拖慢速度
*/
`timescale 1ns/1ps
module wbuf #(
    parameter integer  TAG_W                        = 2,  // Log number of banks
    parameter integer  MEM_DATA_WIDTH               = 64,
    parameter integer  ARRAY_N                      = 4,//d:64
    parameter integer  ARRAY_M                      = 4,//d:64 //TODO: 8
    parameter integer  DATA_WIDTH                   = 16,
    parameter integer  BUF_ADDR_WIDTH               = 9,

    parameter integer  GROUP_SIZE                   = (DATA_WIDTH * ARRAY_M) / MEM_DATA_WIDTH,
    parameter integer  NUM_GROUPS                   = MEM_DATA_WIDTH / DATA_WIDTH,
    parameter integer  GROUP_ID_W                   = GROUP_SIZE == 1 ? 0 : $clog2(GROUP_SIZE),
    parameter integer  BUF_ID_N_W                   = $clog2(ARRAY_N),//单独看列N数量生成的id位宽
    parameter integer  BUF_ID_W                     = BUF_ID_N_W + GROUP_ID_W,//行和列同时的Id位宽

    parameter integer  MEM_ADDR_WIDTH               = BUF_ADDR_WIDTH + BUF_ID_W,
    parameter integer  BUF_DATA_WIDTH               = ARRAY_N * ARRAY_M * DATA_WIDTH//每一个PE都要有Weight
)
(
    input  wire                                         clk,
    input  wire                                         reset,

    input  wire                                         mem_write_req,
    input  wire  [ MEM_ADDR_WIDTH       -1 : 0 ]        mem_write_addr,
    input  wire  [ MEM_DATA_WIDTH       -1 : 0 ]        mem_write_data,

    input  wire                                         buf_read_req,
    input  wire  [ BUF_ADDR_WIDTH       -1 : 0 ]        buf_read_addr,
    output wire  [ BUF_DATA_WIDTH       -1 : 0 ]        buf_read_data
  );

genvar n, m;
generate
for (m=0; m<GROUP_SIZE; m=m+1)
begin: LOOP_M
for (n=0; n<ARRAY_N; n=n+1)
begin: LOOP_N

    localparam integer  LOCAL_ADDR_W                 = BUF_ADDR_WIDTH;
    localparam integer  LOCAL_BUF_ID                 = m + n*GROUP_SIZE;//自有固定buf id
//READ
    wire                                        local_buf_read_req;
    wire [ LOCAL_ADDR_W         -1 : 0 ]        local_buf_read_addr;
    wire [ MEM_DATA_WIDTH       -1 : 0 ]        local_buf_read_data;

    assign buf_read_data[(m+n*GROUP_SIZE)*MEM_DATA_WIDTH+:MEM_DATA_WIDTH] = local_buf_read_data;//矩阵竖向收集data

    wire                                        buf_read_req_fwd;//用来传递当前req和下一个buf的req
    wire [ LOCAL_ADDR_W         -1 : 0 ]        buf_read_addr_fwd;//用来传递当前req和下一个buf的req

  if (m == 0) begin//向后传递signal (dly)
      register_sync #(1) read_req_fwd (clk, reset, local_buf_read_req, buf_read_req_fwd);
      register_sync #(LOCAL_ADDR_W) read_addr_fwd (clk, reset, local_buf_read_addr, buf_read_addr_fwd);
  end else begin//获取前向的signal (无dly)
      assign buf_read_req_fwd = local_buf_read_req;
      assign buf_read_addr_fwd = local_buf_read_addr;
  end

  if (n == 0) begin//当前行第一个buf,从输入获取req
    assign local_buf_read_req = buf_read_req;//从这里开始,input传递read req,从LOOP_M[0]N[0] -> LOOP_M[n-1]N[n-1];
    assign local_buf_read_addr = buf_read_addr;//~~~
  end
  else begin//剩余行buf,从之前行获取req
    assign local_buf_read_req = LOOP_M[0].LOOP_N[n-1].buf_read_req_fwd;//来自上一个buf的req fwd
    assign local_buf_read_addr = LOOP_M[0].LOOP_N[n-1].buf_read_addr_fwd;//来自上一个buf的req fwd
  end
//WRITE
    wire [ BUF_ID_W             -1 : 0 ]        local_mem_write_buf_id;
    wire                                        local_mem_write_req;
    wire [ LOCAL_ADDR_W         -1 : 0 ]        local_mem_write_addr;
    wire [ MEM_DATA_WIDTH       -1 : 0 ]        local_mem_write_data;

    wire [ BUF_ID_W             -1 : 0 ]        buf_id;
    assign buf_id = LOCAL_BUF_ID;

  if (BUF_ID_W == 0) begin//只有一个,不需要id进行select
    assign local_mem_write_addr = mem_write_addr;
    assign local_mem_write_req = mem_write_req;
    assign local_mem_write_data = mem_write_data;
  end
  else begin
    assign {local_mem_write_addr, local_mem_write_buf_id} = mem_write_addr;//分配local addr和id
    assign local_mem_write_req = mem_write_req && local_mem_write_buf_id == buf_id;//id一致激活req
    assign local_mem_write_data = mem_write_data;
  end

  ram #(
    .ADDR_WIDTH                     ( LOCAL_ADDR_W                   ),
    .DATA_WIDTH                     ( MEM_DATA_WIDTH                 ),
    .OUTPUT_REG                     ( 1                              )
  ) u_ram (
    .clk                            ( clk                            ),
    .reset                          ( reset                          ),
    .s_write_addr                   ( local_mem_write_addr           ),
    .s_write_req                    ( local_mem_write_req            ),
    .s_write_data                   ( local_mem_write_data           ),
    .s_read_addr                    ( local_buf_read_addr            ),
    .s_read_req                     ( local_buf_read_req             ),
    .s_read_data                    ( local_buf_read_data            )
    );

end
end
endgenerate

//=============================================================
// VCD
//=============================================================
  `ifdef COCOTB_TOPLEVEL_buffer
  initial begin
    $dumpfile("buffer.vcd");
    $dumpvars(0, buffer);
  end
  `endif
//=============================================================
endmodule
