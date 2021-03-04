`timescale 1ns/1ps
/*
module sum:
  a block of memory;
  reset will set to-read data to 0;
  read data: a request, an address, to-read var
  write data: a request, an address, to-write data;
 
*/
module ram
#(
  parameter integer DATA_WIDTH    = 10,
  parameter integer ADDR_WIDTH    = 12,
  parameter integer OUTPUT_REG    = 0
)
(
  input  wire                         clk,
  input  wire                         reset,

  input  wire                         s_read_req,//read request
  input  wire [ ADDR_WIDTH  -1 : 0 ]  s_read_addr,//read address
  output wire [ DATA_WIDTH  -1 : 0 ]  s_read_data,//to read and send out data

  input  wire                         s_write_req,//data write request
  input  wire [ ADDR_WIDTH  -1 : 0 ]  s_write_addr,//write address
  input  wire [ DATA_WIDTH  -1 : 0 ]  s_write_data//data to write
);

  reg  [ DATA_WIDTH -1 : 0 ] mem [ 0 : 1<<ADDR_WIDTH ]; // mem array size is 2^ADD_WIDTH, each one has DATA_WIDTH bits

  always @(posedge clk)
  begin: RAM_WRITE
    if (s_write_req)//has a write request
      mem[s_write_addr] <= s_write_data;//write data to corresponding address
  end

  generate
    if (OUTPUT_REG == 0)//output is not a reg but a wire, trans data directly without clk delay
      assign s_read_data = mem[s_read_addr];//TODO: reset will not affect s_read_data, its a one time assign
    else begin
      reg [DATA_WIDTH-1:0] _s_read_data;//produce a reg
      always @(posedge clk)
      begin
        if (reset)//sync high reset signal
          _s_read_data <= 0;
        else if (s_read_req)//request read data
          _s_read_data <= mem[s_read_addr];
      end
      assign s_read_data = _s_read_data;//connect wires to reg
    end
  endgenerate
endmodule
