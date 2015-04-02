`timescale 1 ns / 1 ps

module TB_Look_Ahead_Buffer();
  
  parameter length = 20, bits = 5;
  
  reg clock, reset, data_in_valid;
  reg [bits - 1:0] get_byte_n, remove_n_bytes;
  reg [63:0] data_in;
  wire buffer_ready;
  wire byte_n_valid;
  wire [7:0] byte_n;
  wire [bits - 1:0]  size;
  wire [63:0] front_word;
  always #5 clock = ~clock;
  initial clock = 0;
  
  initial begin
    reset = 0;
    remove_n_bytes = 0;
    #10;
    reset = 1;
    data_in_valid = 1;
    data_in = 63'h1111111111111144;
    #10 data_in = 63'h3322222222222299;
    #10 data_in = 63'h33333333333333333;
    #10 data_in = 63'h4444444444444444;
    #10 data_in = 63'h5555555555555555;
    
    #10 //data_in_valid = 0;
    
    #10 get_byte_n = 0 ;
    #10 get_byte_n = 1 ;
    #10 get_byte_n = 2 ;
    #10 get_byte_n = 3 ;
    #10 get_byte_n = 8 ;
    #10 get_byte_n = 16 ;
    #10 get_byte_n = 22;
    
    #10 remove_n_bytes = 2;
    #10 remove_n_bytes = 0;
    
    #10 get_byte_n = 0 ;
    #10 get_byte_n = 1 ;
    #10 get_byte_n = 2 ;
    #10 get_byte_n = 3 ;
    #10 get_byte_n = 4 ;
    #10 get_byte_n = 5 ;
    #10 get_byte_n = 6 ;
    
    $stop;
  end

  Look_Ahead_Buffer #(.LENGTH(length), .N_BITS(bits)) lab
  (
    clock, reset, data_in_valid, 
    get_byte_n, remove_n_bytes,
    data_in, 
    buffer_ready, 
    byte_n_valid,
    byte_n,
    size,
    front_word
  );
  
  
  
endmodule
