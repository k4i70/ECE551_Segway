//structurally modeled D flip-flop without reset
module  MSFF  (input d, clk, output q);
    //d: data input
    //clk: clock input
    //q: output
//flip flop using tri-states and not gates
wire md, sd;
logic mq, clk_n;
not clk_nt(clk_n, clk);
notif1 #(1) tris1(md, d, clk_n);
notif1 #(1) tris2(sd, mq, clk);
not not1(mq, md);
not (weak0, weak1) not2(md, mq);
not (weak0, weak1) not3(sd, q);
not not4(q, sd);
endmodule
