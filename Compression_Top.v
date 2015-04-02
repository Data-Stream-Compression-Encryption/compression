module Compression_Top
  #(parameter Q_LENGTH = 1000, parameter Q_BITS = 12, 
    parameter ANALYZE_S = 50, parameter ANALYZE_N = 20, 
    parameter L_LENGTH = 100, parameter L_BITS = 7, 
    parameter COMP_POINT = 20)
  (
    input clock, reset, stall, data_in_valid,
    input [63:0] data_in,
    output comp_rdy, 
    output reg dump,
    output [7:0] valid_bits,
    output [63:0] data_out    
  );
  
  //Timer to Reset System (no input)
  reg [28:0] counter;
  reg internal_reset; //active low
  wire internal_dump;
  reg end_byte_received, end_byte_received_next;
  
  assign internal_dump = counter[28] || end_byte_received;
   
  always@(posedge clock) begin
    if(!internal_dump)
      counter <= counter + 1;
    else if(!internal_reset || !reset)
      counter <= 0;
    else
      counter <= counter;
  end
  
  //Variables for Look Ahead Buffer
  reg [L_BITS - 1:0] remove_n_bytes;
  wire [L_BITS - 1:0] get_byte_n;
  wire lab_rdy;
  wire byte_n_valid;
  wire [7:0] byte_n;
  wire [L_BITS:0] size;
  wire [63:0] front_word;
  wire lab_data_in_valid;
  
  assign lab_data_in_valid = data_in_valid && data_in && !end_byte_received;
  assign comp_rdy =  !end_byte_received && lab_rdy;

  Look_Ahead_Buffer #(.LENGTH(L_LENGTH), .N_BITS(L_BITS)) lab
  (
    clock, reset && internal_reset, lab_data_in_valid, 
    get_byte_n, remove_n_bytes,
    data_in, lab_rdy, 
    byte_n_valid, byte_n, size, front_word
  );
  
  //Variables for compressor
  reg compress;
  reg [3:0] comp_bytes_in;
  wire [7:0] literal_out;
  wire [Q_BITS:0] distance_out;
  wire [L_BITS:0] length_out;
  wire output_valid;
  
  Compressor #(.Q_LENGTH(Q_LENGTH), .Q_BITS(Q_BITS), .L_LENGTH(L_LENGTH), .L_BITS(L_BITS),
  .ANALYZE_SIZE(ANALYZE_S), .ANALYZE_NUM(ANALYZE_N)) comp
  (
    clock, reset && internal_reset, compress,
    front_word, comp_bytes_in, byte_n, byte_n_valid,
    get_byte_n, distance_out, length_out, literal_out, output_valid
  );
  
  //Variables for Huffman_Top
  reg literal, distance, length;
  reg [7:0] literal_data, literal_data_next;
  reg [14:0] distance_data, distance_data_next;
  reg [8:0] length_data, length_data_next;
  reg [8:0] countdown, countdown_next;
  

  wire [17:0] encoder_data_out;
  wire [4:0] encoder_valid_bits;
  
  assign data_out = encoder_data_out | 0;
  assign valid_bits = encoder_valid_bits | 0;
  
  Huffman_Top encoder
  (
    clock, literal, distance, length,
    literal_data, distance_data, length_data,
    encoder_data_out, encoder_valid_bits
  );
  
  reg [1:0] state, state_next;
  parameter WAITING = 2'd0, COMPRESSING = 2'd1, UPDATING_1 = 2'd2,  UPDATING_2 = 2'd3;

  always@(posedge clock) begin
    
    if(!reset || !internal_reset) begin
      state <= WAITING;
      literal_data <= 0;
      distance_data <= 0;
      length_data <= 0;
      countdown <= 0;
      end_byte_received <= 0;
    end
    
    else begin
      state <= state_next;
      literal_data <= literal_data_next;
      distance_data <= distance_data_next;
      length_data <= length_data_next;
      countdown <= countdown_next;
      end_byte_received <= end_byte_received_next;
    end
    
  end
  
  always@* begin
    end_byte_received_next = end_byte_received;
    if(data_in_valid && !data_in)
      end_byte_received_next = 1;
  end
  
  always@* begin
    
	  countdown_next = countdown; //!!!!!!!!!!!!!!!!!!!!!!!!!!!!!!!!!!!!!!!!!!!!!!!!!!!!!!!!!!!!!!!!!
    state_next = state;
    compress = 0; 
    comp_bytes_in = 0;
    literal = 0;
    length = 0;
    distance = 0;
    literal_data_next = literal_data;
    distance_data_next = distance_data;
    length_data_next = length_data;
    remove_n_bytes = 0;
    internal_reset = 1;
    dump = 0;
    
    if(state == WAITING) begin 
      if(size >= COMP_POINT) begin
        state_next = COMPRESSING;
        compress = 1;
      end
      else if(internal_dump) begin
        if(size) begin
          state_next = COMPRESSING;
          compress = 1;
        end
        else begin
          internal_reset = 0;
          state_next = WAITING;
          dump = 1; 
        end
      end
    end 
    
    else if(state == COMPRESSING) begin
      if(output_valid) begin
        state_next = UPDATING_1;
        literal_data_next = literal_out;
        distance_data_next = distance_out;
        length_data_next = length_out;
        countdown_next = length_out;
        state_next = UPDATING_1;
      end
    end
    
    else if(state == UPDATING_1) begin
      
      if(!stall) begin
        if(!length_data) 
          literal = 1;
        else begin
          distance = 1;
          distance_data_next = 0;
        end
      
        if(countdown) begin
          remove_n_bytes = (countdown > 7) ? 8 : countdown;
          comp_bytes_in = (countdown > 7) ? 8 : countdown;
          countdown_next = (countdown > 7) ? countdown - 8 : 0;
          state_next = UPDATING_2;
        end
        else begin
          remove_n_bytes = 1;
          comp_bytes_in = 1;
          countdown_next = 0;
          state_next = WAITING;
        end
      end
      
    end
    
    else begin //STATE == UPDATING_2
    
      if(length_data) begin
        length = 1;
        length_data_next = 0;
      end
      
      if(countdown) begin
        remove_n_bytes = (countdown > 7) ? 8 : countdown;
        comp_bytes_in = (countdown > 7) ? 8 : countdown;
        countdown_next = (countdown > 7) ? countdown - 8 : 0;
        state_next = (countdown > 7)  ? UPDATING_2 : WAITING;
      end
      else begin
        state_next = WAITING;
      end

    end
    
  end
  
endmodule
