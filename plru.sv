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
//MODE5*SNOOPED READ WITH INTENT TO MODIFIY REQUEST********
task automatic mode5(input bit [31:0] address);
bit [3:0] c;
for (int k=0;k<=15;k++)
	begin
	if (Cache[address[19:6]].way[k].tag==address[31:20])
		begin
			c++;
			if (Cache[address[19:6]].way[k].cache_coherency==M)
				begin
				$display("*HIT TO A MODIFIED LINE and need to flush the data and changing to Invalid State ****");
				Cache[address[19:6]].way[k].cache_coherency=I;
				$display("SNOOP RESULT : HITM");
				$display("MESSAGE TO L1 : GET LINE");
				$display("BUS OPERATION : WRITE");
				$display("MESSAGE TO L1 : INVALIDATE LINE");
				break;
				end
			else if (Cache[address[19:6]].way[k].cache_coherency==E)
				begin
				$display("In Exclusive state and changing to Invalid State");
				Cache[address[19:6]].way[k].cache_coherency=I;
				$display("SNOOP RESULT : HIT");
				$display("MESSAGE TO L1 : INVALIDATE LINE");
				break;
				end
			else if (Cache[address[19:6]].way[k].cache_coherency==S)
				begin
				$display("*In Shared state and changing to Invalid State *");
				$display("SNOOP RESULT : HIT");
				$display("MESSAGE TO L1 : INVALIDATE LINE");
				Cache[address[19:6]].way[k].cache_coherency=I;
				break;
				end
			else if (Cache[address[19:6]].way[k].cache_coherency==I)
				begin
				$display("In Invalid state");
				Cache[address[19:6]].way[k].cache_coherency=I;
				$display("SNOOP RESULT : NOHIT");
				break;
				end
		end
	else 
		begin
		if (k==15 && c==0 )
			begin
			$display("Not there in this Set [%0d] and it is a miss",address[19:6]);
			
			end
		else
			continue;
		end
	end
endtask
//MODE 6 ****invalidate snoop*****
task automatic mode6(input bit[31:0] Address);
for(int i=0;i<= 15;i++)
begin
if((Cache[Address[19:6]].way[i].tag) == Address[31:20])
begin
	if(Cache[Address[19:6]].way[i].cache_coherency == S)
	begin
    Cache[Address[19:6]].way[i].cache_coherency = I;
	
	$display(" Snoop invalidate command occured and proccesor trying to write so all states goes into invalid state ");
    $display("MESSAGE TO L1 : INVALIDATE LINE");	
	end
end //if end
end //for end
endtask
  
//Mode 8*CLEAR THE CACHE AND RESET ALL STATE*****
task automatic mode8();
  for(int i=0;i<NSETS;i++)
begin
	for(int j=0;j<=15;j++)
		begin
		Cache [i].way[j].cache_coherency=I;
		end
	$display("Reseting set[%0d] ",i);
end
endtask
  
  
//Mode9**PRINT CONTENTS AND STATE OF EACH VALID CACHE LINE*****
task  mode9();
$display("Printing contents of valid cache lines");
begin
  for (int i=0;i<NSETS;i++)
		for (int j=0;j<=15;j++)
			begin
				if (Cache [i].way[j].cache_coherency!=I)
					$display("set[%0d] way[%0d]=%0h MESI_bits:%s",i,j,Cache[i].way[j].tag,Cache[i].way[j].cache_coherency.name());
				end
			end
endtask
  
//GETSNOOP FUNCTION
function int getsnoop(input bit [31:0] add);
	typedef enum {HIT, HITM, NOHIT} h;
	int Result;
	case({add[1:0]})
		2'b00: Result = HIT;
		2'b01: Result = HITM;
		2'b10: Result = NOHIT;
		2'b11: Result = NOHIT;
	endcase
	return Result;
endfunction
//*UPDATE LRU*****
task   updatelru(inout [13:0] set,bit[3:0] way);
	case(way)
		3'b000:Cache[set].plru_bits=Cache[set].plru_bits&116;
		3'b001:Cache[set].plru_bits=(Cache[set].plru_bits&124)| 8;
		3'b010:Cache[set].plru_bits=(Cache[set].plru_bits&110)| 2;
		3'b011:Cache[set].plru_bits=(Cache[set].plru_bits&126)| 18;
		3'b100:Cache[set].plru_bits=(Cache[set].plru_bits&91)| 1;
		3'b101:Cache[set].plru_bits=(Cache[set].plru_bits&123)| 33;
		3'b110:Cache[set].plru_bits=(Cache[set].plru_bits&63)| 5;
		3'b111:Cache[set].plru_bits=(Cache[set].plru_bits&127)| 69;
	endcase
	//$display("Set : %0d way:%0d plru_bits:%b",set,way,Cache[set].plru_bits);
endtask
  
  
//GET LRU******************************
task getlru(inout bit [13:0] set,output  bit[3:0] way);
 
if(Cache[set].plru_bits[0]==1) //root node
begin
  if(Cache[set].plru_bits[1]==1) //level 1-1
  begin
      	if(Cache[set].plru_bits[3]==1)//level 2-1
	begin
        	if(Cache[set].plru_bits[7]==1)//level 3-1
        	begin
          		way=0;
			updatelru (set,way);
		end
		else 
		begin 
			way=1;
			updatelru (set,way);
                end//if end of level 3-1
          	if(Cache[set].plru_bits[8]==1)//level 3-2
        	begin
            	way=2;
            	updatelru (set,way);
        	end
        	else
        	begin
            	way=3;
                updatelru (set,way);
                end//if end of level 3-2
        end//if end of level 2-1
      	if(Cache[set].plru_bits[4]==1)//level 2-2
        begin
          	if(Cache[set].plru_bits[9]==1)//level 3-3
            begin
              	way=4;
              	updatelru (set,way);
            end
        	else
            begin
              	way=5;
              	updatelru (set,way);
            end//if end of level 3-3
          	if(Cache[set].plru_bits[10]==1)//level 3-4
            begin
              	way=6;
              	updatelru (set,way);
            end
        	else
            begin
              	way=7;
              	updatelru (set,way);
            end//if end of level 3-4
        end//if end of level 2-2
    end//if end of level 1-1
    if(Cache[set].plru_bits[2]==1)//level 1-2
    begin
      	if(Cache[set].plru_bits[5]==1)//level 2-3
        begin
          	if(Cache[set].plru_bits[11]==1)//level 3-5
            begin
              	way=8;
              	updatelru (set,way);
            end
          	else 
            begin
              	way=9;
              	updatelru (set,way);
            end//if end of level 3-5
          	if(Cache[set].plru_bits[12]==1)//level 3-6
           	begin
              	way=10;
              	updatelru (set,way);
            end
          	else
              	way=11;
          		updatelru (set,way);
        	end//if end of level 3-6
    	end//if end of level 2-3
      	if(Cache[set].plru_bits[6]==1)//level 2-4
        begin
            if(Cache[set].plru_bits[13]==1)//level 3-7
            begin
              	way=12;
              	updatelru (set,way);
            end
          	else
            begin
                way=13;
                updatelru (set,way);
            end//if end of level 3-7
            if(Cache[set].plru_bits[14]==1)//level 3-8
            begin
              	way=14;
              	updatelru (set,way);
            end
          	else
            begin
              	way=15;
              	updatelru (set,way);
            end//if end of level 3-8
        end//if end of level 2-4
    end//if end of level 1-2
//end//if end of root node

endtask


endmodule
