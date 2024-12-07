module Cache_create;
  // Parameters for cache properties
  parameter ADDRESS_BITS = 32;
  parameter OFFSET_BITS = 6;
  parameter INDEX_BITS = 14;
  parameter NSETS = 2**14;
  
  //Cache coherency states
  typedef enum {I,E,S,M} states;

  // Typedefs for cache structure
  typedef struct {
    states cache_coherency;
    bit dirty;
    bit valid;
    bit [11:0] tag;
  } cache_line; // One cache line

  typedef struct {
    bit [14:0] plru_bits;           // 15 pseudo LRU bits for each set
    cache_line way[15:0];   // 16-way associativity
  } cache_set; // One cache set

  // Cache declaration
  cache_set Cache[NSETS-1:0]; // Array of cache sets

  // File parsing declarations
  int file;
  int status;
  bit normal_mode, silent_mode;
  int operation;
  bit [31:0] address;
  string input_file;
  
  
  //Output variables
  int cache_reads, cache_writes;
  int cache_hits, cache_misses;
  real hit_ratio;
  
  
  
initial 
begin
      $display("*LLC SIMULATION *****");
	if (!(($value$plusargs("normal_mode=%d ",normal_mode))|($value$plusargs("silent_mode=%d",silent_mode))))
	begin
		normal_mode=0;
		silent_mode=1;
	end
      if (normal_mode==1) $display ("Running the file in normal_mode");
      else $display("Running the file in silent_mode");
      
      $value$plusargs("INPUT=%s",input_file);
      open_file_do_operations();
      $display("Number of cache reads: %0d", cache_reads);
      $display("Number of cache writes: %0d", cache_writes);
      $display("Number of cache hits: %0d", cache_hits);
      $display("Number of cache misses: %0d", cache_misses);
      hit_ratio=cache_hits/cache_misses+cache_hits;
      $display("Cache hit ratio: %f", hit_ratio);
	end
  
  
  task automatic open_file_do_operations();
    file = $fopen(input_file,"r");  //opening file and assigning it to file driscripter
    if (file) $display("File opening was successfull ");
	else $display("File opening was not successfull ");
    while (!$feof(file)) 			//feof to read the data till end of the file
	begin
      status = $fscanf(file , " %d %h\n",operation , address);  // read the data in line 
      
      if (status == 2) begin
        //Calling operations task to check the operation
        operations(operation,address);
      end else begin
        // Error message for incorrect format
        $display("Error: Invalid file format on line. Expected <int> <address_in_hex>");
      end
	end
    $fclose(file);
    $display("Finished parsing file %s", input_file);
  endtask

  
    
  task automatic  operations (input int op,addr);
    case(op)
      0: read_op(addr); //Read request from L1 data cache
      1: write_op(addr); //Write request from L1 data cache
      2: read_op(addr); //Read request from L1 Instruction cache
      3: mode3(addr); //Snooped read request  
      4: mode4(addr); //Snooped write request 
      5: mode5(addr); //Snooped read with intent to modify request
      6: mode6(addr); //Snooped invalidate command
      
	  8: mode8(); //Reseting all the valid states to Invalid 
      9: mode9(); //Printing all the contents valid states in the cache memory
	endcase	
  endtask

  
  //mode 0 Read request from L1 data cache
  task automatic  read_op (input bit [31:0] Address);
    bit x=0;
	bit y=0;
	int z=0;
    
    $display(" **Read request from L1 data cache** ");
	cache_reads++;
    for(int i=0;i<= 15;i++) //Checking for 16 ways
	begin
    ////////CORRECT TILL HERE//////////
				
      if(Cache[Address[19:6]].way[i].tag == Address[31:20]) //hit checking
		begin
		x=1;
          if(Cache[Address[19:6]].way[i].cache_coherency == M)   // if in modified state (will stay in modified state)
			begin
              Cache[Address[19:6]].way[i].cache_coherency = M;
              $display("In set[%0d] way[%0d]=%0h ",Address[19:6],i,Cache[Address [19:6]].way[i].tag);
			  $display(" The state remains in modified \n__");
              updatelru(Address[19:6],i);
			  cache_hits++;
			end
          else if (Cache[Address[19:6]].way[i].cache_coherency == S) // if in shared state  (will stay in shared state)
			begin
                  Cache[Address[19:6]].way[i].cache_coherency = S;
                  $display("In set[%0d] way[%0d]=%0h ",Address[19:6],i,Cache[Address [19:6]].way[i].tag);
				$display(" The state is remains in S: Shared state \n__");
                  updatelru(Address[19:6],i);
				cache_hits++;
			end
          else if(Cache[Address[19:6]].way[i].cache_coherency == E)
			begin
                  Cache[Address[19:6]].way[i].cache_coherency = E;
                  $display("In set[%0d] way[%0d]=%0h ",Address[19:6],i,Cache[Address [20:6]].way[i].tag);
				  $display(" The state remain in Exclusive state only \n__");
                  updatelru(Address[19:6],i);	
				cache_hits++;
			end
          else if (Cache[Address[19:6]].way[i].cache_coherency == I)
			begin
				cache_misses++;
                updatelru(Address[19:6],i);
				
				if(getsnoop(Address)== 2)
				begin
                    Cache[Address[19:6]].way[i].cache_coherency = E;
                    $display("In set[%0d] way[%0d]=%0h ",Address[19:6],i,Cache [Address [19:6]].way[i].tag);
					$display("The state changes from Invalid to Exclusive State ");
					$display("MESSAGE TO L1 : Send Line ");
					$display("BUS OPERATION : READ\n______________________ ");
					
				end
				else
				begin
                    Cache[Address[19:6]].way[i].cache_coherency = S;
					$display("In set[%0d] way[%0d]=%0h ",Address[20:6],i,Cache [Address [20:6]].way[i].tag);
					$display("The state changes from Invalid State to Shared State ");
					$display("MESSAGE TO L1 : Send Line ");
					$display("BUS OPERATION : READ\n______________________ ");
				end
			end
			break;
		end
	end
	
