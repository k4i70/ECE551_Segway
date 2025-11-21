//testbench for arith.sv
module arith_tb ();
    logic [7:0] A;
    logic [7:0] B;
    logic SUB;
    logic [7:0] SUM;
    logic OV;

    arith iDUT (
        .A(A),
        .B(B),
        .SUB(SUB),
        .SUM(SUM),
        .OV(OV)
    );
    initial begin
        
        A = 8'b00000000; B = 8'b00000000; SUB = 1'b0; #10; 
        if (SUM != 8'b00000000) begin $display("Error 0 + 0 != %d", SUM); end 
        if (OV != 0) begin $display("Error OV != 0"); end //0 + 0 = 0, OV=0

        A = 8'b01111111; B = 8'b00000001; SUB = 1'b0; #10; 
        if (SUM != 8'b10000000) begin $display("Error 127 + 1 != %d", SUM); end 
        if (OV != 1) begin $display("Error OV != 1"); end //127 + 1 = -128, OV=1

        A = 8'b01111111; B = 8'b00000010; SUB = 1'b0; #10; 
        if (SUM != 8'b10000001) begin $display("Error 127 + 2 != %d", SUM); end 
        if (OV != 1) begin $display("Error OV != 1"); end //127 + 2 = -127, OV=1

        A = 8'b10000000; B = 8'b11111111; SUB = 1'b0; #10; 
        if (SUM != 8'b01111111) begin $display("Error -128 + -1 != %d", SUM); end 
        if (OV != 1) begin $display("Error OV != 1"); end //-128 + -1 = 127, OV=1

        A = 8'b10000000; B = 8'b11111110; SUB = 1'b0; #10; 
        if (SUM != 8'b01111110) begin $display("Error -128 + -2 != %d", SUM); end 
        if (OV != 1) begin $display("Error OV != 1"); end //-128 + -2 = 126, OV=1

        A = 8'b01111111; B = 8'b00000001; SUB = 1'b1; #10; 
        if (SUM != 8'b01111110) begin $display("Error 127 - 1 != %d", SUM); end 
        if (OV != 0) begin $display("Error OV != 0"); end //127 - 1 = 126, OV=0

        A = 8'b01111111; B = 8'b10000000; SUB = 1'b1; #10; 
        if (SUM != 8'b11111111) begin $display("Error 127 - -128 != %d", SUM); end 
        if (OV != 1) begin $display("Error OV != 1"); end //127 - -128 = -1, OV=1

        A = 8'b10000000; B = 8'b11111111; SUB = 1'b1; #10; 
        if (SUM != 8'b10000001) begin $display("Error -128 - -1 != %d", SUM); end 
        if (OV != 0) begin $display("Error OV != 0"); end //-128 - -1 = -127, OV=0

        A = 8'b10000000; B = 8'b00000001; SUB = 1'b1; #10; 
        if (SUM != 8'b01111111) begin $display("Error -128 - 1 != %d", SUM); end 
        if (OV != 1) begin $display("Error OV != 1"); end //-128 - 1 = 127, OV=1

        A = 8'b10000000; B = 8'b00000010; SUB = 1'b1; #10; 
        if (SUM != 8'b01111110) begin $display("Error -128 - 2 != %d", SUM); end 
        if (OV != 1) begin $display("Error OV != 1"); end //-128 - 2 = 126, OV=1

        $stop;
    end
    
endmodule