/*

Author: Clarke Austin
Date: 2/2/2015

This module implements the static Huffman Trees for the DEFLATE algorithm.

Static Tables used are based off of DEFLATE algorithm description in 4th edition
of "Data Compression, The Complete Reference"

User requests one of literal, length, or distance parts of LZ77 pair to be encoded and the
result is output at the next clock cycle. If multiple or no parts are requested the output is set 
to all zeros.

Inputs:
literal - encode literal_data and move to data_out at next clock cycle
length - encode length_data and move to data_out at next clock cycle
distance - encode distance_data and move to data_out at next clock cycle
literal_data - literal from output of LZ77 algorithm
length_data - length from output of LZ77 algorithm
distance_data -  distance from output of LZ77 algorithm

Outputs:
data_out - will store encoded data for one clock cycle after literal, length, or distance is high
valid_bits - how many bits of data_out should be used, will be 0 if no encoding took place

*/

module Huffman_Top(
  input clock, literal, distance, length,
  input [7:0] literal_data,
  input [13:0] distance_data,
  input [8:0] length_data,
  output reg [15:0] data_out,
  output reg [4:0] valid_bits
);

  reg [15:0] data_out_next;
  reg [4:0] valid_bits_next;

  //Update output registers every clock cycle
  always@(negedge clock) 
  begin
    data_out <= data_out_next;
    valid_bits <= valid_bits_next;
  end
 
  
  
  //Calculate values for output registers
  always@* 
  begin
    if(literal && !distance && !length)  //encode literal
    begin
      if(literal_data < 8'd144)
      begin
        data_out_next = literal_data + 8'd48;
        valid_bits_next = 5'd8;
      end
      else
      begin
        data_out_next = literal_data + 9'd256;
        valid_bits_next = 5'd9;
      end  
    end
    
    else if(!literal && !distance && length)  //encode length
      begin
        if(length_data < 9'd144)
          begin
            data_out_next = length_data + 9'd48;
            valid_bits_next = 5'd8;
          end
        else if(length_data < 9'd256)
          begin
            data_out_next = length_data + 9'd256;
            valid_bits_next = 5'd9;
          end  
        else if(length_data < 9'd280)
          begin
            data_out_next = length_data - 9'd256;
            valid_bits_next = 5'd7;
          end
        else
          begin
            data_out_next = length_data - 8'd88;
            valid_bits_next = 5'd8;
          end
      end
    
    else if(!literal && distance && !length)  //encode distance input
      begin
        ;      
      end
    
    else  //multiple or no encoding requested, output zeros
      begin
        data_out_next = 16'b0;
        valid_bits_next = 5'b0;
      end

  end
  
  
endmodule
