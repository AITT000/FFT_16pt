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
module controller(
        input 		    clk, nrst, in_vld, out_rdy,
        output wire 	in_rdy, out_vld,
	    output wire	    sel_input,
	    output wire 	sel_res,
        output wire 	sel_mem,
        output wire 	we_AMEM, we_BMEM, we_OMEM,
        output wire 	[3:0] addr_AMEM,
        output wire 	[3:0] addr_BMEM,
        output wire 	[3:0] addr_OMEM,
        output wire 	[2:0] addr_CROM,
        output wire 	en_REG_A,
	    output reg	    en_REG_B, en_REG_C
);

/////////////////////////////////////
/////////// Edit code below!!////////

reg [4:0] cnt, cnt_out;
reg [4:0] cnt_in;
reg [2:0] cstate, nstate, cstate_in, nstate_in, cstate_out, nstate_out;
reg [2:0] cnt_rom;
reg [3:0] buf1, buf2, buf3;
reg [3:0] start_clk;

localparam
	IDLE	= 3'b000,
	STAGE_1	= 3'b001,
	STAGE_2	= 3'b010,
	STAGE_3 = 3'b011,
	STAGE_4	= 3'b100,
	PRE_RUN = 3'b101,
	RUN		= 3'b110;

always @(posedge clk) begin
	if(cstate == IDLE) begin
		start_clk <= start_clk + 1;
	end
end

always@(posedge clk) begin
	if(!nrst) begin
		cnt <= 0;
		cnt_in <= 0;
		cnt_out <= 0;
		cnt_rom <= 0;
		start_clk <= 0;
	end	
	else begin
		if(in_vld == 1'b0 || out_rdy == 1'b0) begin
			cnt <= 0;
		end
		else if(cnt == 18) begin
			cnt <= 0;
		end
		else if(cstate == IDLE) begin
				cnt <= 0;
		end
		else begin
			cnt <= cnt + 1;
		end
	end
end

always @(posedge clk)
begin
    if(!nrst) begin
       cstate		<= IDLE;
	   cstate_in	<= IDLE;
	   cstate_out 	<= IDLE;
	   nstate		<= IDLE;
	   nstate_in	<= IDLE;
	   nstate_out	<= IDLE;
    end
    else begin
       cstate 		<= nstate;
	   cstate_in 	<= nstate_in;
	   cstate_out 	<= nstate_out;
    end
end

