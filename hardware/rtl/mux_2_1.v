//
// 2:1 Mux
//
// Hardik Sharma
// (hsharma@gatech.edu)

`timescale 1ns/1ps
module mux_2_1#(
  parameter integer WIDTH     = 8,        // Data Width
  parameter integer IN_WIDTH  = 2*WIDTH,  // Input Width = 2 * Data Width =16
  parameter integer OUT_WIDTH = WIDTH     // Output Width
) 
(
  input  wire                                     sel,
  input  wire        [ IN_WIDTH       -1 : 0 ]    data_in, //equal to data_in = {data1,data2}; bitlen=16
  output wire        [ OUT_WIDTH      -1 : 0 ]    data_out//equal to data_out = data1 or data2; bitlen=8
);

assign data_out = sel ? data_in[WIDTH+:WIDTH] : data_in[0+:WIDTH];
//[0+:WIDTH]  equal to  [0:WIDTH-1]

endmodule
