module piezo_drv_tb;
//testbench signals
reg clk;
reg RST_n;
reg en_steer;
reg too_fast;
reg batt_low;
wire piezo;
wire piezo_n;


//instantiate the piezo driver
piezo_drv #(1) DUT(.clk(clk),.rst_n(RST_n),.en_steer(en_steer),
                   .too_fast(too_fast), .batt_low(batt_low),
                   .piezo(piezo),.piezo_n(piezo_n));

//clock generation
initial begin
    clk = 0;
    forever #10 clk = ~clk; // 50MHz clock
end
//test sequence
initial begin
    rst_n = 0;
    en_steer = 0;
    too_fast = 0;
    batt_low = 0;
    repeat (2) @(posedge clk);
    rst_n = 1;
    repeat (10) @(posedge clk);
    en_steer = 1; // enable steering sound
    repeat (300) @(posedge clk);
    en_steer = 0;
    too_fast = 1; // enable too fast sound
    repeat (300) @(posedge clk);
    too_fast = 0;   
    batt_low = 1; // enable low battery sound
    repeat (300) @(posedge clk);
    batt_low = 0;
    repeat (50) @(posedge clk);


    //too fast should take priority over batt_low which takes priority over en_steer
    //lets test that
    en_steer = 1;
    batt_low = 1;                   
    repeat (100) @(posedge clk);    //en_steer and batt_low active, batt_low should play
    en_steer = 0;
    too_fast = 1;            
    repeat (100) @(posedge clk); //too_fast and batt_low active, too_fast should play
    batt_low = 0;           
    en_steer = 1;               
    repeat (100) @(posedge clk);    //too_fast and en_steer active, too_fast should play
    batt_low = 1;       
    repeat (100) @(posedge clk);  //all three active, too_fast should play


    $stop; // end of simulation
end
endmodule