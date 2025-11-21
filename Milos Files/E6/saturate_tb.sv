//self checking testbench for saturate.sv

module saturate_tb ();
logic [15:0] unsigned_err;
logic [15:0] signed_err;
logic [9:0] signed_D_diff;
logic [9:0] unsigned_err_sat;
logic [9:0] signed_err_sat;
logic [6:0] signed_D_diff_sat;

saturate iDUT (
    .unsigned_err(unsigned_err),
    .signed_err(signed_err),
    .signed_D_diff(signed_D_diff),
    .unsigned_err_sat(unsigned_err_sat),
    .signed_err_sat(signed_err_sat),
    .signed_D_diff_sat(signed_D_diff_sat)
);

//test cases
initial begin
    //unsigned_err test cases
    unsigned_err = 16'h0000; #10; //expect 000
    assert(unsigned_err_sat === 10'h000) else $error("Test case 1 failed: unsigned_err=0x%h, unsigned_err_sat=0x%h", unsigned_err, unsigned_err_sat);

    unsigned_err = 16'h00FF; #10; //expect 0FF
    assert(unsigned_err_sat === 10'h0FF) else $error("Test case 2 failed: unsigned_err=0x%h, unsigned_err_sat=0x%h", unsigned_err, unsigned_err_sat);

    unsigned_err = 16'h03FF; #10; //expect 3FF
    assert(unsigned_err_sat === 10'h3FF) else $error("Test case 3 failed: unsigned_err=0x%h, unsigned_err_sat=0x%h", unsigned_err, unsigned_err_sat);

    unsigned_err = 16'h0400; #10; //expect 3FF (saturated)
    assert(unsigned_err_sat === 10'h3FF) else $error("Test case 4 failed: unsigned_err=0x%h, unsigned_err_sat=0x%h", unsigned_err, unsigned_err_sat);

    unsigned_err = 16'hFFFF; #10; //expect 3FF (saturated)
    assert(unsigned_err_sat === 10'h3FF) else $error("Test case 5 failed: unsigned_err=0x%h, unsigned_err_sat=0x%h", unsigned_err, unsigned_err_sat);

    //signed_err test cases
    signed_err = 16'h0000; #10; //expect 000
    assert(signed_err_sat === 10'h000) else $error("Test case 6 failed: signed_err=0x%h, signed_err_sat=0x%h", signed_err, signed_err_sat);

    signed_err = 16'h007F; #10; //expect 07F
    assert(signed_err_sat === 10'h07F) else $error("Test case 7 failed: signed_err=0x%h, signed_err_sat=0x%h", signed_err, signed_err_sat);

    signed_err = 16'h01FF; #10; //expect 1FF
    assert(signed_err_sat === 10'h1FF) else $error("Test case 8 failed: signed_err=0x%h, signed_err_sat=0x%h", signed_err, signed_err_sat);

    signed_err = 16'h0200; #10; //expect 1FF (saturated)
    assert(signed_err_sat === 10'h1FF) else $error("Test case 9 failed: signed_err=0x%h, signed_err_sat=0x%h", signed_err, signed_err_sat);

    signed_err = 16'hFE00; #10; //expect 200 (saturated)
    assert(signed_err_sat === 10'h200) else $error("Test case 10 failed: signed_err=0x%h, signed_err_sat=0x%h", signed_err, signed_err_sat);

    signed_err = 16'hFFFF; #10; //expect 3FF (not saturated because it's -1)
    assert(signed_err_sat === 10'h3FF) else $error("Test case 11 failed: signed_err=0x%h, signed_err_sat=0x%h", signed_err, signed_err_sat);    

    //signed_D_diff test cases
    signed_D_diff = 10'h000; #10; //expect 000
    assert(signed_D_diff_sat === 7'h00) else $error("Test case 12 failed: signed_D_diff=0x%h, signed_D_diff_sat=0x%h", signed_D_diff, signed_D_diff_sat);

    signed_D_diff = 10'h03F; #10; //expect 03F
    assert(signed_D_diff_sat === 7'h3F) else $error("Test case 13 failed: signed_D_diff=0x%h, signed_D_diff_sat=0x%h", signed_D_diff, signed_D_diff_sat);

    signed_D_diff = 10'h07F; #10; //expect 3F (saturated)
    assert(signed_D_diff_sat === 7'h3F) else $error("Test case 14 failed: signed_D_diff=0x%h, signed_D_diff_sat=0x%h", signed_D_diff, signed_D_diff_sat);

    signed_D_diff = 10'h0C0; #10; //expect 3F (most positive saturated)
    assert(signed_D_diff_sat === 7'h3F) else $error("Test case 15 failed: signed_D_diff=0x%h, signed_D_diff_sat=0x%h", signed_D_diff, signed_D_diff_sat);

    signed_D_diff = 10'h3FF; #10; //expect 7F (negative one)
    assert(signed_D_diff_sat === 7'h7F) else $error("Test case  16 failed: signed_D_diff=0x%h, signed_D_diff_sat=0x%h", signed_D_diff, signed_D_diff_sat);
end

endmodule