if(x==0)
	begin
		y=0;
      for(int j=0;j<=15;j++)
		begin
			if((Cache[Address[20:6]].way[j].cache_coherency == I)) //checking for empty cache lines
			begin
				cache_misses++;
                Cache[Address[19:6]].way[j].tag=Address[31:20];
			if(getsnoop(Address) == 2)
			begin
			$display("The state changes from Invalid to Exclusive State");
			$display("Send Cache line to L1");
              $display(" Reading data from DRAM and putting it in set[%0d] way[%0d]=%0h ",Address[19:6],j,Cache [Address [19:6]].way[j].tag);
			$display("BUS OPERATION : READ\n______________________ ");
              Cache[Address[19:6]].way[j].cache_coherency = E;
			//$display("MESI_bits:%s",DataCache[Address[20:6]].way[j].cache_coherency.name());
			
			end
		else
			begin
			$display("The state changes from Invalid State to Shared State");
			$display("Send Cache line to L1");
              $display(" Reading data from other caches and putting it in set[%0d] way[%0d]=%0h  ",Address[19:6],j,Cache [Address[19:6]].way[j].tag);
			$display("BUS OPERATION : READ \n__");
			Cache[Address[20:6]].way[j].cache_coherency = S;
			end
              updatelru(Address[19:6],j);
				y=1;
				break;
			end
			else continue;
			
		end
		if(y==0) //conflict miss
		begin
		cache_misses++;
          getlru(Address[19:6],z); //z is the way to evict
          Cache[Address[19:6]].way[z].tag=Address[31:20];
		  if(getsnoop(Address) == 2)
			begin
			$display("The state changes from Invalid to Exclusive State");
			$display("Send Cache line to L1");
			$display(" evicting the cache line  Reading data from dram and putting it in set[%0d] way[%0d]=%0h  ",Address[19:6],z,Cache [Address[19:6]].way[z].tag);
			$display("BUS OPERATION : READ \n__");
              Cache[Address[19:6]].way[z].cache_coherency = E;
			
			end
		else
			begin
			$display("The state changes from Invalid State to Shared State");
			$display("Send Cache line to L1");
			$display(" evicting the cache line  Reading data from other caches and putting it in set[%0d] way[%0d]=%0h  ",Address[19:6],z,Cache [Address [20:6]].way[z].tag);
			$display("BUS OPERATION : READ \n__");
            Cache[Address[19:6]].way[z].cache_coherency = S;
			end
	end
