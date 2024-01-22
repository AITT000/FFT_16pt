/******************************************************************************
Copyright (c) 2022 SoC Design Laboratory, Konkuk University, South Korea
All rights reserved.

Redistribution and use in source and binary forms, with or without
modification, are permitted provided that the following conditions are
met: redistributions of source code must retain the above copyright
notice, this list of conditions and the following disclaimer;
redistributions in binary form must reproduce the above copyright
notice, this list of conditions and the following disclaimer in the
documentation and/or other materials provided with the distribution;
neither the name of the copyright holders nor the names of its
contributors may be used to endorse or promote products derived from
this software without specific prior written permission.

THIS SOFTWARE IS PROVIDED BY THE COPYRIGHT HOLDERS AND CONTRIBUTORS
"AS IS" AND ANY EXPRESS OR IMPLIED WARRANTIES, INCLUDING, BUT NOT
LIMITED TO, THE IMPLIED WARRANTIES OF MERCHANTABILITY AND FITNESS FOR
A PARTICULAR PURPOSE ARE DISCLAIMED. IN NO EVENT SHALL THE COPYRIGHT
OWNER OR CONTRIBUTORS BE LIABLE FOR ANY DIRECT, INDIRECT, INCIDENTAL,
SPECIAL, EXEMPLARY, OR CONSEQUENTIAL DAMAGES (INCLUDING, BUT NOT
LIMITED TO, PROCUREMENT OF SUBSTITUTE GOODS OR SERVICES; LOSS OF USE,
DATA, OR PROFITS; OR BUSINESS INTERRUPTION) HOWEVER CAUSED AND ON ANY
THEORY OF LIABILITY, WHETHER IN CONTRACT, STRICT LIABILITY, OR TORT
(INCLUDING NEGLIGENCE OR OTHERWISE) ARISING IN ANY WAY OUT OF THE USE
OF THIS SOFTWARE, EVEN IF ADVISED OF THE POSSIBILITY OF SUCH DAMAGE.

Authors: Uyong Lee (uyonglee@konkuk.ac.kr)

Revision History
2022.11.17: Started by Uyong Lee
*******************************************************************************/
`timescale 1ns / 1ps

module tb_Top_FFT;

//Top_FFT Input Declaration//
reg clk, nrst, in_vld, out_rdy;
reg [11:0] cnt_tlast; // 16 x 256(set) 
wire in_rdy, out_vld;
wire [31:0] ext_data_input;
wire [31:0] ext_data_output;
wire m_axis_tlast;


//Clock Generator//
parameter CLK_PERIOD = 10; //100MHz
initial begin
    clk = 1'b1;
    forever
    #(CLK_PERIOD/2) clk = ~clk;
end


initial begin
    nrst =1'b0;
    in_vld = 1'b1;
    out_rdy= 1'b1;
    #(0.5*CLK_PERIOD) nrst =1'b1;
end

//Data Input Count//
integer data_cnt;
initial begin
    data_cnt = 0;
end

always @(posedge clk) begin
    if(in_rdy && in_vld) data_cnt = data_cnt +1;
end

//Testbench Data Input//
parameter INFILE =  "RTLin.txt"; //Set your input file path
reg [31:0] txt_data_in[4096:0];
initial begin
    $readmemh(INFILE, txt_data_in);
end
            
               
always @(posedge clk) begin
    if(!nrst) begin
        cnt_tlast <= 0;
    end
    else if(out_rdy && out_vld) begin
        if(cnt_tlast == 4095) cnt_tlast <= 0;
        else cnt_tlast <= cnt_tlast + 1;
    end
    else cnt_tlast <= cnt_tlast;  

end

assign m_axis_tlast = (cnt_tlast==4095) ? 1'b1 : 1'b0 ; //Final output cycle in last set


assign ext_data_input = (in_rdy) ? ( (data_cnt <= -2) ? 0: ((data_cnt>4097) ? 0: txt_data_in[data_cnt])) : 0;


//Top_FFT Instantiation//
TopFFT TopFFT(
                .clk(clk),
                .nrst(nrst),
                .in_vld(in_vld),
                .out_rdy(out_rdy), 
                .ext_data_input(ext_data_input),
                .in_rdy(in_rdy),
                .out_vld(out_vld),
		        .ext_data_output(ext_data_output)
                );

parameter W = 50;
        
reg [W:0] output_re[4096:0];
reg [W:0] output_im[4096:0];

integer out_cnt;

initial begin 
    out_cnt = 0;
end


always @ (posedge clk) begin
    if(out_vld&&out_rdy) begin
        output_im[out_cnt] = ext_data_output[31:16];
        output_re[out_cnt] = ext_data_output[15:0];
        out_cnt = out_cnt+1;
    end   
end

//Testbench Reference Output//
parameter COMPFILE =  "RTLout_ref.txt"; //Set your reference file path
reg [W:0] txt_compare[8192:0];
reg [W:0] Temp;
reg [W:0] Noise;
reg [W:0] Signal;


initial begin
    $readmemh(COMPFILE, txt_compare);
end

real Result;
initial begin
    Result =0.0;    
end


integer dumpfile, i;
initial begin
Noise<=0;
Signal <=0;
  #(20000*CLK_PERIOD) ;
  //Testbench Output//
  dumpfile = $fopen("RTLout.txt","w"); //Set the output file path you want to save
  for(i = 0; i<4096;i=i+1)begin
  $fwrite(dumpfile,"%4h\n",output_re[i]);
  $fwrite(dumpfile,"%4h\n",output_im[i]);
  Noise= Noise+((output_re[i]-txt_compare[2*i])*(output_re[i]-txt_compare[2*i]))+((output_im[i]-txt_compare[(2*i)+1])*(output_im[i]-txt_compare[(2*i)+1]));
  $display ("signal : %h \n", Signal);
  Temp = (output_re[i]*output_re[i]) + (output_im[i]*output_im[i]);   
  Signal = Signal + Temp;
  $display ("%d : signal : %h Temp : %h\n",i, Signal, Temp);
  
  end  
  $fclose(dumpfile);
  $display("\nnoise : %h-dec : %d, signal : %h-dec : %d\n",Noise,Noise, Signal,Signal);
  $display("\nDivided : %7.20f\n",$bitstoreal(Noise)/$bitstoreal(Signal));
  
  
  Result = 10 * $log10($bitstoreal(Noise)/$bitstoreal(Signal));
   $display("NSR : %f",Result);
  end

            
endmodule
