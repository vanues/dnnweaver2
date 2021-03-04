//
// Banked RAM
//  Allows simultaneous accesses for LD/ST and RD/WR instructions
// 允许同时LOAD/STORE 和 READ/WRITE 指令
//
// Hardik Sharma
// (hsharma@gatech.edu)

/*
module sum: see mux part:line 183
*/
`timescale 1ns/1ps
module banked_ram
#(
    parameter integer  TAG_W                        = 2,//TAG 用来选择bank inst
    parameter integer  NUM_TAGS                     = (1<<TAG_W), //banked mem num is 2^TAG_W
    parameter integer  DATA_WIDTH                   = 16,
    parameter integer  ADDR_WIDTH                   = 13,//space for 2^13 data, which is DATA_WIDTH bits
    parameter integer  LOCAL_ADDR_W                 = ADDR_WIDTH - TAG_W//cache? 13-2=11[0-10]
)
(
    input  wire                                         clk,
    input  wire                                         reset,

  // LD/ST --Load / Store
    input  wire                                         s_read_req_a,
    input  wire  [ ADDR_WIDTH           -1 : 0 ]        s_read_addr_a,
    output wire  [ DATA_WIDTH           -1 : 0 ]        s_read_data_a,//read result

    input  wire                                         s_write_req_a,
    input  wire  [ ADDR_WIDTH           -1 : 0 ]        s_write_addr_a,
    input  wire  [ DATA_WIDTH           -1 : 0 ]        s_write_data_a,

  // RD/WR 
    input  wire                                         s_read_req_b,
    input  wire  [ ADDR_WIDTH           -1 : 0 ]        s_read_addr_b,
    output wire  [ DATA_WIDTH           -1 : 0 ]        s_read_data_b,//read result

    input  wire                                         s_write_req_b,
    input  wire  [ ADDR_WIDTH           -1 : 0 ]        s_write_addr_b,
    input  wire  [ DATA_WIDTH           -1 : 0 ]        s_write_data_b
);

//=============================================================
// Localparams
//=============================================================
    //every tag for a banked mem
    //every banked mem has DATA_WIDTH wide output, so sum output is DATA_WIDTH*NUM
    localparam          LOCAL_READ_WIDTH             = DATA_WIDTH * NUM_TAGS;
//=============================================================


//=============================================================
// Wires/Regs
//=============================================================
  genvar i;
    wire [ TAG_W                -1 : 0 ]        wr_tag_a;//for choosing which banked mem
    wire [ LOCAL_ADDR_W         -1 : 0 ]        wr_addr_a;//ADDR_WIDTH - TAG_W 
    wire [ TAG_W                -1 : 0 ]        wr_tag_b;//for choosing which bank
    wire [ LOCAL_ADDR_W         -1 : 0 ]        wr_addr_b;//ADDR_WIDTH - TAG_W

    wire [ TAG_W                -1 : 0 ]        rd_tag_a;//for choosing which bank
    wire [ TAG_W                -1 : 0 ]        rd_tag_b;//for choosing which bank
    reg  [ TAG_W                -1 : 0 ]        rd_tag_a_dly;//delay,rd_tag_a似乎不会改变，delay有意义吗
    reg  [ TAG_W                -1 : 0 ]        rd_tag_b_dly;//delay
    wire [ LOCAL_ADDR_W         -1 : 0 ]        rd_addr_a;//ADDR_WIDTH - TAG_W
    wire [ LOCAL_ADDR_W         -1 : 0 ]        rd_addr_b;//ADDR_WIDTH - TAG_W

    wire [ LOCAL_READ_WIDTH     -1 : 0 ]        local_read_data_a;
    wire [ LOCAL_READ_WIDTH     -1 : 0 ]        local_read_data_b;

//=============================================================

//=============================================================
// Assigns
//=============================================================
    assign {wr_tag_a, wr_addr_a} = s_write_addr_a;// [TAG|LOCAL_ADDR_W] = [INPUT_ADDR]
    assign {wr_tag_b, wr_addr_b} = s_write_addr_b;// 3+13(2+11)(useful bits,2 for select bank)

    assign {rd_tag_a, rd_addr_a} = s_read_addr_a;
    assign {rd_tag_b, rd_addr_b} = s_read_addr_b;

    always @(posedge clk)
    begin
      if (reset)
        rd_tag_a_dly <= 0;
      else if (s_read_req_a)
        rd_tag_a_dly <= rd_tag_a;//delay read tag = old read tag;
    end

    always @(posedge clk)
    begin
      if (reset)
        rd_tag_b_dly <= 0;
      else if (s_read_req_b)
        rd_tag_b_dly <= rd_tag_b;//delay read tag = old read tag;
    end
//=============================================================


//=============================================================
// RAM logic
//=============================================================
generate
  for (i=0; i<NUM_TAGS; i=i+1)
  begin: BANK_INST

    (* ram_style = "block" *)
    reg  [ DATA_WIDTH -1 : 0 ] bank_mem [ 0 : 1<<(LOCAL_ADDR_W) - 1 ];//space for 2^local_addr_w,which is data_width bits

    wire [ DATA_WIDTH           -1 : 0 ]        wdata;
    reg  [ DATA_WIDTH           -1 : 0 ]        rdata;

    wire [ LOCAL_ADDR_W         -1 : 0 ]        waddr;
    wire [ LOCAL_ADDR_W         -1 : 0 ]        raddr;

    //write req
    wire                                        local_wr_req_a;//local means for every banked inst
    wire                                        local_wr_req_b;
    //read req
    wire                                        local_rd_req_a;
    wire                                        local_rd_req_b;
    //read delay
    wire                                        local_rd_req_a_dly;
    wire                                        local_rd_req_b_dly;

    // Write port, only one write req is available?
    assign local_wr_req_a = (wr_tag_a == i) && s_write_req_a;//tag_a choose BANK_INST[i] and has a write req;
    assign local_wr_req_b = (wr_tag_b == i) && s_write_req_b;//~~

    assign wdata = local_wr_req_a ? s_write_data_a : s_write_data_b;//write 只能选一个req?
    assign waddr = local_wr_req_a ? wr_addr_a : wr_addr_b;//~~

    always @(posedge clk)
    begin: RAM_WRITE
      if (local_wr_req_a || local_wr_req_b)begin//只要不是两个req为0，就可以写入wdata到mem addr
        bank_mem[waddr] <= wdata;
      end
    end


    // Read port, 每次最多只有一个req可用？
    assign local_rd_req_a = (rd_tag_a == i) && s_read_req_a;//has rd_req and tag is now banked mem
    assign local_rd_req_b = (rd_tag_b == i) && s_read_req_b;//has rd_req and tag is now banked mem

    assign raddr = local_rd_req_a ? rd_addr_a  : rd_addr_b;//get addr from addr_a or addr_b;

    //以下两句因为后两行local_rd_req_a_dly被注释，并没有任何作用
    //是因为local_rd_req_a(_dly) 和输入的rd_tag_a_dly一样吗
    register_sync #(1) reg_local_rd_req_a (clk, reset, local_rd_req_a, local_rd_req_a_dly);//通过寄存器把req_a给req_a_delay
    register_sync #(1) reg_local_rd_req_b (clk, reset, local_rd_req_b, local_rd_req_b_dly);
    // assign s_read_data_a = local_rd_req_a_dly ? rdata : {DATA_WIDTH{1'bz}};
    // assign s_read_data_b = local_rd_req_b_dly ? rdata : {DATA_WIDTH{1'bz}};

    //local_read_data_a and ~_b 's content are the same;
    assign local_read_data_a[i*DATA_WIDTH+:DATA_WIDTH] = rdata;//collect every banked mem output data
    assign local_read_data_b[i*DATA_WIDTH+:DATA_WIDTH] = rdata;//collect every banked mem output data

    always @(posedge clk)
    begin: RAM_READ
      if (local_rd_req_a || local_rd_req_b)begin//read this inst mem data
        rdata <= bank_mem[raddr];
      end
    end

    //assign rdata = bank_mem[raddr];


`ifdef simulation
    integer idx;
    initial begin
      for (idx=0; idx< (1<<LOCAL_ADDR_W); idx=idx+1)
      begin
        bank_mem[idx] = 32'hDEADBEEF;
      end
    end