end	


endtask


//mode 1 **write request from L1 data cache
task automatic  write_op(input bit [31:0] add);
int k;
bit count[8];
bit [3:0] final_count;
string result;
bit [3:0] EvictLine;
bit [2:0] Evictcount;
bit [11:0] tag_e;
$display(" **There is a write request from L1 data cache");
cache_writes++;
EvictCondition(add,EvictLine);

if (EvictLine==8)
	begin
	for (int z=0;z<=15;z++)
		begin
			if (Cache [add [19:6]].way[z].tag!=add[31:20])
				count[z]=1;
			else 
				begin
				count[z]=0;
				cache_hits++;
				Cache [add [19:6]].way[z].cache_coherency=M;
				end
		end
	final_count= count[0]+count[1]+count[2]+count[3]+count[4]+count[5]+count[6]+count[7];
		 if (final_count==8)
				
				$display("BUS OPERATION = RWIM");
		        $display("MESSAGE TO L1 = EVICTLINE");
		        $display("MESSAGE TO L1 = SEND LINE");
				
				
				begin
				
				getlru (add[19:6], k);
				tag_e= Cache[add [19:6]].way[k].tag;
				cache_misses++;
				$display("Evict the tag :%0h",tag_e);
				if (Cache [add [19:6]].way[k].cache_coherency==S)
				begin
					Cache [add [19:6]].way[k].tag=add[31:20];
					Cache [add [19:6]].way[k].cache_coherency=M;
					$display("BUS OPERATION = INVALIDATE");
				end
				else 
					begin
					Cache [add [19:6]].way[k].tag=add[31:20];
					Cache [add [19:6]].way[k].cache_coherency=M;
					end
				$display(" Get LRU CALLED Writing into set[%0d] way[%0d]=%0h",add[19:6],k,Cache [add [19:6]].way[k].tag);
				
				end
	end
else
	begin
		for (int j=0;j<=15;j++)
			begin
			if (Cache [add[19:6]].way[j].cache_coherency==I)
				begin
				getsnoop1(add);
				//$display("ResultType  ::  %s ",result);
				Cache [add [19:6]].way[j].tag=add[31:20];
				$display(" Writing into set[%0d] way[%0d]=%0h , Bus operation = RWIM",add[19:6],j,Cache [add [19:6]].way[j].tag);
				$display("BUS OPERATION = RWIM");
		        
		        $display("MESSAGE TO L1 = SEND LINE");
				Cache [add[19:6]].way[j].cache_coherency=M;
				updatelru(add[19:6],j);
				cache_misses++;
				break;
				end
			else if (Cache [add[19:6]].way[j].cache_coherency==S && (Cache [add [19:6]].way[j].tag==add[31:20]))
				begin 
				
				//getsnoop1(add);
				//$display("ResultType  ::  %s ",result);
				$display(" Writing into set[%0d] way[%0d]=%0h  ",add[19:6],j,Cache [add [19:6]].way[j].tag);
				Cache [add[19:6]].way[j].cache_coherency=M;
				updatelru(add[19:6],j);
				$display("MESSAGE TO L1 CACHE= SEND LINE");
				$display("BUS OPERATION = INVALIDATE");
				cache_hits++;
				break;
				end
			else if (Cache [add[19:6]].way[j].cache_coherency==M && (Cache [add [19:6]].way[j].tag==add[31:20]))
				begin 
				getsnoop1(add);
				//$display("ResultType  ::  %s ",result);
				$display(" Writing into set[%0d] way[%0d]=%0h  ",add[19:6],j,Cache [add [19:6]].way[j].tag);
				Cache [add[19:6]].way[j].cache_coherency=M;
				updatelru(add[19:6],j);
				$display("MESSAGE TO L1 CACHE= SEND LINE");
				cache_hits++;
				break;
				end
			else if (Cache [add[19:6]].way[j].cache_coherency==E && (Cache [add [19:6]].way[j].tag==add[31:20]))
				begin 

				getsnoop1(add);
				//$display("ResultType  ::  %s ",result);
				$display(" Writing into set[%0d] way[%0d]=%0h  ",add[19:6],j,Cache [add [19:6]].way[j].tag);
				Cache [add[19:6]].way[j].cache_coherency=M;
				updatelru(add[19:6],j);
				$display("MESSAGE TO L1 CACHE= SEND LINE");
				cache_hits++;
				break;
				end
			end
		
	end	
