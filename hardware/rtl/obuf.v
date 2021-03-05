//
// OBUF - Output Buffer
//
// Hardik Sharma
// (hsharma@gatech.edu)

/*
module sum:
产生ARRAY_M个banked_ram模块，每个模块里有2^TAG_W个banked_mem
- 当BUF_ID_W==0 时，mem和buf的读和写似乎都同时作用于2个banked_ram（相当于克隆一个ram出来），读和写的结果都一样。
- 当BUF_ID_W!=0 时，TODO:

根据banked_ram设计，mem_read/write_req优先级是高于buf_~_req的
*/
`timescale 1ns/1ps
module obuf #(
  parameter integer  TAG_W                        = 2,  // Log number of banks
  parameter integer  MEM_DATA_WIDTH               = 64,
  parameter integer  ARRAY_M                      = 2,//有ARRAY_M个banked_ram模块
  parameter integer  DATA_WIDTH                   = 32,
  parameter integer  BUF_ADDR_WIDTH               = 10,

  parameter integer  GROUP_SIZE                   = MEM_DATA_WIDTH / DATA_WIDTH,
  parameter integer  GROUP_ID_W                   = GROUP_SIZE == 1 ? 0 : $clog2(GROUP_SIZE),
  parameter integer  BUF_ID_W                     = $clog2(ARRAY_M) - GROUP_ID_W,//0

  parameter integer  MEM_ADDR_WIDTH               = BUF_ADDR_WIDTH + BUF_ID_W,//10 
  parameter integer  BUF_DATA_WIDTH               = ARRAY_M * DATA_WIDTH
)
(
  input  wire                                         clk,
  input  wire                                         reset,

  input  wire                                         mem_read_req,
  input  wire  [ MEM_ADDR_WIDTH       -1 : 0 ]        mem_read_addr,
  output wire  [ MEM_DATA_WIDTH       -1 : 0 ]        mem_read_data,

  input  wire                                         mem_write_req,
  input  wire  [ MEM_ADDR_WIDTH       -1 : 0 ]        mem_write_addr,
  input  wire  [ MEM_DATA_WIDTH       -1 : 0 ]        mem_write_data,

  input  wire                                         buf_read_req,
  input  wire  [ BUF_ADDR_WIDTH       -1 : 0 ]        buf_read_addr,
  output wire  [ BUF_DATA_WIDTH       -1 : 0 ]        buf_read_data,

  input  wire                                         buf_write_req,
  input  wire  [ BUF_ADDR_WIDTH       -1 : 0 ]        buf_write_addr,
  input  wire  [ BUF_DATA_WIDTH       -1 : 0 ]        buf_write_data
  );

  genvar m;
  generate//生成ARRAY_M个module实例, 地址默认均为10位，数据32位（
    for (m=0; m<ARRAY_M; m=m+1)
    begin: LOOP_M

      localparam integer  LOCAL_ADDR_W                 = BUF_ADDR_WIDTH;//default:10
      localparam integer  LOCAL_BUF_ID                 = m/GROUP_SIZE;
      //buf part
      wire                                        local_buf_write_req;
      wire [ LOCAL_ADDR_W         -1 : 0 ]        local_buf_write_addr;
      wire [ DATA_WIDTH           -1 : 0 ]        local_buf_write_data;

      wire                                        local_buf_read_req;
      wire [ LOCAL_ADDR_W         -1 : 0 ]        local_buf_read_addr;
      wire [ DATA_WIDTH           -1 : 0 ]        local_buf_read_data;

      assign local_buf_write_data = buf_write_data[(m)*DATA_WIDTH+:DATA_WIDTH];//截取部分对应data到自己module里
      assign buf_read_data[(m)*DATA_WIDTH+:DATA_WIDTH] = local_buf_read_data;//传出从本module读取的data

      assign local_buf_read_req = buf_read_req;//传入read req 
      assign local_buf_write_req = buf_write_req;//传入write req
      assign local_buf_write_addr = buf_write_addr;//传入buf write addr
      assign local_buf_read_addr = buf_read_addr;//传入buf read addr
      //mem part, same interface with buf part
      wire [ BUF_ID_W             -1 : 0 ]        local_mem_write_buf_id;

      wire                                        local_mem_write_req;
      wire [ LOCAL_ADDR_W         -1 : 0 ]        local_mem_write_addr;
      wire [ DATA_WIDTH           -1 : 0 ]        local_mem_write_data;

      wire                                        local_mem_read_req;
      wire [ LOCAL_ADDR_W         -1 : 0 ]        local_mem_read_addr;
      wire [ DATA_WIDTH           -1 : 0 ]        local_mem_read_data;

      wire [ BUF_ID_W             -1 : 0 ]        buf_id;
      assign buf_id = LOCAL_BUF_ID;

      if (BUF_ID_W == 0) begin//only one 
        assign local_mem_write_addr = mem_write_addr;
        assign local_mem_write_req = mem_write_req;
        assign local_mem_write_data = mem_write_data[(m%GROUP_SIZE)*DATA_WIDTH+:DATA_WIDTH];

        assign local_mem_read_addr = mem_read_addr;
        assign local_mem_read_req = mem_read_req;
        assign mem_read_data[(m%GROUP_SIZE)*DATA_WIDTH+:DATA_WIDTH] = local_mem_read_data;
      end
      else begin
        wire [ BUF_ID_W             -1 : 0 ]        local_mem_read_buf_id;
        reg  [ BUF_ID_W             -1 : 0 ]        local_mem_read_buf_id_dly;

        assign {local_mem_write_addr, local_mem_write_buf_id} = mem_write_addr;
        assign local_mem_write_req = mem_write_req && local_mem_write_buf_id == buf_id;
        assign local_mem_write_data = mem_write_data[(m%GROUP_SIZE)*DATA_WIDTH+:DATA_WIDTH];

        assign {local_mem_read_addr, local_mem_read_buf_id} = mem_read_addr;
        assign local_mem_read_req = mem_read_req && local_mem_read_buf_id == buf_id;
        assign mem_read_data[(m%GROUP_SIZE)*DATA_WIDTH+:DATA_WIDTH] = local_mem_read_buf_id_dly == buf_id ? local_mem_read_data : 'bz;

        // register_sync#(BUF_ID_W) id_dly (clk, reset, local_mem_read_buf_id, local_mem_read_buf_id_dly);

        always @(posedge clk)
        begin
          if (reset)
            local_mem_read_buf_id_dly <= 0;
          else if (mem_read_req)
            local_mem_read_buf_id_dly <= local_mem_read_buf_id;
        end

      end
      //每个banked_ram里有2^TAG_W 个banked_mem
      banked_ram #(
        .TAG_W                          ( TAG_W                          ),
        .ADDR_WIDTH                     ( LOCAL_ADDR_W                   ),
        .DATA_WIDTH                     ( DATA_WIDTH                     )
      ) buf_ram (
        .clk                            ( clk                            ),
        .reset                          ( reset                          ),
        .s_write_addr_a                 ( local_mem_write_addr           ),
        .s_write_req_a                  ( local_mem_write_req            ),
        .s_write_data_a                 ( local_mem_write_data           ),
        .s_read_addr_a                  ( local_mem_read_addr            ),
        .s_read_req_a                   ( local_mem_read_req             ),
        .s_read_data_a                  ( local_mem_read_data            ),
        .s_write_addr_b                 ( local_buf_write_addr           ),
        .s_write_req_b                  ( local_buf_write_req            ),
        .s_write_data_b                 ( local_buf_write_data           ),
        .s_read_addr_b                  ( local_buf_read_addr            ),
        .s_read_req_b                   ( local_buf_read_req             ),
        .s_read_data_b                  ( local_buf_read_data            )
        );

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
