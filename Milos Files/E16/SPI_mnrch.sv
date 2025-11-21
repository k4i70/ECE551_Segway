module SPI_mnrch ( 
    input logic clk,
    input logic rst_n,
    input logic wrt,
    input logic [15:0] wt_data,
    output logic MOSI,
    input logic MISO,
    output logic SCLK,
    output logic SS_n,
    output logic [15:0] rd_data,
    output logic done
);
    typedef enum logic [1:0] {
        IDLE,
        FRONT_PORCH,
        TRANSFER,
        BACK_PORCH
    } state_t;

    state_t current_state, next_state;
    logic [3:0] bit_count;
    logic [15:0] shft_reg;
    logic shft_im;
    logic smpl;
    logic [3:0] clk_div;
    logic ld_SCLK;
    logic miso_smpl;
    logic set_done;
    logic init;
    logic done_15;
    logic shift;
    logic smpl_im;

    always @(posedge clk) begin
        clk_div <= ld_SCLK ? 4'b1011 : clk_div + 4'b0001;
    end

    assign SCLK = clk_div[3];
    assign shft_im = (clk_div == 4'b1111);
    assign smpl_im = (clk_div == 4'b0111);

    // MISO sampling
    always @(posedge clk) begin
        miso_smpl <= (smpl_im) ? MISO : miso_smpl;
    end

    // shift register logic
    always @(posedge clk) begin
        if(init) begin
            shft_reg <= wt_data;
        end else if(shift && current_state != FRONT_PORCH) begin
            shft_reg <= {shft_reg[14:0], miso_smpl};
        end else begin
            shft_reg <= shft_reg;
        end
    end

    assign MOSI = shft_reg[15];

    // state transition logic
    always_ff @(posedge clk or negedge rst_n) begin
        if(!rst_n) begin
            current_state <= IDLE;
        end else begin
            current_state <= next_state;
        end
    end

    // bit counter logic
    always_ff @(posedge clk) begin
        if(init) begin
            bit_count <= 4'b0000;
        end else if(shift && current_state != FRONT_PORCH) begin
            bit_count <= bit_count + 4'b0001;
        end else begin
            bit_count <= bit_count;
        end
    end

    assign done_15 = &bit_count;

    // done signal logic
    always_ff @(posedge clk or negedge rst_n) begin
        if(!rst_n) begin
            done <= 1'b0;
        end else if(init) begin
            done <= 1'b0;
        end else if(set_done) begin
            done <= 1'b1;
        end
    end

    always_ff @(posedge clk or negedge rst_n) begin
        if(!rst_n) begin
            SS_n <= 1'b1;
        end else if(init) begin
            SS_n <= 1'b0;
        end else if(set_done) begin
            SS_n <= 1'b1;
        end
    end


    // next state logic
    //first do not shift the shift register until after the first fall of SCLK
    //shift register on the rising edge of SS_n
    always_comb begin
        next_state = current_state;
        ld_SCLK = 1'b0;
        set_done = 1'b0;
        init = 1'b0;
        shift = 1'b0;
        case(current_state)
            IDLE: begin
                ld_SCLK = 1'b1;
                if(wrt) begin
                    init = 1'b1;
                    next_state = FRONT_PORCH;
                end else begin
                    next_state = IDLE;
                end
            end
            FRONT_PORCH: begin
                if(shft_im) begin
                    next_state = TRANSFER;
                end else begin
                    next_state = FRONT_PORCH;
                end
            end
            TRANSFER: begin
                if(bit_count == 4'b1111) begin
                    next_state = BACK_PORCH;
                end else if(shft_im) begin
                    shift = 1'b1;
                end else begin
                    next_state = TRANSFER;
                end
            end
            BACK_PORCH: begin
                if(shft_im) begin
                    shift = 1'b1;
                    set_done = 1'b1;
                    ld_SCLK = 1'b1;
                    next_state = IDLE;
                end else begin
                    next_state = BACK_PORCH;
                end
            end
            default: next_state = IDLE;
        endcase
    end

    // read data logic
    always_ff @(posedge clk or negedge rst_n) begin
        if(!rst_n) begin
            rd_data <= 16'b0;
        end else if(done_15 && shft_im) begin
            rd_data <= shft_reg;
        end
    end
endmodule