endtask

function automatic void getsnoop1(input bit [31:0] add);
string str1="HIT",str2="HITM",str3="NOHIT";

	case({add[1:0]})
		2'b00: $display("GET_SNOOP_RESULT=%s",str1);
		2'b01: $display("GET_SNOOP_RESULT=%s",str2);
		2'b10: $display("GET_SNOOP_RESULT=%s",str3);
		2'b11: $display("GET_SNOOP_RESULT=%s",str3);
	endcase
endfunction


task automatic EvictCondition(input bit [31:0] add,output bit [3:0] final_count);
bit count[8];
for(int z=0;z<=15;z++)
	
	begin
		
		if (Cache [add[19:6]].way[z].cache_coherency!=I)
		count[z]=1;
		else count[z]=0;
		    
	end
	
    final_count= count[0]+count[1]+count[2]+count[3]+count[4]+count[5]+count[6]+count[7];
	//$display("finalcount=%d", final_count );
endtask

//MODE3*Snooped Read Request*//

task automatic mode3(input bit[31:0] Address);
bit x =0;
for(int i=0;i<= 15;i++)
begin
if(Cache[Address[19:6]].way[i].tag == Address[31:20])
	begin
	x=1;
	if(Cache[Address[19:6]].way[i].cache_coherency == M)
	begin
	Cache[Address[19:6]].way[i].cache_coherency = S;
	//PutSnoopResult(Address,HITM);
	//GETLINE L1;	
	//$display(" The state is modified to S: Shared state and request L1 to flush the data");
	$display("MESSAGE TO L1: GETLINE");
	$display("BUS OPERATION = WRITE");
	$display("SNOOP RESULT : HITM");
	end
	else if (Cache[Address[19:6]].way[i].cache_coherency == S)
	begin
	Cache[Address[19:6]].way[i].cache_coherency = S;
	$display(" The state is remains in S: Shared state");
	$display("SNOOP RESULT : HIT");
	//PutSnoopResult(Address,HIT);
	end
	else if(Cache[Address[19:6]].way[i].cache_coherency == E)
	begin
	Cache[Address[19:6]].way[i].cache_coherency = S;
	$display("SNOOP RESULT : HIT");
	$display(" The state is goes to S: Shared state");
	//PutSnoopResult(Address,HIT);
	end
    else 
	begin
	Cache[Address[19:6]].way[i].cache_coherency = I;
	$display(" The state is remains in I: Invalid state ");	
	$display("SNOOP RESULT : NOHIT");
	//PutSnoopResult(Address,NOHIT);
	end
	break;
	end
	
end

if(x==0)
$display("SNOOP RESULT : NOHIT");

endtask  
  

//MODE4  ****SNOOPED WRITE REQUEST****************
task automatic mode4(input bit[31:0] Address);
//for(int i=0;i<= 15;i++)
//begin
	//if((Cache[Address[19:6]].way[i].tag) == Address[31:20])
	//begin
	$display(" Snoop write command occured, nothing can be done with our processor ");
	//end
//end
endtask


endmodule
