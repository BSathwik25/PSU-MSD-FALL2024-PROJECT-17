
module file_parser;

  // File check declarations
  int file;
  int status;

  // Parsing declarations
  int operation;
  string address;

  // File name declarations
  string input_file;

  // Task to parse file
  task file_parsing;
    // Attempt to get the input file from plusargs
    if ($value$plusargs("INPUT=%s", input_file) == 0) begin
      `ifdef DEBUG_ON
        $display("DEBUG mode ON");
        $display("No file specified. Using default file: default_file.din");
      `endif
      input_file = "default_file.din"; // Set default file if no file specified
    end else begin
      `ifdef DEBUG_ON
        $display("DEBUG mode ON");
        $display("Opening user-specified file: %s", input_file);
      `endif
    end

    // Attempt to open the specified or default file
    file = $fopen(input_file, "r");
    
    // Check if file was successfully opened
    if (file == 0) begin
      if (input_file != "default_file.din") begin
        `ifdef DEBUG_ON
          $display("DEBUG mode ON");
          $display("Error opening specified file: %s. Attempting default file.", input_file);
        `endif
        // Fallback to default file if the specified file can't be opened
        input_file = "default_file.din";
        file = $fopen(input_file, "r");
      end

      // If the file still can't be opened, terminate the simulation
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
        // Display parsed values, including operation 0
        $display("Parsed - Operation: %0d, Address: %s", operation, address);
      end else begin
        // Error message for incorrect format in the file
        $display("Error: Invalid file format on line. Expected <int> <string>");
      end
    end

    // Close the file after reading
    $fclose(file);
    $display("Finished parsing file %s", input_file);
  endtask

  // Initial block to call the task
  initial begin
    $display("Start");
    file_parsing;
    #1000;
    $finish;
  end

endmodule
