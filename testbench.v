module testbench();
  reg clk, rst;

  cpu cpu(
    .clk(clk),
    .rst(rst)
  );

  always #5 begin
    clk <= ~clk;
  end
  
  task wait_posedge_clk;
    input n;
    integer n;

    begin
      for (n=n; n>0; n=n-1) begin
        @(posedge clk)
          ;
      end
    end
  endtask


  initial begin
    clk <= 1'b0;
    rst <= 1'b1;
    wait_posedge_clk(2);
    rst <= 1'b0;
    wait_posedge_clk(2);
    rst <= 1'b1;
    wait_posedge_clk(10);
    wait_posedge_clk(10000000000);
    $finish;    
  end

endmodule
