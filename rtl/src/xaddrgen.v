`timescale 1ns / 1ps
`include "xversat.vh"

`include "xmemdefs.vh"

module xaddrgen (
		 input                         clk,
		 input                         rst,
		 input                         init,
		 input                         run,

		 //configurations 
		 input [`DADDR_W - 1:0]        iterations,
		 input [`PERIOD_W - 1:0]       period,
		 input [`PERIOD_W - 1:0]       duty,
		 input [`PERIOD_W - 1:0]       delay,
		 input [`DADDR_W - 1:0]        start,
		 input signed [`DADDR_W - 1:0] shift,
		 input signed [`DADDR_W - 1:0] incr,

		 //outputs 
		 output reg [`DADDR_W - 1:0]   addr,
		 output reg                    mem_en,
		 output reg                    done
		 );

   reg signed [`PERIOD_W :0]                   per_cnt, per_cnt_nxt; //period count
   wire [`PERIOD_W :0]                         period_int, duty_int;
   
   reg [`DADDR_W - 1:0]                        addr_nxt;
   
   reg [`DADDR_W - 1:0]                        iter, iter_nxt; //iterations count 


   reg 					       mem_en_nxt;
   reg 					       done_nxt;
   

   parameter IDLE=1'b0, RUN=1'b1;   
   reg 					       state, state_nxt;
   
   assign period_int = {1'b0, period};
   assign duty_int = {1'b0, duty};

   always @ *  begin

      state_nxt = state;
      
      done_nxt  = done;
      mem_en_nxt = mem_en;
      
      per_cnt_nxt = per_cnt;
      addr_nxt = addr;
      iter_nxt = iter;

      if (state == IDLE) begin 
	 if (init) begin 
	    per_cnt_nxt = -{{1'b0}, delay}+1'b1;
	    addr_nxt = start;
	    iter_nxt = `DADDR_W'd1;
	 end 

	 if(run) begin
	    state_nxt = RUN;
	    done_nxt = 1'b0;

	    if(delay == `PERIOD_W'b0)
	      mem_en_nxt = 1'b1;
	    
	 end 
      end else begin //state = RUN

	 //compute mem_en_nxt
	 if ( per_cnt == {{1'b0},{`PERIOD_W'b0}}    ||    (per_cnt == period_int && iter != iterations) )
	   mem_en_nxt = 1'b1;
	 
	 if (per_cnt == duty_int && (period != duty || iter == iterations))
	   mem_en_nxt = 1'b0;
	 
	 //compute per_cnt_nxt
	 per_cnt_nxt = per_cnt + 1'b1;
	 
	 if (per_cnt == period_int) 
	   per_cnt_nxt = {(`PERIOD_W+1){1'b0}}+1'b1;

	 //compute iter_nxt
	 if (per_cnt == period_int) 
	   iter_nxt = iter + 1'b1;


	 //compute addr_nxt
	 if(mem_en)
	   addr_nxt = addr + incr;
	 
	 if (per_cnt == period_int) begin
	    addr_nxt = addr + incr + shift;
	 end
	 
	 if(mem_en == 1'b1 && per_cnt == duty_int && period != duty)
	   addr_nxt = addr;
	 
	 //compute state_nxt
	 if(iter == iterations && per_cnt == period_int) begin 
	    state_nxt = IDLE;
	    done_nxt = 1'b1;
	 end
	 
      end // else: !if(state == IDLE)
   end // always @ *
   

   // register update
   always @ (posedge clk) 
     if (rst) begin
	state <= IDLE;
	mem_en <= 1'b0;
	done <= 1'b1;
	addr <= `DADDR_W'b0;
	per_cnt <= `PERIOD_W'b0;
	iter <= `DADDR_W'b0;
     end else begin 
	state <= state_nxt;
	mem_en <= mem_en_nxt;
	done <= done_nxt;
	addr <= addr_nxt;
	per_cnt <= per_cnt_nxt;
	iter <= iter_nxt;
     end 

endmodule