`endif //simulation

  end//for
endgenerate
//=============================================================
//=============================================================
// Mux
//Every banked mem inst will connect to 2 mux inst below
//difference is [sel] input;
//banked mem[0]--------|
//banked mem[1]--------|     --- read_a_mux
//                      -----|
//banked mem[2]--------|     --- read_b_mux
//banked mem[3]--------|
//最后在4个data中读出其中2个data

//运行过程中，同一个clock最多
//testbench: 生成4个bank，对bank0和1同时写，同时读bank0，状态正常，这个相当于可以同时做4次（2写2读？）
//=============================================================
  mux_n_1 #(
    .WIDTH                          ( DATA_WIDTH                     ),
    .LOG2_N                         ( TAG_W                          )
  ) read_a_mux (
    .sel                            ( rd_tag_a_dly                   ),
    .data_in                        ( local_read_data_a              ),
    .data_out                       ( s_read_data_a                  )
  );

  mux_n_1 #(
    .WIDTH                          ( DATA_WIDTH                     ),
    .LOG2_N                         ( TAG_W                          )
  ) read_b_mux (
    .sel                            ( rd_tag_b_dly                   ),
    .data_in                        ( local_read_data_b              ),
    .data_out                       ( s_read_data_b                  )
  );
//=============================================================

endmodule
