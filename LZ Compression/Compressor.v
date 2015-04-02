/*
This module implements LZ77 compression.  
This uses a circular queue as a sliding dictionary and needs 
to be connected to a look ahead buffer using the byte_n inputs and outputs.

Inputs:
compress - start compressing the data.
bytes_in - bytes coming in
valid_bytes_in - how many bytes on bytes_in should be added to the queue
byte_n - nth byte of the look ahead buffer
byte_n_valid - is byte_n a correct value

Outputs:
get_byte_n - get byte # n from look ahead buffer
distance - LZ77 output
length - LZ77 output
literal - LZ77 output
output_valid - distance, length, literal are valid outputs
*/

module Compressor
  #(parameter Q_LENGTH = 10, parameter Q_BITS = 4, parameter L_LENGTH = 10, parameter L_BITS = 4,
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
  
  //putting the bytes in an array for convenience
  wire [7:0] byte_array [7:0];
  assign byte_array[7] = bytes_in[7:0];
  assign byte_array[6] = bytes_in[15:8];
  assign byte_array[5] = bytes_in[23:16];
  assign byte_array[4] = bytes_in[31:24];
  assign byte_array[3] = bytes_in[39:32];
  assign byte_array[2] = bytes_in[47:40];
  assign byte_array[1] = bytes_in[55:48];
  assign byte_array[0] = bytes_in[63:56];
  
  
  reg [7:0] queue [Q_LENGTH - 1:0];
  reg [7:0] queue_next [Q_LENGTH - 1:0];
  reg [Q_BITS:0] head, tail, size, head_next, tail_next, size_next;
  
  reg [2:0] state, state_next;
  parameter WAIT = 3'd0, CHECK = 3'd1, ROTATE = 3'd2, ANALYZE_A = 3'd3, ANALYZE_B = 3'd4, OUTPUTTING = 3'd5;
  
  reg [L_BITS:0] checker_num, checker_num_next; 
  reg [Q_BITS:0] distance_next;
  reg [L_BITS:0] length_next;
  reg [7:0] literal_next;
  reg output_valid_next;
  reg [Q_LENGTH - 1:0] possible_spots, possible_spots_next;
  reg [Q_BITS:0] first_match, first_match_next;
  
  reg [ANALYZE_SIZE - 1:0] queue_checker [ANALYZE_NUM - 1:0];
  reg [ANALYZE_SIZE - 1:0] queue_checker_next [ANALYZE_NUM - 1:0];
  reg [Q_BITS:0] first_matches [ANALYZE_NUM - 1:0];
  reg [Q_BITS:0] first_matches_next [ANALYZE_NUM - 1:0];

  always@(posedge clock) begin
    
    if(!reset) begin
      size <= 0;
      head <= 0;
      tail <= 0;
      checker_num <= 0;
      state <= WAIT;
      output_valid <= 0;
		  literal <= literal_next;
		  distance <= distance_next;
		  length <= length_next;
		  first_match <= 0;
    end
    
    else begin
      size <= size_next;
      head <= head_next;
      tail <= tail_next;
      state <= state_next;
      checker_num <= checker_num_next;
      output_valid <= output_valid_next;
		  literal <= literal_next;
		  distance <= distance_next;
		  length <= length_next;
		  first_match <= first_match_next;
    end   
  end
  
  reg [Q_BITS:0] h, i, j, k, l, m;
  
  always@(posedge clock) begin
    for(h = 0; h < ANALYZE_NUM; h = h + 1) begin
      queue_checker[h] <= queue_checker_next[h];
      first_matches[h] <= first_matches_next[h];
    end
    for(i = 0; i < Q_LENGTH; i = i + 1) begin
      queue[i] <= queue_next[i];
      possible_spots[i] <= possible_spots_next[i];
    end
  end

  always@* begin
    
    size_next = size;
    head_next = head;
    tail_next = tail;
    k = 0;
	  m = 0;
    get_byte_n = checker_num;
    state_next = state;
    first_match_next = 0;//FOR THE FOR LOOP TO WORK THIS MAY NEED TO CHANGE
    checker_num_next = checker_num;
    distance_next = 0;
    length_next = 0;
    literal_next = 0;
    output_valid_next = 0;
    
    for(j = 0; j < Q_LENGTH; j = j + 1) begin
      queue_next[j] = queue[j];
      if(head == tail) begin
        if(size == Q_LENGTH)
          possible_spots_next[j] = 1;
        else
          possible_spots_next[j] = 0;
      end
      else begin
        if(head > tail)
          possible_spots_next[j] = (j >= tail && j < head) ? 1 : 0;
        else
          possible_spots_next[j] = (j >= tail || j < head) ? 1 : 0;
      end
    end
    
    for(l = 0; l < ANALYZE_NUM; l = l + 1) begin
      queue_checker_next[l] = queue_checker[l];
      first_matches_next[l] = 0;
    end
    
    //State where the queue can be updated
    if(state == WAIT) begin
      
      if(compress) begin
        state_next = CHECK;
        checker_num_next = 0;
      end
        
      //If there are bytes to input and there is room in the queue
      if(valid_bytes_in != 0) begin
        
        head_next = (head + valid_bytes_in >= Q_LENGTH) ?  
                head + valid_bytes_in - Q_LENGTH : head + valid_bytes_in;
        size_next = (size + valid_bytes_in > Q_LENGTH) ? Q_LENGTH : size + valid_bytes_in; 
        tail_next = (size + valid_bytes_in >= Q_LENGTH) ? head_next : tail; // might want to remove head_next for tming
        for(k = 0; k < 8; k = k + 1) begin
          if(k < valid_bytes_in) begin
				    if(head + k >= Q_LENGTH)
					    queue_next[head + k - Q_LENGTH] = byte_array[k];
				    else
					    queue_next[head + k] = byte_array[k];
			 end
        end
        
      end
    end
    
    else if(state == CHECK) begin
       
      first_match_next = first_match;
      for(k = 0; k < ANALYZE_NUM; k = k + 1) begin
        for(m = 0; m < ANALYZE_SIZE; m = m + 1) begin
          if(!byte_n_valid)// || (head == k*ANALYZE_SIZE + m && checker_num))
            queue_checker_next[k][m] = 0;
          else
            queue_checker_next[k][m] = (!checker_num) 
              ? possible_spots[k*ANALYZE_SIZE + m] && queue[k*ANALYZE_SIZE + m] == byte_n 
                : possible_spots[k*ANALYZE_SIZE + m] && queue_checker[k][m] && queue[k*ANALYZE_SIZE + m] == byte_n; 
       
		  end
      end
      state_next = ANALYZE_A;
    end
    
    else if(state == ROTATE) begin
      //shift the entire queue
      for(k = 0; k < Q_LENGTH - 1; k = k + 1) begin
        queue_next[k] = queue[k + 1];
      end
      queue_next[Q_LENGTH - 1] = queue[0];
      head_next = (head == 0) ? Q_LENGTH - 1 : head - 1;
      tail_next = (tail == 0) ? Q_LENGTH - 1 : tail - 1;
      state_next = CHECK;
      first_match_next = first_match;
    end
    
    else if(state == ANALYZE_A) begin
      first_match_next = first_match;
      for(k = 0; k < ANALYZE_NUM; k = k + 1) begin
        for(m = 0; m < ANALYZE_SIZE; m = m + 1) begin
          if(queue_checker[k][m] && !first_matches_next[k]) 
            first_matches_next[k] = m + 1; 
          else
            first_matches_next[k] = first_matches_next[k];
        end
      end
      state_next = ANALYZE_B;
    end
    
    else if(state == ANALYZE_B) begin
      
      for(k = 0; k < ANALYZE_NUM; k = k + 1) begin
        if(first_matches[k] && !first_match_next)
          first_match_next = k*ANALYZE_SIZE + first_matches[k];
        else
          first_match_next = first_match_next;
      end
       
      if(!first_match_next) begin
        state_next = OUTPUTTING;
        first_match_next = first_match;
      end
      else begin
        state_next = ROTATE;
        checker_num_next = checker_num + 1;
      end
      
    end
    
    else if(state == OUTPUTTING) begin
      get_byte_n = 0;
      literal_next = byte_n;
      
      
      if(first_match < checker_num ) begin // use first_match + Q_LENGTH - checker_num
        if(head > first_match + Q_LENGTH - checker_num) begin
          distance_next = head - (first_match + Q_LENGTH - checker_num) + 1;
        end
        else begin
          distance_next = head - (first_match - checker_num) + 1;
        end
      end
      else begin
        if(head < (first_match - checker_num)) begin
          distance_next = head - (first_match - checker_num) + 1 + Q_LENGTH;
        end
        else begin
          distance_next = head - (first_match - checker_num) + 1;
        end
      end
      
      
      length_next = checker_num;
      output_valid_next = 1;
      state_next = WAIT;
    end
    
    else begin
      $display("ERROR INVALID STATE");
    end
    
  end  

endmodule
