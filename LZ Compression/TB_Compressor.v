module TB_Compressor();

  reg clock, reset, compress;
  reg [3:0] valid_bytes_in;
  reg [63:0] bytes_in;
  reg byte_n_valid;
  wire [3:0] get_byte_n;
  reg [7:0] byte_n;
  reg comp;
  wire [7:0] lit;
  wire [4:0] dist, len;
  wire out_val;
  
  always #5 clock = ~clock;
  initial clock = 0;
  
  
  reg [1:0] test_case;
  always@* begin
    if(test_case == 0) begin
      case(get_byte_n) 
        4'd0: begin byte_n_valid = 1; byte_n = 8'h66; end
        4'd1: begin byte_n_valid = 1; byte_n = 8'h77; end
        4'd2: begin byte_n_valid = 1; byte_n = 8'h88; end
        4'd3: begin byte_n_valid = 1; byte_n = 8'h99; end 
        4'd4: begin byte_n_valid = 1; byte_n = 8'haa; end
        4'd5: begin byte_n_valid = 1; byte_n = 8'hbc; end
        4'd6: begin byte_n_valid = 1; byte_n = 8'h88; end
        4'd7: begin byte_n_valid = 1; byte_n = 8'h99; end
        4'd8: begin byte_n_valid = 1; byte_n = 8'haa; end
        4'd9: begin byte_n_valid = 1; byte_n = 8'hbb; end
        4'd10: begin byte_n_valid = 1; byte_n = 8'hcc; end
        default: begin byte_n_valid = 0; byte_n = 8'h0; end   
      endcase
    end
    else begin byte_n_valid = 0; byte_n = 8'h0; end  
  end
  
  
  
  initial begin
    test_case = 0;
    
    reset = 0; 
    comp = 0;
    #10 reset = 1;
    #20;
    #10 valid_bytes_in = 4'd8;
    bytes_in = 64'h0011223344556677;
    
    #10 valid_bytes_in = 4'd4;
    bytes_in = 64'h8899aabbccddeeff;
    #10 valid_bytes_in = 4'd0;
    #100;
    comp = 1;
    #5000;
    
    
    
    $stop;
    
  end
  
  
  Compressor c
  (
    clock, reset, comp,//compress
    bytes_in,
    valid_bytes_in,
    byte_n, byte_n_valid,
    get_byte_n,
    dist,
    len, lit, out_val
  );
  /*
  
module Compressor
  #(parameter Q_LENGTH = 10, parameter Q_BITS = 4, parameter L_LENGTH = 5, parameter L_BITS = 3,
  parameter ANALYZE_SIZE = 5, parameter ANALYZE_NUM = 2)
  (
    input clock, reset, compress,
    input [63:0] bytes_in,
    input [3:0] valid_bytes_in,
    input [7:0] byte_n,
    input byte_n_valid,
    output reg [L_BITS - 1:0] get_byte_n,
    output reg [Q_BITS:0] distance, 
    output reg [L_BITS:0] length,
    output reg [7:0] literal,
    output reg output_valid
  );
  
  */
  
endmodule
