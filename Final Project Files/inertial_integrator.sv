module inertial_integrator(
    input clk,                    // system clock
    input rst_n,                  // active low reset
    input vld,                    // High for a single clock cycle when new inertial readings are valid
    input signed [15:0] ptch_rt,  // 16-bit signed raw pitch rate from inertial sensor
    input signed [15:0] AZ,       // Will be used for sensor fusion (acceleration in Z direction)
    output signed [15:0] ptch     // Fully compensated and "fused" 16-bit signed pitch
);

    // Local parameters
    localparam PTCH_RT_OFFSET = 16'h0050;  // Offset for pitch rate compensation
    localparam AZ_OFFSET = 16'h00A0;       // Offset for AZ compensation
    
    // Internal registers
    reg signed [26:0] ptch_int;            // pitch integrator (27-bit for headroom)
    
    // Internal signals
    wire signed [15:0] ptch_rt_comp;       // compensated pitch rate
    wire signed [15:0] AZ_comp;            // compensated AZ
    wire signed [25:0] ptch_acc_product;   // intermediate calculation for pitch from accel
    wire signed [15:0] ptch_acc;           // pitch angle calculated from accel only
    wire signed [26:0] fusion_ptch_offset; // fusion correction term
    wire signed [26:0] ptch_rt_comp_ext;   // sign-extended ptch_rt_comp
    
    // Compensate raw pitch rate
    assign ptch_rt_comp = ptch_rt - PTCH_RT_OFFSET;
    
    // Compensate AZ
    assign AZ_comp = AZ - AZ_OFFSET;
    
    // Calculate pitch from accelerometer
    assign ptch_acc_product = AZ_comp * $signed(327);  // 327 is fudge factor
    assign ptch_acc = {{3{ptch_acc_product[25]}}, ptch_acc_product[25:13]};  // pitch angle calculated from accel only
    
    // Sign extend ptch_rt_comp to 27 bits
    assign ptch_rt_comp_ext = {{11{ptch_rt_comp[15]}}, ptch_rt_comp};
    
    // Fusion offset calculation
    assign fusion_ptch_offset = (ptch_acc > ptch) ? 27'sd1024 : 
                               (ptch_acc < ptch) ? -27'sd1024 : 27'sd0;
    
    // Pitch integrator update - only on valid readings
    always_ff @(posedge clk, negedge rst_n) begin
        if (!rst_n) begin
            ptch_int <= 27'sd0;
        end else if (vld) begin
            ptch_int <= ptch_int - ptch_rt_comp_ext + fusion_ptch_offset;
        end
    end
    
    // Output the upper 16 bits of the integrator (divide by 2^11 = 2048)
    assign ptch = ptch_int[26:11];

endmodule