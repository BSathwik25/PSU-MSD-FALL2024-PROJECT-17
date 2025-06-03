//Snoop Results of other caches
`define NOHIT 2'b11
`define HIT 2'b00
`define HITM 2'b01

//"---00= HIT,   ---01 = HitM        ---10   or  ---11 = NoHit"

`define READ 1
`define WRITE 2
`define INVALIDATE 3
`define RWIM 4 

 //L2 to L1 Messages
`define GETLINE 1 
`define SENDLINE 2 
`define INVALIDATELINE 3 
`define EVICTLINE 4

//modes
`define NormalMode 1
`define SilentMode 0


module Cache_create;
//Parameters for cache properties
parameter CACHE_SIZE = 1<<23;
parameter CACHE_WAYS = 16;
parameter BLOCK_SIZE = 64;
  
  
 //cache design parameters
localparam int ADDR_BITS = 32;
localparam int OFFSET_BITS =$clog2(BLOCK_SIZE);
localparam int INDEX_BITS = $clog2(NSETS);
localparam int NSETS = CACHE_SIZE/(BLOCK_SIZE*CACHE_WAYS);
localparam int TAG_BITS = 32 - (INDEX_BITS+OFFSET_BITS);
  
  //Cache coherency states
  typedef enum {I,E,S,M} states;

  // Typedefs for cache structure
  typedef struct {
    states cache_coherency;
    bit dirty;
    bit valid;
    bit [TAG_BITS-1:0] tag;
  } cache_line; // One cache line

  typedef struct {
    bit [CACHE_WAYS-2:0] plru_bits;           // 15 pseudo LRU bits for each set
    cache_line way[CACHE_WAYS-1:0];   // 16-way associativity
  } cache_set; // One cache set

  // Cache declaration
  cache_set Cache[NSETS-1:0]; // Array of cache sets

  // File parsing declarations
  int file;
  int status;
  bit normal_mode, silent_mode;
  int operation;
    bit [ADDR_BITS-1:0] address;
  string input_file;
int index_add;
int tag_add;

task parser(input bit [ADDR_BITS-1:0] address);
tag_add = address[ADDR_BITS-1:(INDEX_BITS+OFFSET_BITS)];
index_add = address[INDEX_BITS+OFFSET_BITS-1:OFFSET_BITS];
endtask
  
  
  //Output variables
  int cache_reads, cache_writes;
  int cache_hits, cache_misses;
  real hit_ratio;
  
  
  int SnoopResult;
  int mode;
  
  
  
initial 
begin
      $display("*LLC SIMULATION *****");
if ( $value$plusargs ("MODE=%d", mode)) begin
      	if(mode==1) $display("RUNNING IN NORMAL MODE");
               else $display("RUNNING IN SILENT MODE");
  end
   else begin
       	$display("No Mode Specified. Using Default Mode as SILENT MODE");
       	mode=0;
    end 
  
  if ($value$plusargs("INPUT=%s", input_file)) begin
      `ifdef DEBUG
    		$display("Using particular file: %s", input_file);
      `endif
  end 
  else begin
      input_file = "default_file.din";
      `ifdef DEBUG
      		$display("No file name particularlly, using default file: %s", input_file);
      `endif
  end
  
  opening_file();
  $display("Number of cache reads: %0d", cache_reads);
  $display("Number of cache writes: %0d", cache_writes);
  $display("Number of cache hits: %0d", cache_hits);
  $display("Number of cache misses: %0d", cache_misses);
  hit_ratio=cache_hits/cache_misses+cache_hits;
  $display("Cache hit ratio: %f", hit_ratio);
  
end//initial end
  
  task automatic opening_file();  
    file = $fopen(input_file,"r");  //opening file and assigning it to file driscripter
    if (file == 0) begin
      $fatal("error:could not open file '%s'",input_file);
    end
	else begin
      $display("File opening was successful ");
    end
  
  while (!$feof(file)) 			//feof to read the data till end of the file
	begin
      status = $fscanf(file , " %d %h\n",operation , address);  // read the data in line 
      parser(address);
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


//DISPLAY MESI STATE IN NORMAL MODE*/
function string MESI_to_string(int MESI);
    case (MESI)
        I: return "I";  
        E: return "E"; 
        M: return "M";  
        S: return "S"; 
        default: return "Unknown";
endcase
endfunction
  
  
  
    
 /*BUS OPERATION TYPES *********************************************/
  
  
      function string BusOP_to_string(int BusOperation);
    case (BusOperation)
        `READ      : return "READ";  
        `WRITE     : return "WRITE"; 
        `RWIM      : return "RWIM";  
        `INVALIDATE: return "INVALIDATE"; 
        default    : return "Unknown";
    endcase
   endfunction

  
  
  /*SNOOP RESULT TYPES *********************************************/
  
  
      function string Snoop_to_string(int SnoopResult);
    case (SnoopResult)
        `HIT       : return "HIT";  
        `NOHIT     : return "NOHIT"; 
        `HITM      : return "HITM";   
        default    : return "Unknown";
    endcase
   endfunction

  
  
   /*L2 TO L1 MESSAGE TYPES **********************************/
  
  function string CacheMessage_to_string(int Message);
    case (Message)
        `GETLINE            : return "GETLINE";  
        `INVALIDATELINE     : return "INVALIDATELINE"; 
        `SENDLINE           : return "SENDLINE"; 
        `EVICTLINE          : return "EVICTLINE";
         default            : return "Unknown";
    endcase
   endfunction
 
  
  
  
  /************************************ BUS OPERATIONS *****************************************/

  function automatic void BusOperation(int BusOp, bit[ADDR_BITS-1:0] Address, int SnoopResult);
   if(mode==`NormalMode)
    $display("BusOp: %s, Address: %h, Snoop Result: %s\n",BusOP_to_string(BusOp),Address,Snoop_to_string(SnoopResult));
  endfunction

  
  
    
  /************************************ GET SNOOP RESULTS ***************************************/
//`define NOHIT 2'b11
//`define HIT 2'b00
//`define HITM 2'b01

  function automatic int GetSnoopResult(bit[ADDR_BITS-1:0] Address);
    if(Address[1:0]==2'b00)
        return `HIT;
    else if(Address[1:0]==2'b01)
        return `HITM;
    else
        return `NOHIT;
  endfunction

  
    /************************************ PUT SNOOP RESULTS **************************************/

  function automatic void PutSnoopResult(bit [ADDR_BITS-1:0] Address, int SnoopResult);
    if(mode==`NormalMode)
      $display("SnoopResult: Address %h, SnoopResult: %0d\n", Address, Snoop_to_string(SnoopResult));
  endfunction
  

  
  
  
  
    /************************************ Communication TO UPPER LEVEL CACHE **************************/


  function automatic void MessageToCache(int Message, bit [ADDR_BITS-1:0] Address);
   if(mode==`NormalMode)
     $display("Message to UPPER Level Cache: %s", CacheMessage_to_string(Message));
  endfunction


 

  
  //*mode 0 READ OPERATION **********************/
task automatic read_op(input bit [ADDR_BITS-1:0] Address);
    bit hit_found = 0;
    bit vacancy_found = 0;
  	int valid_count;
    int WayToEvict;
	bit [$clog2(CACHE_WAYS)-1:0] q;
  if(mode == `NormalMode) $display(" *READ REQUEST FROM L1 DATA CACHE* ");
    cache_reads++; //increment cache reads

    // Check for HIT in the cache
  
    for (int i = 0; i < CACHE_WAYS; i++) begin
      if(Cache[index_add].way[i].cache_coherency != I) begin //checking for valid
        valid_count++;
        if (Cache[index_add].way[i].tag == tag_add ) begin //checking tag
            hit_found = 1;
            cache_hits++;
          if (mode == `NormalMode) begin
            $display("HIT/MISS: CACHE HIT");
            $display("MESI STATE: %s, TAG: %h", MESI_to_string(Cache[index_add].way[i].cache_coherency), Cache[index_add].way[i].tag);
          end
           
          MessageToCache(`SENDLINE,Address);
	  
	  q=i;
          updatelru(index_add,q);
         // Update PLRU for the accessed way
        break;
        end// for end
      end //if end
end

    // MISS: Check for Vacancy
      if (hit_found==0 && valid_count != CACHE_WAYS) begin //collision MISS
        cache_misses++;
        
        if(mode==`NormalMode) $display("HIT/MISS: CACHE MISS");
        for (int i = 0; i < CACHE_WAYS; i++) begin
          if (Cache[index_add].way[i].cache_coherency == I) begin //invalid line checking
                vacancy_found = 1;
                
                // Use GetSnoopResult to determine the snoop result
                SnoopResult = GetSnoopResult(Address);
            	
            	BusOperation(`READ,Address,SnoopResult);
                
            	if (SnoopResult == `NOHIT) Cache[index_add].way[i].cache_coherency = E;
                else Cache[index_add].way[i].cache_coherency = S;
				
            if(mode==`NormalMode) $display("MESI STATE: %s, TAG: %h", MESI_to_string(Cache[index_add].way[i].cache_coherency), Cache[index_add].way[i].tag);

                Cache[index_add].way[i].tag = tag_add;
		
		q=i;
                updatelru(index_add,q);
            	MessageToCache(`SENDLINE,Address);
                break;
          end//if end
        end//for ednd
      end//if end

    // MISS: Compulsory (All ways occupied)
      if (hit_found==0 && valid_count==CACHE_WAYS) begin
        cache_misses++;
        if(mode==`NormalMode) $display("HIT/MISS: CACHE MISS");

        // Find the way to evict using the PLRU mechanism
        WayToEvict = get_way(index_add); // PLRU logic determines the eviction way
      
        // Send eviction message to L1
        MessageToCache(`EVICTLINE, Address);

        // Determine snoop result and load the new line
        SnoopResult = GetSnoopResult(Address);
        BusOperation(`READ, Address, SnoopResult);

        if (SnoopResult == `NOHIT) Cache[index_add].way[WayToEvict].cache_coherency = E;
        else Cache[index_add].way[WayToEvict].cache_coherency = S;
        
        if(mode==`NormalMode) $display("MESI STATE: %s, TAG: %h", MESI_to_string(Cache[index_add].way[WayToEvict].cache_coherency), Cache[index_add].way[WayToEvict].tag);
        
        Cache[index_add].way[WayToEvict].tag = tag_add;
	
	q=WayToEvict;
        updatelru(index_add,q);
        //updatelru(bit `(WayToEvict));
        
        MessageToCache(`SENDLINE, Address);
     end

      if(mode==`NormalMode) $display("++++++++++++++++++++++++++++++++++++++++++++++++++");

endtask
/*WRITE OPERATION*/
task automatic write_op(input bit [ADDR_BITS-1:0] Address);
    bit flag = 0;
    int valid_count = 0;
    int WayToEvict;
    bit [$clog2(CACHE_WAYS)-1:0] q;
    if(mode == `NormalMode) begin
	$display(" WRITE REQUEST FROM L1 DATA CACHE ");
    end
    cache_writes++; // Increment cache writes

    // Check for HIT in the cache
    for (int i = 0; i < CACHE_WAYS; i++) begin
        // Check for valid cache line and valid coherency state
        if(Cache[index_add].way[i].cache_coherency != I) begin 
            valid_count++;

            // Checking tag for hit condition
            if (Cache[index_add].way[i].tag == tag_add) begin
                cache_hits++;
                if (mode == `NormalMode) $display("HIT/MISS: CACHE HIT");

                // Send line to upper level cache
                MessageToCache(`SENDLINE, Address);

                // Handle invalidation if necessary
                if(Cache[index_add].way[i].cache_coherency == S) 
                    BusOperation(`INVALIDATE, Address, SnoopResult);

                Cache[index_add].way[i].cache_coherency = M; // Update state to Modified

                if (mode == `NormalMode) $display("MESI STATE: %s, TAG: %h", 
                                                    MESI_to_string(Cache[index_add].way[i].cache_coherency), 
                                                    Cache[index_add].way[i].tag);
		
		q=i;
                updatelru(index_add,q);
                //updatelru(bit `(i)); // Update PLRU for the accessed way
                flag = 1; // Set flag to indicate a hit
                break; // Break out of loop since we found a hit
            end else begin // If the tag doesn't match, it's a miss
                cache_misses++;
                if(mode == `NormalMode) $display("HIT/MISS: CACHE MISS");

                // Stall CPU, check dirty bit and evict if necessary
                if (Cache[index_add].way[i].dirty) begin
                    if (mode == `NormalMode) $display("Evicting dirty line. Writing back to DRAM.");
                    BusOperation(`INVALIDATE, Address, SnoopResult);
                end

                WayToEvict = get_way(index_add); // Determine which line to evict
                MessageToCache(`EVICTLINE, Address); // Send eviction message
                BusOperation(`RWIM, Address, SnoopResult); // Write and invalidate memory

                // Update the evicted cache line with new tag and set as Modified
                Cache[index_add].way[i].tag = tag_add;
                Cache[index_add].way[i].cache_coherency = M;
                Cache[index_add].way[i].dirty = 1; // Set dirty bit to 1

                if(mode == `NormalMode) 
                    $display("MESI STATE: %s, TAG: %h", 
                             MESI_to_string(Cache[index_add].way[WayToEvict].cache_coherency), 
                             Cache[index_add].way[WayToEvict].tag);
		
		q=WayToEvict;
                updatelru(index_add,q);
                //updatelru(bit `(WayToEvict)); // Update PLRU for evicted line
                MessageToCache(`SENDLINE, Address); // Send the updated line to the cache
                flag = 1; // Set flag to indicate a miss has been handled
                break; // Break out of loop after eviction
            end
        end
    end

    // Handling unoccupied miss (valid[index] == 0)
    if (flag == 0 && valid_count != CACHE_WAYS) begin
        cache_misses++;
        if (mode == `NormalMode) $display("HIT/MISS: CACHE MISS (UNOCCUPIED)");

        // Stall CPU and initiate memory request
        for (int i = 0; i < CACHE_WAYS; i++) begin
            if (Cache[index_add].way[i].cache_coherency == I) begin
                BusOperation(`RWIM, Address, SnoopResult); // Write and invalidate memory

                // Update cache metadata
                Cache[index_add].way[i].cache_coherency = M;
                Cache[index_add].way[i].tag = tag_add;
                Cache[index_add].way[i].dirty = 1;

                if (mode == `NormalMode) 
                    $display("MESI STATE: %s, TAG: %h", 
                             MESI_to_string(Cache[index_add].way[i].cache_coherency), 
                             Cache[index_add].way[i].tag);
		
		q=i;
                updatelru(index_add,q);
                //updatelru(bit `(i)); // Update PLRU for unoccupied line
                MessageToCache(`SENDLINE, Address); // Send the new line to the cache
                break; // Break out of loop once cache line is populated
            end
        end
    end

    // Handling case when all ways are valid (eviction necessary)
    if (flag == 0 && valid_count == CACHE_WAYS) begin
        cache_misses++;
        if (mode == `NormalMode) $display("HIT/MISS: CACHE MISS (COMPULSORY)");

        // Evict using PLRU mechanism
        WayToEvict = get_way(index_add); // Get the way to evict

        if (Cache[index_add].way[WayToEvict].dirty) begin
            if (mode == `NormalMode) $display("Evicting dirty line. Writing back to DRAM.");
            BusOperation(`INVALIDATE, Address, SnoopResult); // Invalidate bus operation
        end

        // Read new cache line into memory
        MessageToCache(`EVICTLINE, Address);
        BusOperation(`RWIM, Address, SnoopResult);

        // Update cache metadata
        Cache[index_add].way[WayToEvict].tag = tag_add;
        Cache[index_add].way[WayToEvict].cache_coherency = M;
        Cache[index_add].way[WayToEvict].dirty = 1; // Mark the line as dirty

        if (mode == `NormalMode) 
            $display("MESI STATE: %s, TAG: %h", 
                     MESI_to_string(Cache[index_add].way[WayToEvict].cache_coherency), 
                     Cache[index_add].way[WayToEvict].tag);
		
		q=WayToEvict;
                updatelru(index_add,q);
        //updatelru(bit `(WayToEvict)); // Update PLRU for evicted line
        MessageToCache(`SENDLINE, Address); // Send the updated line to the cache
    end

    if (mode == `NormalMode) $display("++++++++++++++++++++++++++++++++++++++++++++++++++");
endtask

/**SNOOPED READ ********************************************/


  task automatic mode3(input bit[ADDR_BITS-1:0] Address);
     int valid_count=0;
     bit flag=0;

     if (mode==`NormalMode)
           $display("Operation: SNOOPED READ");
    for(int i=0;i< CACHE_WAYS;i++)
        begin

          valid_count+=1;
          if (Cache[index_add].way[i].cache_coherency != I && Cache[index_add].way[i].tag==tag_add)
             begin
               if (Cache[index_add].way[i].cache_coherency == E || Cache[index_add].way[i].cache_coherency == S)
                   PutSnoopResult(Address, `HIT);
               else
                   PutSnoopResult(Address, `HITM);
               Cache[index_add].way[i].cache_coherency = S;
               if(mode==`NormalMode)
                 $display("MESI:%s", MESI_to_string(Cache[index_add].way[i].cache_coherency));
               flag=1;
               break;
             end
        end
    if(flag==0 && valid_count==CACHE_WAYS)
         PutSnoopResult(Address,`NOHIT);
     $display("+++++++++++++++++++++++++++++++++++++++++++++++++++++++++");
  endtask


//MODE4  ****SNOOPED WRITE REQUEST****************
 task automatic mode4(input bit[ADDR_BITS-1:0] Address);
if(mode==`NormalMode)
	$display(" Snoop write command occured, nothing can be done with our processor ");	
endtask
  
//MODE5**SNOOPED READ WITH INTENT TO MODIFIY REQUEST*******
 task automatic mode5(input bit [ADDR_BITS-1:0] Address);
bit flag =0;
int valid_count =0;
  if(mode==`NormalMode) $display("Operation: SNOOPED READ WITH INTENT TO MODIFY");
  for (int k=0;k<=CACHE_WAYS-1;k++)
	begin
      	if (Cache[index_add].way[k].cache_coherency==I && Cache[index_add].way[k].tag==tag_add)
		begin
          valid_count+=1;
          if (Cache[index_add].way[k].cache_coherency==E || Cache[index_add].way[k].cache_coherency==S)
            PutSnoopResult(Address,`HIT);
          else begin
            PutSnoopResult(Address,`HITM);
            MessageToCache(`GETLINE,Address);
          end
          
          MessageToCache(`INVALIDATELINE,Address);
          Cache[index_add].way[k].cache_coherency =I;
          
          if(mode == `NormalMode) begin
            $display("MESI: %s", MESI_to_string(Cache[index_add].way[k].cache_coherency));
          end           
          flag=1;
          break;
       	end//for end
   end//if end
                     
if(flag==0 && valid_count==16)
      PutSnoopResult(Address,`NOHIT);
endtask  

//MODE 6 **************invalidate snoop**********************
task automatic mode6 (input bit [ADDR_BITS-1:0] Address);
  int valid_count = 0;
  bit flag = 0;

  if (mode == `NormalMode)
    $display("Operation: SNOOPED INVALIDATE");

  // Loop through all cache ways
  for (int i = 0; i < CACHE_WAYS; i++) begin
    valid_count++;

    // Check cache coherence and tag match
    if ((Cache[index_add].way[i].cache_coherency == S) && 
        (Cache[index_add].way[i].tag == tag_add)) begin
      PutSnoopResult(Address, `HIT); // Snoop hit
      MessageToCache(`INVALIDATELINE, Address); // Send invalidation message
      Cache[index_add].way[i].cache_coherency = I; // Invalidate line
      flag = 1; // Set flag to indicate hit

      if (mode == `NormalMode)
        $display("MESI: %s", MESI_to_string(Cache[index_add].way[i].cache_coherency));
      break; // Exit loop after finding a match
    end // End of if
  end // End of for

  // If no match and all ways are valid
  if (flag == 0 && valid_count == CACHE_WAYS) begin
    PutSnoopResult(Address, `NOHIT); // Snoop miss
  end // End of if

  $display("+++++++++++++++++++++++++++++++++++++++++++++++++++++++++++++");

endtask

  

//Mode 8*CLEAR THE CACHE AND RESET ALL STATE**************
task automatic mode8();

  for(int i=0;i < NSETS;i++) begin
    for(int j=0;j< CACHE_WAYS;j++) begin
      Cache[i].way[j].cache_coherency = I;
      	Cache[i].way[i].tag = 0;
	end
end

endtask
  
  
//Mode9*PRINT CONTENTS AND STATE OF EACH VALID CACHE LINE************
task  mode9();
  bit valid;
  
	$display("Printing contents of valid cache lines");
  $display("");
  $display("MESI  |   TAG  | SET | WAY | PLRU |");
  
  for (int i=0;i < NSETS;i++) begin
    for (int j=0;j< CACHE_WAYS;j++)begin
      if (Cache [i].way[j].cache_coherency != I) begin
        valid=1;
        $display("---------------------------------------------------------------------------------");
        $display("%s   |  %h  | %d | %d | %b |", MESI_to_string(Cache[i].way[j].cache_coherency), Cache[i].way[j].tag, i, j, Cache[i].plru_bits);
      end//if end
    end//for end
  end//for end
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
  

//UPDATE LRU/
bit [CACHE_WAYS-2:0] PLRU=0;          
           
task automatic updatelru(bit [INDEX_BITS-1:0] set, bit [3:0] way);
begin
	int b=0;
	int i=0;
  	for(i=$clog2(CACHE_WAYS)-1;i>=0;i--) begin
		//for(b=0;b<CACHE_WAYS-2;b++) begin
	
   			Cache[set].plru_bits[b] = way[i]; //MSB
   			b=2*b+1+way[i];
		
	end
end
endtask


function automatic int get_way(bit [INDEX_BITS-1:0] set);
begin
	int b=0;
	int way=0;
	for(int i=0;i<$clog2(CACHE_WAYS);i++) begin
		Cache[set].plru_bits[b] = ~way[i];
    		b=2*b + 1 + (~way[i]);
	end
return way;
end
endfunction


/*bit PLRU[];
function automatic void updatelru( bit [$clog2(CACHE_WAYS)-1:0] way);
int b = 0;
int i;
bit w[];
  for (i = 0; i < $clog2(CACHE_WAYS)-1; i++) begin
	PLRU[b] = way[i]; // next MSB of w
	b = (b << 1) + (1 << way[i]);
  end
	$display(way);
endfunction
  
function automatic int get_way();
int b = 0; // index into PLRU tree bits
bit v[]; // victim way
bit p;
int i;
int x;
  for (i = 0; i < $clog2(CACHE_WAYS)-1; i--) begin
		v[i] = ~PLRU[b]; // next MSB of v
		b = (b << 1) + (1 << ~PLRU[b]);
		p={p,v[i]};
   end

   $cast(x,p);
return(x);
endfunction
*/
endmodule

