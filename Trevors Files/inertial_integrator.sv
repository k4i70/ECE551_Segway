// Team Name: iSPI
module inertial_integrator(
    input clk,
    input rst_n,
    input vld,                  // High for a single clock cycle when new inertial readings are valid
    input signed [15:0] ptch_rt,// 16-bit signed raw pitch rate from inertial sensor
    input [15:0] AZ,           // Will be used for sensor fusion (acceleration in Z direction)
    output signed [15:0] ptch  // Fully compensated and "fused" 16-bit signed pitch
);

// Localparams
localparam PITCH_RT_OFFSET = 16'h0050;  // Offset for pitch rate compensation
localparam AZ_OFFSET = 16'h00A0;        // Offset for AZ compensation

// Internal registers and wires
reg signed [26:0] ptch_int;             // Pitch integrating accumulator (27-bit)
wire signed [15:0] ptch_rt_comp;        // Compensated pitch rate
wire signed [15:0] AZ_comp;             // Compensated AZ
wire signed [25:0] ptch_acc_product;    // Intermediate product for pitch from accel
wire signed [15:0] ptch_acc;            // Pitch angle calculated from accel only
wire signed [26:0] fusion_ptch_offset;  // Fusion offset term (27-bit)

// Compensate pitch rate and AZ readings
assign ptch_rt_comp = ptch_rt - PITCH_RT_OFFSET;
assign AZ_comp = AZ - AZ_OFFSET;

// Calculate pitch from accelerometer
assign ptch_acc_product = AZ_comp * $signed(327); // 327 is fudge factor
assign ptch_acc = {{3{ptch_acc_product[25]}}, ptch_acc_product[25:13]}; // pitch angle calculated from accel only

// Determine fusion offset
assign fusion_ptch_offset = (ptch_acc > ptch) ? 27'sd1024 : -27'sd1024;

// Output the upper 16 bits of the integrator (bits [26:11])
assign ptch = ptch_int[26:11];

// Main integration process
always_ff @(posedge clk or negedge rst_n) begin
    if (!rst_n) begin
        ptch_int <= 27'sd0;
    end else if (vld) begin
        // Integrate: ptch_int = ptch_int - ptch_rt_comp + fusion_ptch_offset
        ptch_int <= ptch_int - {{11{ptch_rt_comp[15]}}, ptch_rt_comp} + fusion_ptch_offset;
    end
end

endmodule
