`timescale 1ns / 1ps

`include "xmemdefs.vh"

module xmem_tb;

   //parameters 
   parameter clk_per = 20;
   parameter DATA_W = 32;
   integer i, j, aux_addr, aux_val, err_cnt = 0;
   integer pixels[25-1:0];
   
   //control 
   reg 				clk;
   reg 				rst;
   reg				run;
   wire 			doneA, doneB;

   //mem interface
   reg 				we;
   reg [`MEM_ADDR_W-1:0] 	addr;
   reg [DATA_W-1:0] 		rdata;
   reg 				valid;
   
   //input / output data
   reg [2*`DATABUS_W-1:0] 	flow_in;
   wire [2*DATA_W-1:0]   	flow_out;
   
   //configurations
   reg [2*`MEMP_CONF_BITS-1:0] 	config_bits;
   
   // Instantiate the Unit Under Test (UUT)
   xmem # ( 
	     .DATA_W(DATA_W)
   ) uut (
	     //control 
	     .clk(clk),
	     .rst(rst),
   	     .run(run),
             .doneA(doneA),
	     .doneB(doneB),

	     //mem interface
 	     .we(we),
	     .addr(addr),
	     .rdata(rdata),
	     .valid(valid),

	     //input / output data
	     .flow_in(flow_in),
	     .flow_out(flow_out),
	     
	     //configurations
	     .config_bits(config_bits)
	     
	     );

   initial begin
      
`ifdef DEBUG
      $dumpfile("xmem.vcd");
      $dumpvars();
`endif
      
      //inputs
      clk = 0;
      rst = 1;
      run = 0;

      we = 0;
      addr = 0;
      rdata = 0;
      valid = 0;
     
      flow_in = 0;
      config_bits = 0;
      
      //Global reset (100ns)
      #(clk_per*5) rst = 0;

      //Testing mem interface
      $display("\nTesting mem interface...");
      
      //Write values to memory
      for(i = 0; i < 25; i++) begin
        pixels[i] = $random%50;
        cpu_write(i, pixels[i]);
      end

      //Read values back from memory
      for(i = 0; i < 25; i++) begin
        cpu_read(i, aux_val);
	if(aux_val != pixels[i]) err_cnt++;
      end

      //Check mem interface
      if(err_cnt == 0) $display("Mem interface passed test");
      else $display("Mem interface failed test with %d errors", err_cnt);
      err_cnt = 0;

      //Testing address generator and configuration bus
      $display("\nTesting address generator and configuration bus...");

      //configurations
      //simulate reading first 3x3 block of 5x5 feature map
      config_bits[2*`MEMP_CONF_BITS-1 -: `MEM_ADDR_W] = 3; //iterations
      config_bits[2*`MEMP_CONF_BITS-`MEM_ADDR_W-1 -: `PERIOD_W] = 3; //period
      config_bits[2*`MEMP_CONF_BITS-`MEM_ADDR_W-`PERIOD_W-1 -: `PERIOD_W] = 3; //duty
      config_bits[2*`MEMP_CONF_BITS-4*`MEM_ADDR_W-2*`PERIOD_W-`N_W-1 -: `PERIOD_W] = 0; //delay
      config_bits[2*`MEMP_CONF_BITS-`MEM_ADDR_W-2*`PERIOD_W-`N_W-1 -: `MEM_ADDR_W] = 0; //start
      config_bits[2*`MEMP_CONF_BITS-2*`MEM_ADDR_W-2*`PERIOD_W-`N_W-1 -: `MEM_ADDR_W] = 5-3; //shift
      config_bits[2*`MEMP_CONF_BITS-3*`MEM_ADDR_W-2*`PERIOD_W-`N_W-1 -: `MEM_ADDR_W] = 1; //incr

      //run
      run = 1;
      #(clk_per);
      run = 0;

      //wait until done
      do begin

	//compare expected and actual values
	for(i = 0; i < 3; i++) begin
          for(j = 0; j < 3; j++) begin
            #clk_per;
            if(flow_out[2*DATA_W-1 -: DATA_W] != pixels[aux_addr]) err_cnt++;
            aux_addr += 1;
          end
          aux_addr += (5-3);
        end
      end while(doneA == 0);

      //End simulation
      if(err_cnt == 0) $display("Addr gen and conf bus passed test\n");
      else $display("Addr gen and conf bus failed test with %d errors\n", err_cnt);
      $finish;
   end
	
   always 
     #(clk_per/2) clk = ~clk;
 
   //
   // CPU TASKS
   //
   
   task cpu_write;
      input [`MEM_ADDR_W-1:0] cpu_address;
      input [DATA_W-1:0] cpu_data;
      addr = cpu_address;
      valid = 1;
      we = 1;
      rdata = cpu_data;
      #clk_per;
      we = 0;
      valid = 0;
      #clk_per;
   endtask
 
   task cpu_read;
      input [`MEM_ADDR_W-1:0] cpu_address;
      output [DATA_W-1:0] read_reg;
      addr = cpu_address;
      valid = 1;
      we = 0;
      #clk_per;
      read_reg = flow_out[2*DATA_W-1 -: DATA_W]; 
      valid = 0;
      #clk_per;
   endtask
    	 
endmodule
