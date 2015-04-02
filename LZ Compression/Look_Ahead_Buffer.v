/*

Author: Clarke Austin
Date: 2/2/2015

This module implements a buffer.
To be used in compression to look at inputs after the byte being compressed.
Byte 0 refers to the oldest byte and will be the first byte removed.

Inputs:
data_in_valid - is the data on data_in valid
data_in - 8 byte input, all 8 bytes put in buffer at once
remove_n_bytes - take the oldest n bytes off the buffer
get_byte_n - will output byte n on output bus byte_n immediately (combinational)

Outputs:
buffer_ready - there is room on the buffer for 8 bytes to be added
byte_n_valid - the output byte_n is a correct, means get_byte_n asks for a valid byte
byte_n - gets the nth byte of the output

*/

module Look_Ahead_Buffer
  #(parameter LENGTH = 100, parameter N_BITS = 7)
  (
    input clock, reset, data_in_valid, 
    input [N_BITS - 1:0] get_byte_n, remove_n_bytes,
    input [63:0] data_in, 
    output buffer_ready, 
    output byte_n_valid,
    output [7:0] byte_n,
    output reg [N_BITS:0] size,
    output reg [63:0] front_word
  );
  
  reg [7:0] buffer [LENGTH - 1:0];
  reg [7:0] buffer_next [LENGTH - 1:0];
  reg [N_BITS:0] size_next;
  reg [N_BITS:0] m, l, k, j, i;
  reg [63:0] front_word_next;
 
  assign byte_n = buffer[size - 1 - get_byte_n];
  assign byte_n_valid = (reset && get_byte_n < size); 
  assign buffer_ready = (size < LENGTH - 8) && reset ? 1 : 0;
  
  always@(posedge clock) begin
    
    if(!reset) begin
      size <= 0;
      front_word <= 0;
    end     
     
    else begin
      size <= size_next;
      front_word <= front_word_next;
    end
	 
    for(j = 0; j < LENGTH; j = j + 1)
		  buffer[j] <= buffer_next[j];
    
  end
  
  always@* begin
  
  k = 0;
    size_next = size;
    
    for(i = 0; i < LENGTH; i = i + 1)
		  buffer_next[i] = buffer[i];
		  
	  for(l = 0; l < 8; l = l + 1) begin
	    for(m = 0; m < 8; m = m + 1) begin
	     if(size > l)
	       front_word_next[(7-l)*8 + m] = buffer[size - l - 1][m];
	     else
	       front_word_next[(7-l)*8 + m] = 0;
	    end
	  end  
    if(remove_n_bytes != 0 && data_in_valid == 0) begin
      size_next = size - remove_n_bytes;
	  end
		
	  //if trying to add data to buffer
    else if(data_in_valid != 0) begin
      if(size + 8 < LENGTH) begin
        size_next = (remove_n_bytes != 0) ? size + 8 - remove_n_bytes : size + 8;
		  
		    for(k = 8; k < LENGTH; k = k + 1)
			    buffer_next[k] = buffer[k - 8];
			
		    buffer_next[0] = data_in[7:0];
		    buffer_next[1] = data_in[15:8];
		    buffer_next[2] = data_in[23:16];
		    buffer_next[3] = data_in[31:24];
		    buffer_next[4] = data_in[39:32];
		    buffer_next[5] = data_in[47:40];
		    buffer_next[6] = data_in[55:48];
		    buffer_next[7] = data_in[63:56];
      end
      else begin
        size_next = (remove_n_bytes != 0) ? size - remove_n_bytes : size;
      end  
 
    end
      
  end
  
endmodule