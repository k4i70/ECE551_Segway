module SPI_mnrch (
    input logic clk,
    input logic rst_n,
    output logic SS_n, SCLK, MOSI,
    input logic MISO,
    input logic wrt, // A high for 1 clock period would initiate a SPI transaction
    input logic [15:0] wrt_data, // Data (command) being sent to inertial sensor
    output logic done, // Asserted when SPI transaction is complete, stay asserted until next wrt
    output logic [15:0] rd_data // Data from SPI serf. For intertial sensor we will ever use [7:0]
);

    // State encoding
    typedef enum logic [1:0] {
        // 4 states
        IDLE, FRONT_PORCH, MAIN, BACK_PORCH
    } state_t;

    state_t current_state, next_state;

    // Control signals used throughout the module
    logic init;           // Initialize shift register and bit counter
    logic set_done;       // Set done signal and deactivate SS_n
    logic MISO_smpl;      // Sampled MISO signal
    logic done15;         // All 16 bits have been shifted
    logic shft;         // Shift signal for shift register
    logic smpl_im;      // Sample MISO imminent signal

    /* SCLK Generation */
    // SCLK frequency will be 1/16 of the 50mHz clk.
    // Clock divider for SCLK generation
    // When SCLK is loaded, it will be held at 4'b1011. 
    logic [3:0] SCLK_div;
    logic ld_SCLK; // Load SCLK hold value signal
    always_ff @(posedge clk or negedge rst_n) begin
        if (!rst_n)
            SCLK_div <= 4'd0;
        else if (ld_SCLK)
            SCLK_div <= 4'b1011; // Load SCLK hold value
        else
            SCLK_div <= SCLK_div + 1'b1;
    end
    // SCLK generation
    assign SCLK = SCLK_div[3]; // MSB of counter is SCLK
    // Decode SCLK value to smpl signal and shift_im pulse to signify a shift is imminent.
    logic smpl;
    logic shift_im;
    always_comb begin
        smpl_im = 1'b0;
        shift_im = 1'b0;
        if (SCLK_div == 4'b0111)
            smpl_im = 1'b1;
        if (SCLK_div == 4'b1111)
            shift_im = 1'b1;
    end




    /* Shift Register Logic */
    // Creating 16 bit shift register that can load data from MISO and send data out to MOSI
    logic [15:0] shift_reg;
    // The bit coming from the serf (MISO) is sampled on the rise of SCLK, and then put into our shift register on the fall of SCLK.
    // MSB is MOSI[15], LSB is MISO[0].
    // Shift register logic
    // Use clk edges for FFs for efficiency, but still use SCLK for timing
    always_ff @(posedge clk or negedge rst_n) begin
        if (!rst_n)
            shift_reg <= 16'b0;
        else if (init) begin
            shift_reg <= wrt_data; // Load data to be sent into shift register
        end
        else if (shft) begin
            shift_reg <= {shift_reg[14:0], MISO_smpl}; // Shift left, bring in sampled MISO bit
        end else begin
            shift_reg <= shift_reg; // Hold value
        end
    end
    // MOSI is always the MSB of the shift register
    assign MOSI = shift_reg[15];




    /* smpl Block */
    // smpl signal determins when MISO is sampled into shift register
    // Otherwise MISO_smpl is ignored. 
    always_ff @(posedge clk or negedge rst_n) begin
        if (!rst_n)
            MISO_smpl <= 1'b0;
        else if (smpl)
            MISO_smpl <= MISO;
        else
            MISO_smpl <= MISO_smpl; // Hold value
    end
    



    /* Bit_cntr logic */
    // We can use the shft signal to count the number of bits shifted
    // We can set to 0 when init is high
    // Count up to 16 bits
    logic [3:0] bit_cntr; // 4 bits to count to
    always_ff @(posedge clk or negedge rst_n) begin
        if (!rst_n)
            bit_cntr <= 4'd0;
        else if (init)
            bit_cntr <= 4'd0;
        else if (shft)
            bit_cntr <= bit_cntr + 1'b1;
        else 
            bit_cntr <= bit_cntr; // Hold value
    end
    assign done15 = &bit_cntr; // done15 when all 16 bits have been shifted


    /* rd_data Logic */
    // rd_data is the content of the shift register after all bits have been shifted
    always_ff @(posedge clk or negedge rst_n) begin
        if (!rst_n)
            rd_data <= 16'd0;
        else if (set_done)
            rd_data <= shift_reg; // Capture shifted data when done
        else
            rd_data <= rd_data; // Hold value
    end    


    /* SS_n Logic */
    // SS_n is low when not in IDLE state
    always_ff @(posedge clk or negedge rst_n) begin
        if (!rst_n)
            SS_n <= 1'b1; // SS_n inactive
        else if (init)
            SS_n <= 1'b0;
        else if (set_done)
            SS_n <= 1'b1;
        else
            SS_n <= SS_n; // Hold value
    end


    /* done Logic */
    always_ff @(posedge clk or negedge rst_n) begin
        if (!rst_n)
            done <= 1'b0;
        else if (init) // Clear done when new wrt starts
            done <= 1'b0;   
        else if (set_done)
            done <= 1'b1;
        else
            done <= done; // Hold value
    end


    /* State Machine Logic */
    // State transition logic
    always_ff @(posedge clk or negedge rst_n) begin
        if (!rst_n)
            current_state <= IDLE;
        else
            current_state <= next_state;
    end

    // State machine combinational logic
    always_comb begin
        // Default assignments
        next_state = current_state;
        ld_SCLK = 1'b1; // Default SCLK value to be held high. 
        init = 1'b0; // Init decides when wrt_data is shifted in. 
        set_done = 1'b0;
        shft = 1'b0;

        case (current_state)
            IDLE: begin
                ld_SCLK = 1'b1; // Load SCLK hold value to keep SCLK high
                if (wrt) begin
                    next_state = FRONT_PORCH;
                    init = 1'b1; // Initialize shift register and bit counter
                end
            end

            FRONT_PORCH: begin
                ld_SCLK = 1'b0; // Allow counter to run and generate SCL
                if (SCLK == 1'b0) // Wait for SCLK falling edge
                    next_state = MAIN;
            end

            MAIN: begin
                ld_SCLK = 1'b0; // Keep counter running to generate SCLK
                // Send shft signal and smpl signal based on imminent signals
                // Send shift after shift_im is asserted. 
                if (shift_im)
                    shft = 1'b1;
                if (smpl_im)
                    smpl = 1'b1;
                if (done15 && shift_im) begin // All bits shifted, wait for last shift to complete
                    next_state = BACK_PORCH;
                    ld_SCLK = 1'b1; // Stop SCLK counter immediately when transitioning
                end
            end

            BACK_PORCH: begin
                ld_SCLK = 1'b1; // Load SCLK hold value to stop counter and keep SCLK high
                set_done = 1'b1; // Set done signal and deactivate SS_n
                next_state = IDLE;
            end

            default: next_state = IDLE;
        endcase
    end


endmodule
