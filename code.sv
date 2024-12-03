module Cache_create;
  // Parameters for cache properties
  parameter ADDRESS_BITS = 32;
  parameter OFFSET_BITS = 6;
  parameter INDEX_BITS = 14;
  parameter NSETS = 2**14;

  // Typedefs for cache structure
  typedef struct {
    bit [1:0] mesi_bits;
    bit dirty;
    bit valid;
    bit [11:0] tag_bits;
  } cache_line; // One cache line

  typedef struct {
    bit [14:0] plru_bits;           // 15 pseudo LRU bits for each set
    cache_line cache_lines[15:0];   // 16-way associativity
  } cache_set; // One cache set

  // Cache declaration
  cache_set cache[NSETS-1:0]; // Array of cache sets

  // File parsing declarations
  int file;
  int status;
  int operation;
  string address;
  string input_file;

  // Task to parse the file
  task file_parsing;
    begin
      // Attempt to get the input file from plusargs
      if ($value$plusargs("INPUT=%s", input_file) == 0) begin
        `ifdef DEBUG_ON
          $display("DEBUG mode ON");
          $display("No file specified. Using default file: default_file.din");
        `endif
        input_file = "default_file.din"; // Set default file if no file is specified
      end else begin
        `ifdef DEBUG_ON
          $display("DEBUG mode ON");
          $display("Opening user-specified file: %s", input_file);
        `endif
      end

      // Attempt to open the specified or default file
      file = $fopen(input_file, "r");
      
      // Check if the file was successfully opened
      if (file == 0) begin
        if (input_file != "default_file.din") begin
          `ifdef DEBUG_ON
            $display("DEBUG mode ON");
            $display("Error opening specified file: %s. Attempting default file.", input_file);
          `endif
          // Fallback to default file
          input_file = "default_file.din";
          file = $fopen(input_file, "r");
        end

        // Terminate if the file still can't be opened
        if (file == 0) begin
          `ifdef DEBUG_ON
            $display("DEBUG mode ON");
            $display("Error opening default file: %s", input_file);
          `endif
          $finish;
        end
      end

      `ifdef DEBUG_ON
        $display("DEBUG mode ON");
        $display("File %s opened successfully", input_file);
      `endif

      // Start file parsing
      $display("Parsing file: %s", input_file);

      // Read each line from the file
      while (!$feof(file)) begin
        // Read a line with format: operation address
        status = $fscanf(file, "%d %s\n", operation, address);

        if (status == 2) begin
          // Display parsed values
          $display("Parsed - Operation: %0d, Address: %s", operation, address);
        end else begin
          // Error message for incorrect format
          $display("Error: Invalid file format on line. Expected <int> <string>");
        end
      end

      // Close the file after reading
      $fclose(file);
      $display("Finished parsing file %s", input_file);
    end
  endtask

  // Initial block to call file_parsing
  initial begin
    $display("Start Cache Simulation");

    // Call file_parsing task
    file_parsing;

    // Simulate cache operations (can be extended later)
    #1000;
    $finish;
  end

endmodule

