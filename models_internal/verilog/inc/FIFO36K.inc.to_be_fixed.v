
  localparam  fifo_depth = (DATA_WIDTH <= 9) ? 4096 :
                           (DATA_WIDTH <= 18) ? 2048 :
                           1024;
  
  localparam  fifo_addr_width = (DATA_WIDTH <= 9) ? 12 :
                                (DATA_WIDTH <= 18) ? 11 :
                                10;

  reg [fifo_addr_width-1:0] fifo_wr_addr = {fifo_addr_width{1'b0}};
  reg [fifo_addr_width-1:0] fifo_rd_addr = {fifo_addr_width{1'b0}};

  wire [31:0] ram_wr_data;
  wire [3:0] ram_wr_parity;

  reg fwft = 1'b0;
  reg [DATA_WIDTH-1:0] fwft_data = {DATA_WIDTH{1'b0}};

  wire [31:0] ram_rd_data; 
  wire [3:0]  ram_rd_parity;
  wire ram_clk_b;

  integer number_entries = 0;

  generate

    if ((DATA_WIDTH == 9)|| (DATA_WIDTH == 17) || (DATA_WIDTH == 25)) begin: one_parity
      assign ram_wr_data = {{32-DATA_WIDTH{1'b0}}, WR_DATA};
      assign ram_wr_parity = {3'b000, WR_DATA[DATA_WIDTH-1]};
      assign RD_DATA = fwft ? fwft_data : {ram_rd_parity[0], ram_rd_data[DATA_WIDTH-2:0]};
    end else if (DATA_WIDTH == 33) begin: width_33
      assign ram_wr_data = WR_DATA[31:0];
      assign ram_wr_parity = {3'b000, WR_DATA[32]};
      assign RD_DATA = fwft ? fwft_data : {ram_rd_parity[0], ram_rd_data[31:0]};
    end else if ((DATA_WIDTH == 18) || (DATA_WIDTH == 26)) begin: two_parity
      assign ram_wr_data = {{32-DATA_WIDTH{1'b0}}, WR_DATA};
      assign ram_wr_parity = {2'b00, WR_DATA[DATA_WIDTH-1:DATA_WIDTH-2]};
      assign RD_DATA = fwft ? fwft_data : {ram_rd_parity[1:0], ram_rd_data[DATA_WIDTH-3:0]};
    end else if (DATA_WIDTH == 34) begin: width_34
      assign ram_wr_data = WR_DATA[31:0];
      assign ram_wr_parity = {2'b00, WR_DATA[33:32]};
      assign RD_DATA = fwft ? fwft_data : {ram_rd_parity[1:0], ram_rd_data[31:0]};
    end else if (DATA_WIDTH == 27) begin: width_27
      assign ram_wr_data = {8'h00, WR_DATA[23:0]};
      assign ram_wr_parity = {1'b0, WR_DATA[26:24]};
      assign RD_DATA = fwft ? fwft_data : {ram_rd_parity[2:0], ram_rd_data[23:0]};
    end else if (DATA_WIDTH == 35) begin: width_35
      assign ram_wr_data = WR_DATA[31:0];
      assign ram_wr_parity = {1'b0, WR_DATA[34:32]};
      assign RD_DATA = fwft ? fwft_data : {ram_rd_parity[2:0], ram_rd_data[31:0]};
    end else if (DATA_WIDTH == 36) begin: width_36
      assign ram_wr_data = WR_DATA[31:0];
      assign ram_wr_parity = WR_DATA[35:32];
      assign RD_DATA = fwft ? fwft_data : {ram_rd_parity[3:0], ram_rd_data[31:0]};
    end else begin: no_parity
      assign ram_wr_data = fall_through ? wr_data_fwft : {{32-DATA_WIDTH{1'b0}}, WR_DATA};
      assign ram_wr_parity = 4'h0;
      assign RD_DATA = fwft ? fwft_data : ram_rd_data[DATA_WIDTH-1:0];
    end

    if ( FIFO_TYPE == "SYNCHRONOUS" )  begin: sync

      always @(posedge WR_CLK)
        if (WR_EN && !RD_EN)
          number_entries <= number_entries + 1;
        else if (!WR_EN && RD_EN)
          number_entries <= number_entries - 1;

      always @(posedge RESET, posedge WR_CLK)
        if (RESET) begin
          fifo_wr_addr <= {fifo_addr_width{1'b0}};
          fifo_rd_addr <= {fifo_addr_width{1'b0}};
          EMPTY        <= 1'b1;
          FULL         <= 1'b0;
          ALMOST_EMPTY <= 1'b0;
          ALMOST_FULL  <= 1'b0;
          PROG_EMPTY   <= 1'b1;
          PROG_FULL    <= 1'b0;
          OVERFLOW     <= 1'b0;
          UNDERFLOW    <= 1'b0;
          number_entries = 0;
          fwft         <= 1'b0;
          fwft_data    <= {DATA_WIDTH-1{1'b0}};
        end else begin
          if (WR_EN)
            fifo_wr_addr <= fifo_wr_addr + 1'b1;
          EMPTY        <= ((number_entries==0) || ((RD_EN && !WR_EN) && (number_entries==1)));
          FULL         <= ((number_entries==fifo_depth) || ((number_entries==(fifo_depth-1)) && WR_EN && !RD_EN));
          ALMOST_EMPTY <= (((number_entries==1) && !(RD_EN && !WR_EN)) ||  ((RD_EN && !WR_EN) && (number_entries==2)));
          ALMOST_FULL  <= (((number_entries==(fifo_depth-1)) && !(!RD_EN && WR_EN)) ||  ((!RD_EN && WR_EN) && (number_entries==fifo_depth-2)));
          PROG_EMPTY   <= ((number_entries) <= (PROG_EMPTY_THRESH-1));
          PROG_FULL    <= ((fifo_depth-number_entries) <= (PROG_FULL_THRESH-1));
          UNDERFLOW    <= (EMPTY && RD_EN);
          OVERFLOW     <= (FULL && WR_EN);
          if (EMPTY && WR_EN) begin
            fwft_data <= WR_DATA;
            fifo_rd_addr <= fifo_rd_addr + 1'b1;
            fwft <= 1'b1;
          end else if (RD_EN) begin
            //RD_DATA <= ram_rd;
            fwft <= 1'b0;
            if (!(ALMOST_EMPTY && !WR_EN))
              fifo_rd_addr <= fifo_rd_addr + 1'b1;
          end
        end

        assign ram_clk_b = WR_CLK;

        initial begin
          #1;
          @(RD_CLK);
          $display("\nWarning: FIFO36K instance %m RD_CLK should be tied to ground when FIFO36K is configured as FIFO_TYPE=SYNCHRONOUS.");
        end

    end else begin: async

      //  Add async code here

    end

  endgenerate

  // Use BRAM

  TDP_RAM36K #(
    .INIT({32768{1'b0}}), // Initial Contents of memory
    .INIT_PARITY({2048{1'b0}}), // Initial Contents of memory
    .WRITE_WIDTH_A(DATA_WIDTH), // Write data width on port A (1-36)
    .READ_WIDTH_A(DATA_WIDTH), // Read data width on port A (1-36)
    .WRITE_WIDTH_B(DATA_WIDTH), // Write data width on port B (1-36)
    .READ_WIDTH_B(DATA_WIDTH) // Read data width on port B (1-36)
  ) FIFO_RAM_inst (
    .WEN_A(WR_EN), // Write-enable port A
    .WEN_B(1'b0), // Write-enable port B
    .REN_A(1'b0), // Read-enable port A
    .REN_B(RD_EN), // Read-enable port B
    .CLK_A(WR_CLK), // Clock port A
    .CLK_B(ram_clk_b), // Clock port B
    .BE_A(4'hf), // Byte-write enable port A
    .BE_B(4'h0), // Byte-write enable port B
    .ADDR_A({fifo_wr_addr, {15-fifo_addr_width{1'b0}}}), // Address port A, align MSBs and connect unused MSBs to logic 0
    .ADDR_B({fifo_rd_addr, {15-fifo_addr_width{1'b0}}}), // Address port B, align MSBs and connect unused MSBs to logic 0
    .WDATA_A(ram_wr_data), // Write data port A
    .WPARITY_A(ram_wr_parity), // Write parity data port A
    .WDATA_B(32'h00000000), // Write data port B
    .WPARITY_B(4'h0), // Write parity port B
    .RDATA_A(), // Read data port A
    .RPARITY_A(), // Read parity port A
    .RDATA_B(ram_rd_data), // Read data port B
    .RPARITY_B(ram_rd_parity) // Read parity port B
  );
