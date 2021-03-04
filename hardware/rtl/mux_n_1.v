//
// n:1 Mux
//
// Hardik Sharma
// (hsharma@gatech.edu)

//mux_n_1 sum
//if n==1 , out = in
//if n==2 , call mux_2_1
//if n>2  , split data into 2 parts, then call itself mux_(2/n)_1 twice, until data size ==2, call mux_2_1, get final result;


`timescale 1ns/1ps
module mux_n_1 #(
  parameter integer WIDTH     = 8,                // Data Width
  parameter integer LOG2_N    = 7,                // Log_2(Num of inputs)
  parameter integer IN_WIDTH  = (1<<LOG2_N)*WIDTH,// Input Width = (2^LOG2_N) * Data Width //移位实现可变参数
  parameter integer OUT_WIDTH = WIDTH,            // Output Width
  parameter integer TOP_MODULE = 1                 // Output Width
) (
  input  wire        [ LOG2_N         -1 : 0 ]    sel,
  input  wire        [ IN_WIDTH       -1 : 0 ]    data_in,
  output wire        [ OUT_WIDTH      -1 : 0 ]    data_out
);

genvar ii, jj;//TODO: never used
generate
if (LOG2_N == 0) //IN_WIDTH = (1<<0)WIDTH = WIDTH = OUT_WIDTH
begin
  assign data_out = data_in;//IN_WIDTH == OUT_WIDTH 直接赋值 out = in
end
else if (LOG2_N > 1) // IN_WIDTH 宽度 > OUT_WIDTH，需要进入选择器
begin
  localparam integer SEL_LOW_WIDTH = LOG2_N-1; // select at lower level has 1 less width,以实现二分 2^log2_n / 2 
  localparam integer IN_LOW_WIDTH  = IN_WIDTH / 2; // Input at lower level has half width, 选择indata一半宽度的位置
  localparam integer OUT_LOW_WIDTH = OUT_WIDTH; // Output at lower level has same width

  //以下做二分,递归调用
  wire [ SEL_LOW_WIDTH  -1 : 0 ] sel_low; //这里sel_low能够选择的范围相比sel减少一半
  wire [ IN_LOW_WIDTH   -1 : 0 ] in_0; //half length of IN_WIDTH
  wire [ IN_LOW_WIDTH   -1 : 0 ] in_1; //half length of IN_WIDTH
  wire [ OUT_LOW_WIDTH  -1 : 0 ] out_0;//standard length of OUT_WIDTH
  wire [ OUT_LOW_WIDTH  -1 : 0 ] out_1;//standard length of OUT_WIDTH

  assign sel_low = sel[LOG2_N-2: 0];//这里sel_low没有取到高位，在二分后的一半长度中一样可以实现选择
  assign in_0 = data_in[0+:IN_LOW_WIDTH];//二分低位
  assign in_1 = data_in[IN_LOW_WIDTH+:IN_LOW_WIDTH];//二分高位

  //低位一半data递归
  mux_n_1 #(
    .WIDTH          ( WIDTH         ),
    .TOP_MODULE     ( 0             ),
    .LOG2_N         ( SEL_LOW_WIDTH )
  ) mux_0 (
    .sel            ( sel_low       ),
    .data_in        ( in_0          ),
    .data_out       ( out_0         )
  );
  //高位一半data递归
  mux_n_1 #(
    .WIDTH          ( WIDTH         ),
    .TOP_MODULE     ( 0             ),
    .LOG2_N         ( SEL_LOW_WIDTH )
  ) mux_1 (
    .sel            ( sel_low       ),
    .data_in        ( in_1          ),
    .data_out       ( out_1         )
  );

  //递归后只留下2个的outdata结果
  //例如sel=0 , indata = 0a0b0c0d => mux(0a0b)  mux(0c0d) => mux(0b0d) => 0d;
  wire sel_curr = sel[LOG2_N-1];
  localparam IN_CURR_WIDTH = 2 * OUT_WIDTH;
  wire [ IN_CURR_WIDTH -1 : 0 ] in_curr = {out_1, out_0};//拿到上面两个二分高低位的outdata结果，拼凑到一起进行2to1选择

  mux_2_1 #(
    .WIDTH          ( WIDTH         )
  ) mux_inst_curr (
    .sel            ( sel_curr      ),
    .data_in        ( in_curr       ),
    .data_out       ( data_out      )
  );
end
else//if (LOG2_N == 1),2选1
begin
  mux_2_1 #( //IN_WIDTH = 2* OUT_WIDTH
    .WIDTH          ( WIDTH         )
  ) mux_inst_curr (
    .sel            ( sel           ),
    .data_in        ( data_in       ),
    .data_out       ( data_out      )
  );
end
endgenerate
//=========================================
// Debugging: COCOTB VCD
//=========================================
`ifdef COCOTB_TOPLEVEL_mux_n_1
if (TOP_MODULE == 1)
begin
  initial begin
    $dumpfile("mux_n_1.vcd");
    $dumpvars(0, mux_n_1);
  end
end
`endif

endmodule
