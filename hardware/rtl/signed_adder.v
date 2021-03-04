//
// Signed Adder
// Implements: out = a + b
//
// Hardik Sharma
// (hsharma@gatech.edu)
//FIXME: FP32 and FP16 not exists?
/*
module sum:
cal with sync clock
3DTYPE:
1.FXP
  cal result, to reg or wire
2.FP32
  cal result, to wire
3.FP16
  cal result, to wire
*/
`timescale 1ns/1ps
module signed_adder #(
    parameter integer  DTYPE                        = "FXP",
    parameter          REGISTER_OUTPUT              = "FALSE",
    parameter integer  IN1_WIDTH                    = 20,
    parameter integer  IN2_WIDTH                    = 32,
    parameter integer  OUT_WIDTH                    = 32
) (
    input  wire                                         clk,
    input  wire                                         reset,//NEVER used
    input  wire                                         enable,
    input  wire  [ IN1_WIDTH            -1 : 0 ]        a,
    input  wire  [ IN2_WIDTH            -1 : 0 ]        b,
    output wire  [ OUT_WIDTH            -1 : 0 ]        out
  );

  generate
    if (DTYPE == "FXP") begin//TODO: What is FXP
      wire signed [ IN1_WIDTH-1:0] _a;
      wire signed [ IN2_WIDTH-1:0] _b;
      wire signed [ OUT_WIDTH-1:0] alu_out;
      assign _a = a;//assign in a
      assign _b = b;//assign in b
      assign alu_out = _a + _b;//cal result a+b
      if (REGISTER_OUTPUT == "TRUE") begin//output to register
        reg [OUT_WIDTH-1:0] _alu_out;//produce a reg
        always @(posedge clk)
        begin
          if (enable)
            _alu_out <= alu_out;//wire to reg
        end
        assign out = _alu_out;//reg to wire(out)
      end else
        assign out = alu_out;//output to wire(out)
    end
    else if (DTYPE == "FP32") begin//4bit
      fp32_add add (
        .clk                            ( clk                            ),
        .a                              ( a                              ),
        .b                              ( b                              ),
        .result                         ( out                            )
        );
    end
    else if (DTYPE == "FP16") begin//2bit faster, less data range, less mem
      fp_mixed_add add (
        .clk                            ( clk                            ),
        .a                              ( a                              ),
        .b                              ( b                              ),
        .result                         ( out                            )
        );
    end
  endgenerate

endmodule
