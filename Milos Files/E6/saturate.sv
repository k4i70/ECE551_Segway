module saturate (input logic [15:0] unsigned_err,
                  input logic [15:0] signed_err,
                  input logic [9:0] signed_D_diff,
                  output logic [9:0] unsigned_err_sat,
                  output logic [9:0] signed_err_sat,
                  output logic [6:0] signed_D_diff_sat);

//if any bits above the 10th bit are set, saturate to max value
assign unsigned_err_sat = (|unsigned_err[15:10]) ? 10'h3FF : unsigned_err[9:0];
//because of sign, need to check 10th bit as well
assign signed_err_sat = (|signed_err[15:9] & ~&signed_err[15:9]) ? (signed_err[15] ? 10'h200 : 10'h1FF) : signed_err[9:0];
//beccause of sign, need to check 7th bit as well
assign signed_D_diff_sat = (|signed_D_diff[9:6] & ~&signed_D_diff[9:6]) ? (signed_D_diff[9] ? 7'h40 : 7'h3F) : signed_D_diff[6:0];
endmodule