///////////////////FSM////////////////////
always @(*) begin
    case(cstate)
		IDLE : begin
			if(cnt_in == 15) begin
			   nstate <= STAGE_1;
			end
		end
		STAGE_1 : begin
			if(cnt == 18) begin
				nstate <= STAGE_2;
			end
			else begin
				nstate <= STAGE_1;
			end
		end
		STAGE_2 : begin
			if(cnt == 18) begin
				nstate <= STAGE_3;
			end
			else begin
				nstate <= STAGE_2;
			end
		end
		STAGE_3 : begin
			if(cnt == 18) begin
				nstate <= STAGE_4;
			end
			else begin
				nstate <= STAGE_3;
			end
		end
		STAGE_4 : begin
			if(cnt == 18 && in_handshake) begin
				nstate <= STAGE_1;	
			end
			else if(cnt == 18 && in_handshake == 0) begin
				nstate <= IDLE;
			end
			else begin
				nstate <= STAGE_4;
			end
		end
		default : nstate <= IDLE;
	endcase
	case(cstate_in)
		IDLE: begin
			if(cstate == IDLE) begin
				nstate_in <= PRE_RUN;
			end
			else if(cstate == STAGE_4 && (cnt >= 2 && cnt <= 17)) begin
				nstate_in <= RUN;
			end
			else begin
				nstate_in <= IDLE;
			end
		end
		PRE_RUN: begin
			if(start_clk == 4'b1111) begin
				nstate_in <= RUN;
			end
			else begin
				nstate_in <= PRE_RUN;
			end
		end
		RUN: begin
			if(cnt_in == 15) begin
				nstate_in <= IDLE;
			end
			else begin
				nstate_in <= RUN;
			end
		end
	endcase
	case(cstate_out)
		IDLE: begin
			if(cstate == STAGE_4 && cnt == 18) begin
				nstate_out <= RUN;
			end
			else begin
				nstate_out <= IDLE;
			end
		end
		RUN: begin
			if(cnt_out == 16) begin
				nstate_out <= IDLE;
			end
			else begin
				nstate_out <= RUN;
			end
		end
	endcase
end


/////////////////manipulate address of rom/////////////////
always @(posedge clk) begin
	case(cstate)
		IDLE: begin
			cnt_rom <= 0;
		end
		STAGE_1: begin
			cnt_rom <= 0;
		end
		STAGE_2: begin
			if(cnt != 0 && cnt[0] == 0 && cnt_rom == 4) begin
				cnt_rom <= 0;
			end
			else if(cnt != 0 && cnt != 18 && cnt[0] == 0) begin
				cnt_rom <= cnt_rom + 4;
			end
			else begin
				cnt_rom <= cnt_rom;
			end
		end
		STAGE_3: begin
			if(cnt != 0 && cnt[0] == 0 && cnt_rom == 6) begin
				cnt_rom <= 0;
			end
			else if(cnt != 0 && cnt != 18 && cnt[0] == 0) begin
				cnt_rom <= cnt_rom + 2;
			end
			else begin
				cnt_rom <= cnt_rom;
			end
		end
		STAGE_4: begin
			if(cnt != 0 && cnt[0] == 0 && cnt_rom == 7) begin
				cnt_rom <= 0;
			end
			else if (cnt != 0 && cnt != 18 && cnt[0] == 0) begin
				cnt_rom <= cnt_rom + 1;
			end
			else begin
				cnt_rom <= cnt_rom;
			end
		end
	endcase
end


always @(posedge clk) begin
	
	case(cstate_in)
		RUN: begin
			if(cnt_in == 15) begin
				cnt_in <= 0;
			end
			else begin
				cnt_in <= cnt_in + 1;
			end
		end
	endcase
	case(cstate_out)
		RUN: begin
			if(cnt_out == 16) begin
				cnt_out <= 0;
			end
			else begin
				cnt_out <= cnt_out + 1;
			end
		end
	endcase
	

	if(!nrst) begin
		en_REG_B <=0;
		en_REG_C <=0;
	end
	else begin
		en_REG_B <= en_REG_A;
		en_REG_C <= en_REG_B;
	end 
end

////buf for holding 3cycles which is wired to addr_AMEM, addr_BMEM, addr_OMEM////////
always @(posedge clk) begin
	case(cstate)
		IDLE: begin
			buf1 <= 0;
			buf2 <= 0;
			buf3 <= 0;
		end
		STAGE_1: begin
			buf1 <= addr_AMEM;
			buf2 <= buf1;
			buf3 <= buf2;
		end
		STAGE_2: begin
			buf1 <= addr_BMEM;
			buf2 <= buf1;
			buf3 <= buf2;
		end
		STAGE_3: begin
			buf1 <= addr_AMEM;
			buf2 <= buf1;
			buf3 <= buf2;
		end
		STAGE_4: begin
			buf1 <= addr_BMEM;
			buf2 <= buf1;
			buf3 <= buf2;
		end
	endcase
end

assign en_REG_A = cnt[0];

assign addr_CROM =  cnt_rom;


assign out_vld = (cstate_out == RUN && cnt >= 1) ? 1 : 0;
assign in_rdy = (cstate_in == RUN && cstate == IDLE || (cstate == STAGE_4 && (cnt >= 3 && cnt <= 18))) ? 1 : 0;
assign sel_input = in_rdy;


assign we_AMEM 	= 	!(cstate_in == RUN || (cstate == STAGE_2 && (cnt >= 3 && cnt <= 18))) ? 1 : 0;
assign we_BMEM 	=	((cstate == STAGE_1 || cstate == STAGE_3) && (cnt >= 3 && cnt <= 18)) ? 0 : 1;
assign we_OMEM 	= 	(cstate_in == RUN && cstate == STAGE_4) ? 0 : 1;


assign sel_res = en_REG_C;
assign sel_mem  = (cstate == STAGE_2 || cstate == STAGE_4) ? 1 : 0;

assign addr_AMEM = 	(cstate_in == RUN) ? {cnt_in[0], cnt_in[1], cnt_in[2], cnt_in[3]} :
					(cstate == STAGE_1 && cnt <= 15) ? cnt:
					(cstate == STAGE_2 && cnt >= 3) ? buf3 :
					(cstate == STAGE_3 && cnt <= 15) ? {cnt[3], cnt[0], cnt[2], cnt[1]} :
					4'bx;
assign addr_BMEM =	(cstate == STAGE_1 && cnt >= 3) ? buf3:
					(cstate == STAGE_2 && cnt <= 15) ? {cnt[3:2], cnt[0], cnt[1]} :
					(cstate == STAGE_3 && cnt >= 3) ? buf3 :
					(cstate == STAGE_4 && cnt <= 15) ? {cnt[0], cnt[3:1]} :
					4'bx;
assign addr_OMEM =  (cstate == STAGE_4 && cnt >= 3) ? buf3 :
					(cstate_out == RUN && cnt_out < 16) ? cnt :
					4'bx;

assign in_handshake = in_rdy && in_vld;
		
//////////Edit code above!!/////////
////////////////////////////////////		
		
endmodule
