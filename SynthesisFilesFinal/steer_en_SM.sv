`timescale 1ns/1ps
module steer_en_SM(clk,rst_n,tmr_full,sum_gt_min,sum_lt_min,diff_gt_1_4,
                   diff_gt_15_16,clr_tmr,en_steer,rider_off);

  input clk;				// 50MHz clock
  input rst_n;				// Active low asynch reset
  input tmr_full;			// asserted when timer reaches 1.3 sec
  input sum_gt_min;			// asserted when left and right load cells together exceed min rider weight
  input sum_lt_min;			// asserted when left_and right load cells are less than min_rider_weight

  /////////////////////////////////////////////////////////////////////////////
  // HEY HOFFMAN...you are a moron.  sum_gt_min would simply be ~sum_lt_min. 
  // Why have both signals coming to this unit??  ANSWER: What if we had a rider
  // (a child) who's weigth was right at the threshold of MIN_RIDER_WEIGHT?
  // We would enable steering and then disable steering then enable it again,
  // ...  We would make that child crash(children are light and flexible and 
  // resilient so we don't care about them, but it might damage our Segway).
  // We can solve this issue by adding hysteresis.  So sum_gt_min is asserted
  // when the sum of the load cells exceeds MIN_RIDER_WEIGHT + HYSTERESIS and
  // sum_lt_min is asserted when the sum of the load cells is less than
  // MIN_RIDER_WEIGHT - HYSTERESIS.  Now we have noise rejection for a rider
  // who's weight is right at the threshold.  This hysteresis trick is as old
  // as the hills, but very handy...remember it.
  //////////////////////////////////////////////////////////////////////////// 

  input diff_gt_1_4;		// asserted if load cell difference exceeds 1/4 sum (rider not situated)
  input diff_gt_15_16;		// asserted if load cell difference is great (rider stepping off)
  output logic clr_tmr;		// clears the 1.3sec timer
  output logic en_steer;	// enables steering (goes to balance_cntrl)
  output logic rider_off;	// held high in intitial state when waiting for sum_gt_min
  
  // You fill out the rest...use good SM coding practices ///


  // State declarations
  typedef enum logic [1:0] {
    IDLE = 2'b00,
    WAIT_STEADY = 2'b01,
    STEERING = 2'b10
  } state_t;

  state_t state, next_state;



  always_ff @(posedge clk or negedge rst_n) begin
    if (!rst_n) begin
      state <= IDLE;
    end else begin
      state <= next_state;
    end
  end

  always_comb begin
    // Default outputs
    clr_tmr = 1'b0;
    en_steer = 1'b0;
    rider_off = 1'b1;
    next_state = state;
    
    case (state)
      IDLE: begin
        if (sum_gt_min) begin
          next_state = WAIT_STEADY;
          clr_tmr = 1'b1; // Start the timer when transitioning to WAIT_STEADY
        end
      end
      
      WAIT_STEADY: begin
        rider_off = 1'b0;
        if (diff_gt_1_4) begin
          clr_tmr = 1'b1; // Keep clearing timer while rider is not balanced
        end
        if (tmr_full && !diff_gt_1_4) begin
          next_state = STEERING;
          en_steer = 1'b1; // Enable steering when transitioning to STEERING
        end else if (sum_lt_min) begin
          next_state = IDLE;
          clr_tmr = 1'b1; // Clear the timer when going back to IDLE
        end
        // Note: diff_gt_15_16 alone should not cause transition to IDLE from WAIT_STEADY
        // Only sum_lt_min should cause transition to IDLE
      end
      
      STEERING: begin
        rider_off = 1'b0;
        en_steer = 1'b1; // Keep steering enabled in STEERING state
        if (sum_lt_min) begin
          next_state = IDLE;
          clr_tmr = 1'b1; // Clear the timer when going back to IDLE
        end else if (diff_gt_15_16) begin
          next_state = WAIT_STEADY;
          clr_tmr = 1'b1; // Clear the timer when going back to WAIT_STEADY
        end
        // Note: diff_gt_1_4 should not cause transition back to WAIT_STEADY
        // Only sum_lt_min goes to IDLE, diff_gt_15_16 goes to WAIT_STEADY
      end
      
      default: begin
        next_state = IDLE;
      end

    endcase
  end
  
  
endmodule