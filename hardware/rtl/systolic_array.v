//
// 2-D systolic array
//
// Hardik Sharma
// (hsharma@gatech.edu)

/*
module sum:
先Systolic Array - Begin做a*b，最后在accumulator处统一做+c
*/
`timescale 1ns/1ps
module systolic_array #(
    parameter integer  ARRAY_N                      = 4,//MxN PEs
    parameter integer  ARRAY_M                      = 4,
    parameter          DTYPE                        = "FXP", // FXP for Fixed-point, FP32 for single precision, FP16 for half-precision

    parameter integer  ACT_WIDTH                    = 16,
    parameter integer  WGT_WIDTH                    = 16,
    parameter integer  BIAS_WIDTH                   = 32,
    parameter integer  ACC_WIDTH                    = 48,//累加位宽，why 48（因为buf width是48吗）

    // General
    parameter integer  MULT_OUT_WIDTH               = ACT_WIDTH + WGT_WIDTH,//d:32
    parameter integer  PE_OUT_WIDTH                 = MULT_OUT_WIDTH + $clog2(ARRAY_N),//32+16=48,TODO:为什么还要加一个clog
    
    parameter integer  SYSTOLIC_OUT_WIDTH           = ARRAY_M * ACC_WIDTH,//用来存储每行最后一个PE的计算结果（宽ACC_WIDTH)，一共ARRAY_M行
    parameter integer  IBUF_DATA_WIDTH              = ARRAY_N * ACT_WIDTH,
    parameter integer  WBUF_DATA_WIDTH              = ARRAY_N * ARRAY_M * WGT_WIDTH,
    parameter integer  OUT_WIDTH                    = ARRAY_M * ACC_WIDTH,
    parameter integer  BBUF_DATA_WIDTH              = ARRAY_M * BIAS_WIDTH,//4*32

    // Address for buffers
    parameter integer  OBUF_ADDR_WIDTH              = 16,
    parameter integer  BBUF_ADDR_WIDTH              = 16
        ) (
    input  wire                                         clk,
    input  wire                                         reset,

    input  wire                                         acc_clear,

    input  wire  [ IBUF_DATA_WIDTH      -1 : 0 ]        ibuf_read_data,//input act buffer data

    output wire                                         sys_bias_read_req,
    output wire  [ BBUF_ADDR_WIDTH      -1 : 0 ]        sys_bias_read_addr,
    input  wire                                         bias_read_req,
    input  wire  [ BBUF_ADDR_WIDTH      -1 : 0 ]        bias_read_addr,
    input  wire  [ BBUF_DATA_WIDTH      -1 : 0 ]        bbuf_read_data,//bias data
    input  wire                                         bias_prev_sw,

    input  wire  [ WBUF_DATA_WIDTH      -1 : 0 ]        wbuf_read_data,//weight buffer data
    input  wire  [ OUT_WIDTH            -1 : 0 ]        obuf_read_data,
    input  wire  [ OBUF_ADDR_WIDTH      -1 : 0 ]        obuf_read_addr,
    output wire                                         sys_obuf_read_req,
    output wire  [ OBUF_ADDR_WIDTH      -1 : 0 ]        sys_obuf_read_addr,
    input  wire                                         obuf_write_req,
    output wire  [ OUT_WIDTH            -1 : 0 ]        obuf_write_data,//总计算结果
    input  wire  [ OBUF_ADDR_WIDTH      -1 : 0 ]        obuf_write_addr,
    output wire                                         sys_obuf_write_req,
    output wire  [ OBUF_ADDR_WIDTH      -1 : 0 ]        sys_obuf_write_addr
);

//=========================================
// Localparams
//=========================================
//=========================================
// Wires and Regs
//=========================================

  //FSM to see if we can accumulate or not
    reg  [ 2                    -1 : 0 ]        acc_state_d;//4 states, only 2 used: ACC_INVALID=0,ACC_VALID=1
    reg  [ 2                    -1 : 0 ]        acc_state_q;//4 states


    wire [ OUT_WIDTH            -1 : 0 ]        accumulator_out;//累加结果
    wire                                        acc_out_valid;
    wire [ ARRAY_M              -1 : 0 ]        acc_out_valid_;
    wire                                        acc_out_valid_all;
    wire [ SYSTOLIC_OUT_WIDTH   -1 : 0 ]        systolic_out;

    wire [ ARRAY_M              -1 : 0 ]        systolic_out_valid;
    wire [ ARRAY_N              -1 : 0 ]        _systolic_out_valid;

    wire [ OBUF_ADDR_WIDTH      -1 : 0 ]        systolic_out_addr;
    wire [ OBUF_ADDR_WIDTH      -1 : 0 ]        _systolic_out_addr;

    wire                                        _addr_eq;//前后两次地址相等
    reg                                         addr_eq;
    wire [ ARRAY_N              -1 : 0 ]        _acc;
    wire [ ARRAY_M              -1 : 0 ]        acc;//累加器使能
    wire [ OBUF_ADDR_WIDTH      -1 : 0 ]        _systolic_in_addr;

    wire [ BBUF_ADDR_WIDTH      -1 : 0 ]        _bias_read_addr;
    wire                                        _bias_read_req;

    wire [ ARRAY_M              -1 : 0 ]        systolic_acc_clear;
    wire [ ARRAY_M              -1 : 0 ]        _systolic_acc_clear;
//=========================================
// Systolic Array - Begin
//=========================================
// TODO: Add groups
genvar n, m;
generate
for (m=0; m<ARRAY_M; m=m+1)
begin: LOOP_INPUT_FORWARD
for (n=0; n<ARRAY_N; n=n+1)
begin: LOOP_OUTPUT_FORWARD

    wire [ ACT_WIDTH            -1 : 0 ]        a;       // Input Operand a
    wire [ WGT_WIDTH            -1 : 0 ]        b;       // Input Operand b
    wire [ PE_OUT_WIDTH         -1 : 0 ]        pe_out;  // Output of signed spatial multiplier
    wire [ PE_OUT_WIDTH         -1 : 0 ]        c;       // Output  of mac

  //==============================================================
  // Operands for the parametric PE
  // Operands are delayed by a cycle when forwarding
  if (m == 0)
  begin
    assign a = ibuf_read_data[n*ACT_WIDTH+:ACT_WIDTH];//截取从n*ACT_WIDTH开始，长ACT_WIDTH的比特
  end
  else//m!=0
  begin
    wire [ ACT_WIDTH            -1 : 0 ]        fwd_a;
    assign fwd_a = LOOP_INPUT_FORWARD[m-1].LOOP_OUTPUT_FORWARD[n].a;//对每个inst都传播a
    // register_sync #(ACT_WIDTH) fwd_a_reg (clk, reset, fwd_a, a);
    assign a = fwd_a;//当前的a等于上一轮的a
  end

    assign b = wbuf_read_data[(m+n*ARRAY_M)*WGT_WIDTH+:WGT_WIDTH];//截取从(m+n*ARRAY_M)*WGT_WIDTH开始，长WGT_WIDTH的比特
  //==============================================================

  wire [1:0] prev_level_mode = 0;

    localparam          PE_MODE                      = n == 0 ? "MULT" : "FMA";

  // output forwarding
  if (n == 0)//等于0时，PE_MODE 为MULTI，这里的C没有参与运算
    assign c = {PE_OUT_WIDTH{1'bz}};
  else//n!=0 PE_MODE == FMA (a*b+c)
    assign c = LOOP_INPUT_FORWARD[m].LOOP_OUTPUT_FORWARD[n-1].pe_out;//C是上一个PE的a*b计算结果

  pe #(
    .PE_MODE                        ( PE_MODE                        ),
    .ACT_WIDTH                      ( ACT_WIDTH                      ),
    .WGT_WIDTH                      ( WGT_WIDTH                      ),
    .PE_OUT_WIDTH                   ( PE_OUT_WIDTH                   )
  ) pe_inst (
    .clk                            ( clk                            ),  // input
    .reset                          ( reset                          ),  // input
    .a                              ( a                              ),  // input
    .b                              ( b                              ),  // input
    .c                              ( c                              ),  // input
    .out                            ( pe_out                         )   // output // pe_out = a * b + c
    );

  if (n == ARRAY_N - 1)//每行最后的PE就是结果
  begin
    assign systolic_out[m*PE_OUT_WIDTH+:PE_OUT_WIDTH] = pe_out;//存储每行的计算结果PE_OUT,4*48 - 56(Z) = 4*32
  end

end
end
endgenerate
//=========================================
// Systolic Array - End
//=========================================

  genvar i;




//=========================================
// Accumulate logic
//=========================================

    reg  [ OBUF_ADDR_WIDTH      -1 : 0 ]        prev_obuf_write_addr;

  always @(posedge clk)
  begin
    if (obuf_write_req)
      prev_obuf_write_addr <= obuf_write_addr;//赋予旧地址
  end
    //acc_status_q 状态
    localparam integer  ACC_INVALID                  = 0;
    localparam integer  ACC_VALID                    = 1;

  // If the current read address and the previous write address are the same, accumulate
    assign _addr_eq = (obuf_write_addr == prev_obuf_write_addr) && (obuf_write_req) && (acc_state_q != ACC_INVALID);//acc_state改变导致addr_eq再也回不去0，进而导致local_acc x
    wire acc_clear_dly1;
  register_sync #(1) acc_clear_dlyreg (clk, reset, acc_clear, acc_clear_dly1);
  always @(posedge clk)
  begin
    if (reset)
      addr_eq <= 1'b0;
    else
      addr_eq <= _addr_eq;
  end

  //acc_state_d trans
  always @(*)
  begin
    acc_state_d = acc_state_q;
    case (acc_state_q)
      ACC_INVALID: begin
        if (obuf_write_req)
          acc_state_d = ACC_VALID;
      end
      ACC_VALID: begin
        if (acc_clear_dly1)
          acc_state_d = ACC_INVALID;
      end
    endcase
  end

  //acc_state_q trans
  always @(posedge clk)
  begin
    if (reset)
      acc_state_q <= ACC_INVALID;
    else
      acc_state_q <= acc_state_d;
  end
//=========================================

//=========================================
// Output assignments
//=========================================

  register_sync #(1) out_valid_delay (clk, reset, obuf_write_req, _systolic_out_valid[0]);//延迟赋值
  register_sync #(OBUF_ADDR_WIDTH) out_addr_delay (clk, reset, obuf_write_addr, _systolic_out_addr);
  register_sync #(OBUF_ADDR_WIDTH) in_addr_delay (clk, reset, obuf_read_addr, _systolic_in_addr);

  register_sync #(1) out_acc_delay (clk, reset, addr_eq && _systolic_out_valid, _acc[0]);//初步使能赋值

  generate
    for (i=1; i<ARRAY_N; i=i+1)
    begin: COL_ACC
      register_sync #(1) out_valid_delay (clk, reset, _acc[i-1], _acc[i]);//有延迟的传播
    end

    for (i=1; i<ARRAY_M; i=i+1)
    begin: ROW_ACC
      // register_sync #(1) out_valid_delay (clk, reset, acc[i-1], acc[i]);
    assign acc[i] = acc[i-1];//无延迟传播
    end

  endgenerate
  //assign acc[0] = _acc[ARRAY_N-1];
  register_sync #(1) acc_delay (clk, reset, _acc[ARRAY_N-1], acc[0]);//第二步累加器使能延迟赋值


  generate
    for (i=1; i<ARRAY_N; i=i+1)
    begin: COL_VALID_OUT
      register_sync #(1) out_valid_delay (clk, reset, _systolic_out_valid[i-1], _systolic_out_valid[i]);//延迟传播
    end
    for (i=1; i<ARRAY_M; i=i+1)
    begin: ROW_VALID_OUT
      register_sync #(1) out_valid_delay (clk, reset, systolic_out_valid[i-1], systolic_out_valid[i]);
    end
  endgenerate
    assign systolic_out_valid[0] = _systolic_out_valid[ARRAY_N-1];


  generate
    for (i=0; i<ARRAY_N+2; i=i+1)
    begin: COL_ADDR_OUT
    wire [ OBUF_ADDR_WIDTH      -1 : 0 ]        prev_addr;
    wire [ OBUF_ADDR_WIDTH      -1 : 0 ]        next_addr;
      if (i==0)
    assign prev_addr = _systolic_out_addr;
      else
    assign prev_addr = COL_ADDR_OUT[i-1].next_addr;
      register_sync #(OBUF_ADDR_WIDTH) out_addr (clk, reset, prev_addr, next_addr);
    end
  endgenerate

    assign sys_obuf_write_addr = COL_ADDR_OUT[ARRAY_N+1].next_addr;


  generate
    for (i=1; i<ARRAY_N; i=i+1)
    begin: COL_ADDR_IN
    wire [ OBUF_ADDR_WIDTH      -1 : 0 ]        prev_addr;
    wire [ OBUF_ADDR_WIDTH      -1 : 0 ]        next_addr;
      if (i==1)
    assign prev_addr = _systolic_in_addr;
      else
    assign prev_addr = COL_ADDR_IN[i-1].next_addr;
      register_sync #(OBUF_ADDR_WIDTH) out_addr (clk, reset, prev_addr, next_addr);
    end
  endgenerate
    assign sys_obuf_read_addr = COL_ADDR_IN[ARRAY_N-1].next_addr;

  // Delay logic for bias reads
  register_sync #(BBUF_ADDR_WIDTH) bias_addr_delay (clk, reset, bias_read_addr, _bias_read_addr);
  register_sync #(1) bias_req_delay (clk, reset, bias_read_req, _bias_read_req);
  generate
    for (i=1; i<ARRAY_N; i=i+1)
    begin: BBUF_COL_ADDR_IN
    wire [ BBUF_ADDR_WIDTH      -1 : 0 ]        prev_addr;
    wire [ BBUF_ADDR_WIDTH      -1 : 0 ]        next_addr;
    wire                                        prev_req;
    wire                                        next_req;
      if (i==1) begin
    assign prev_addr = _bias_read_addr;
    assign prev_req = _bias_read_req;
      end
      else begin
    assign prev_addr = BBUF_COL_ADDR_IN[i-1].next_addr;
    assign prev_req = BBUF_COL_ADDR_IN[i-1].next_req;
      end
      register_sync #(BBUF_ADDR_WIDTH) out_addr (clk, reset, prev_addr, next_addr);
      register_sync #(1) out_req (clk, reset, prev_req, next_req);
    end
  endgenerate
    assign sys_bias_read_addr = BBUF_COL_ADDR_IN[ARRAY_N-1].next_addr;
    assign sys_bias_read_req = BBUF_COL_ADDR_IN[ARRAY_N-1].next_req;

  //=========================================


  //=========================================
  // Output assignments
  //=========================================
    assign obuf_write_data = accumulator_out;//PE和累加之后的结果
    assign sys_obuf_read_req = systolic_out_valid[0];
  register_sync #(1) acc_out_vld (clk, reset, systolic_out_valid[0], acc_out_valid);
    wire                                        _sys_obuf_write_req;
  register_sync #(1) sys_obuf_write_req_delay (clk, reset, acc_out_valid, _sys_obuf_write_req);
  register_sync #(1) _sys_obuf_write_req_delay (clk, reset, _sys_obuf_write_req, sys_obuf_write_req);
  // assign sys_obuf_write_req = acc_out_valid;

    assign acc_out_valid_[0] = acc_out_valid && ~addr_eq;
    assign acc_out_valid_all = |acc_out_valid_;

generate
for (i=1; i<ARRAY_M; i=i+1)
begin: OBUF_VALID_OUT
      register_sync #(1) obuf_output_delay (clk, reset, acc_out_valid_[i-1], acc_out_valid_[i]);
end
endgenerate

    wire [ ARRAY_N              -1 : 0 ]        col_bias_sw;
    wire [ ARRAY_M              -1 : 0 ]        bias_sel;
    wire                                        _bias_sel;
  // assign col_bias_sw[0] = bias_prev_sw;
  register_sync #(1) row_bias_sel_delay (clk, reset, bias_prev_sw, col_bias_sw[0]);
  register_sync #(1) col_bias_sel_delay (clk, reset, col_bias_sw[ARRAY_N-1], _bias_sel);
  register_sync #(1) _bias_sel_delay (clk, reset, _bias_sel, bias_sel[0]);
  generate
    for (i=1; i<ARRAY_N; i=i+1)
    begin: ADD_SRC_SEL_COL
      register_sync #(1) col_bias_sel_delay (clk, reset, col_bias_sw[i-1], col_bias_sw[i]);
    end
    for (i=1; i<ARRAY_M; i=i+1)
    begin: ADD_SRC_SEL
      //register_sync #(1) bias_sel_delay (clk, reset, bias_sel[i-1], bias_sel[i]);
    assign bias_sel[i] = bias_sel[i-1];
    end
  endgenerate

    wire [ ARRAY_M              -1 : 0 ]        acc_enable;
    assign acc_enable[0] = _sys_obuf_write_req;

generate
for (i=1; i<ARRAY_M; i=i+1)
begin: ACC_ENABLE
      //register_sync #(1) acc_enable_delay (clk, reset, acc_enable[i-1], acc_enable[i]);
    assign acc_enable[i] = acc_enable[i-1];
end
endgenerate

//=========================================

//=========================================
// Accumulator 
// 这里的PE是所有a*b加完后，再加一个变量x
//=========================================
generate
for (i=0; i<ARRAY_M; i=i+1)
begin: ACCUMULATOR

    wire [ ACC_WIDTH            -1 : 0 ]        obuf_in;
    wire [ PE_OUT_WIDTH         -1 : 0 ]        sys_col_out;
    wire [ ACC_WIDTH            -1 : 0 ]        acc_out_q;//单个累加结果

    wire                                        local_acc;//使能
    wire                                        local_bias_sel;
    wire                                        local_acc_enable;

    assign local_acc_enable = acc_enable[i];//加法器使能
    assign local_acc = acc[i];//数据选择
    assign local_bias_sel = bias_sel[i];//数据选择

    wire [ ACC_WIDTH            -1 : 0 ]        local_bias_data;//bias
    wire [ ACC_WIDTH            -1 : 0 ]        local_obuf_data;//obuf (output buffer?) 会不会存在多次计算，一次不够所以存output buffer？

    assign local_bias_data = $signed(bbuf_read_data[BIAS_WIDTH*i+:BIAS_WIDTH]);//加载bias数据
    assign local_obuf_data = obuf_read_data[ACC_WIDTH*i+:ACC_WIDTH];//加载obuf数据

    assign obuf_in = ~local_bias_sel ? local_bias_data : local_obuf_data;//选择bias还是obuf data
    assign accumulator_out[ACC_WIDTH*i+:ACC_WIDTH] = acc_out_q;//存储累加结果
    assign sys_col_out = systolic_out[PE_OUT_WIDTH*i+:PE_OUT_WIDTH];//提取每行PE结果

  wire signed [ ACC_WIDTH    -1 : 0 ]        add_in;//被加数
    //FIXME: 这里如果local_acc 一开始就选择acc_out_q，最后结果只能是zzzz
    // 正确的流程只能是add_in一开始选择obuf_in,中途不变或者再切换
    assign add_in = local_acc ? acc_out_q : obuf_in;//选择上一次的计算结果累加,累加最后只有1个元素？ ，或者加obuf
    //有符号加法
    signed_adder #(
    .DTYPE                          ( DTYPE                          ),
    .REGISTER_OUTPUT                ( "TRUE"                         ),
    .IN1_WIDTH                      ( PE_OUT_WIDTH                   ),
    .IN2_WIDTH                      ( ACC_WIDTH                      ),
    .OUT_WIDTH                      ( ACC_WIDTH                      )
    ) adder_inst (
    .clk                            ( clk                            ),  // input
    .reset                          ( reset                          ),  // input
    .enable                         ( local_acc_enable               ),
    .a                              ( sys_col_out                    ),
    .b                              ( add_in                         ),
    .out                            ( acc_out_q                      )
      );
end
endgenerate
//=========================================

`ifdef COCOTB_TOPLEVEL_systolic_array
  initial begin
    $dumpfile("systolic_array.vcd");
    $dumpvars(0, systolic_array);
  end
`endif

endmodule
