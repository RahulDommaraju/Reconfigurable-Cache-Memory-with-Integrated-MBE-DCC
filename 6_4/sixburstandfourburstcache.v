`timescale 1ns/1ps

/* ============================================================
   TOP MODULE
============================================================ */

module ECC_Cache_System(

input clk,
input rst,

input write_en,
input read_en,

input [1:16] data_in,
input [1:6] address,
input [1:23] codeword_received,

input display_enable,

output [8:23] data_out,
output hit

);

wire ecc_mode;
wire cache_mode;

reg [1:23] codeword_reg;
reg mode_reg;

wire [1:23] encoded_codeword;
wire [1:23] cache_codeword;
wire [1:23] corrected_codeword;

wire [1:7] syndrome;
wire [2:0] burst_size;
wire uncorrectable;

wire [7:0] hit_count;
wire [7:0] miss_count;
wire [7:0] error_count;

wire switch_to_6;
wire switch_to_4;

reg access_valid_reg;

wire access_valid;
assign access_valid = access_valid_reg;

always @(posedge clk or posedge rst) begin

    if(rst)
        access_valid_reg <= 1'b0;
    else
        access_valid_reg <= (read_en && hit);

end

ECC_Mode_Manager mode_manager(
.clk(clk),
.rst(rst),
.uncorrectable(uncorrectable),
.burst_size(burst_size),
.access_valid(access_valid),
.ecc_mode(ecc_mode),
.switch_to_6(switch_to_6),
.switch_to_4(switch_to_4)
);

ECC_Encoder_Select encoder(
.data_in(data_in),
.ecc_mode(ecc_mode),
.encoded_codeword(encoded_codeword)
);

Cache_2Way cache(
.clk(clk),
.rst(rst),
.write_en(write_en),
.read_en(read_en),
.address(address),
.codeword_in(encoded_codeword),
.ecc_mode(ecc_mode),
.codeword_out(cache_codeword),
.mode_out(cache_mode),
.hit(hit)
);

wire [1:23] decoder_input;

assign decoder_input = (read_en && hit) ? cache_codeword :
                       ((codeword_received != 0) ? codeword_received : 23'b0);

always @(posedge clk or posedge rst) begin

    if(rst) begin
        codeword_reg <= 23'b0;
        mode_reg     <= 1'b0;
    end
    else begin
        codeword_reg <= decoder_input;
        mode_reg     <= ecc_mode;
    end

end

ECC_Decoder_Select decoder(
.codeword_received(codeword_reg),
.ecc_mode(mode_reg),
.display_enable(display_enable),
.corrected_codeword(corrected_codeword),
.data_out(data_out),
.syndrome(syndrome),
.burst_size(burst_size),
.uncorrectable(uncorrectable)
);

Cache_Stats stats(
.clk(clk),
.rst(rst),
.hit(hit),
.read_en(read_en),
.hit_count(hit_count),
.miss_count(miss_count)
);

Reliability_Monitor reliability(
.clk(clk),
.rst(rst),
.uncorrectable(uncorrectable),
.access_valid(access_valid),
.error_count(error_count)
);

endmodule

/* ============================================================
   MODE MANAGER
============================================================ */

module ECC_Mode_Manager(

input clk,
input rst,
input uncorrectable,
input [2:0] burst_size,
input access_valid,

output reg ecc_mode,
output reg switch_to_6,
output reg switch_to_4

);

reg [2:0] uncorr_count;
reg [2:0] small_count;

always @(posedge clk or posedge rst) begin

    if(rst) begin

        ecc_mode     <= 1'b0;
        uncorr_count <= 3'b0;
        small_count  <= 3'b0;
        switch_to_6  <= 1'b0;
        switch_to_4  <= 1'b0;

    end
    else begin

        switch_to_6 <= 1'b0;
        switch_to_4 <= 1'b0;

        if(ecc_mode == 1'b0) begin

            if(access_valid) begin

                if(uncorrectable)
                    uncorr_count <= uncorr_count + 1'b1;
                else
                    uncorr_count <= 3'b0;

                if((uncorr_count == 3'd2) && uncorrectable) begin
                    ecc_mode     <= 1'b1;
                    uncorr_count <= 3'b0;
                    switch_to_6  <= 1'b1;
                end

            end

        end
        else begin

            if(access_valid) begin

                if((burst_size <= 4) && (burst_size != 0))
                    small_count <= small_count + 1'b1;
                else
                    small_count <= 3'b0;

                if((small_count == 3'd2) && (burst_size <= 4) && (burst_size != 0)) begin
                    ecc_mode    <= 1'b0;
                    small_count <= 3'b0;
                    switch_to_4 <= 1'b1;
                end

            end

        end

    end

end

endmodule

/* ============================================================
   ENCODER SELECT
============================================================ */

module ECC_Encoder_Select(

input [1:16] data_in,
input ecc_mode,

output [1:23] encoded_codeword

);

wire [1:23] code4;
wire [1:23] code6;

BCH23_16_Encoder enc4(
.data_in(data_in),
.encoded_codeword(code4)
);

BCH23_16_Encoder_6burst enc6(
.data_in(data_in),
.encoded_codeword(code6)
);

assign encoded_codeword = (ecc_mode == 1'b0) ? code4 : code6;

endmodule

/* ============================================================
   BCH 4-BURST ENCODER
============================================================ */

module BCH23_16_Encoder(
input [1:16] data_in,
output reg [1:23] encoded_codeword
);

integer i;
reg [1:7] parity;
reg [1:23] temp_codeword;

function [1:7] H4;
input integer idx;
begin
case(idx)
1:  H4 = 7'b1000000;
2:  H4 = 7'b0100000;
3:  H4 = 7'b0010000;
4:  H4 = 7'b0001000;
5:  H4 = 7'b0000100;
6:  H4 = 7'b0000010;
7:  H4 = 7'b0000001;
8:  H4 = 7'b1001000;
9:  H4 = 7'b0100110;
10: H4 = 7'b0010001;
11: H4 = 7'b1101000;
12: H4 = 7'b0100100;
13: H4 = 7'b1000111;
14: H4 = 7'b0110110;
15: H4 = 7'b1101100;
16: H4 = 7'b1000001;
17: H4 = 7'b1011000;
18: H4 = 7'b0110011;
19: H4 = 7'b0001001;
20: H4 = 7'b0001111;
21: H4 = 7'b1000100;
22: H4 = 7'b0100001;
23: H4 = 7'b0010011;
default: H4 = 7'b0000000;
endcase
end
endfunction

always @(*) begin

    temp_codeword = 23'b0;
    parity        = 7'b0;

    temp_codeword[8:23] = data_in;

    for(i=8;i<=23;i=i+1)
        if(temp_codeword[i])
            parity = parity ^ H4(i);

    temp_codeword[1:7] = parity;
    encoded_codeword   = temp_codeword;

end

endmodule

/* ============================================================
   BCH 6-BURST ENCODER
============================================================ */

module BCH23_16_Encoder_6burst(

input [1:16] data_in,
output reg [1:23] encoded_codeword

);

integer i;
reg [1:7] parity;
reg [1:23] temp_codeword;

function [1:7] H6;
input integer idx;
begin
case(idx)
1:  H6 = 7'b1000000;
2:  H6 = 7'b0100000;
3:  H6 = 7'b0010000;
4:  H6 = 7'b0001000;
5:  H6 = 7'b0000100;
6:  H6 = 7'b0000010;
7:  H6 = 7'b0000001;
8:  H6 = 7'b0100010;
9:  H6 = 7'b1001000;
10: H6 = 7'b0000101;
11: H6 = 7'b1000100;
12: H6 = 7'b1010000;
13: H6 = 7'b1000010;
14: H6 = 7'b1100100;
15: H6 = 7'b1010001;
16: H6 = 7'b0101100;
17: H6 = 7'b1001110;
18: H6 = 7'b0100100;
19: H6 = 7'b0001010;
20: H6 = 7'b1001001;
21: H6 = 7'b0010110;
22: H6 = 7'b1001010;
23: H6 = 7'b1000111;
default: H6 = 7'b0000000;
endcase
end
endfunction

always @(*) begin

    temp_codeword = 23'b0;
    parity        = 7'b0;

    temp_codeword[8:23] = data_in;

    for(i=8;i<=23;i=i+1)
        if(temp_codeword[i])
            parity = parity ^ H6(i);

    temp_codeword[1:7] = parity;
    encoded_codeword   = temp_codeword;

end

endmodule

/* ============================================================
   DECODER SELECT
============================================================ */

module ECC_Decoder_Select(

input [1:23] codeword_received,
input ecc_mode,
input display_enable,

output [1:23] corrected_codeword,
output [8:23] data_out,
output [1:7] syndrome,
output [2:0] burst_size,
output uncorrectable

);

wire [1:23] corr4;
wire [1:23] corr6;

wire [8:23] data4;
wire [8:23] data6;

wire [1:7] syn4;
wire [1:7] syn6;

wire [2:0] burst4;
wire [2:0] burst6;

wire unc4;
wire unc6;

wire en4;
wire en6;

assign en4 = (ecc_mode == 1'b0);
assign en6 = (ecc_mode == 1'b1);

BCH23_16_Decoder dec4(
.codeword_received(codeword_received),
.enable(en4),
.display_enable(display_enable),
.corrected_codeword(corr4),
.final_output(data4),
.syndrome(syn4),
.burst_size(burst4),
.uncorrectable(unc4)
);

BCH23_16_Decoder_6burst dec6(
.codeword_received(codeword_received),
.enable(en6),
.display_enable(display_enable),
.corrected_codeword(corr6),
.final_output(data6),
.syndrome(syn6),
.burst_size(burst6),
.uncorrectable(unc6)
);

assign corrected_codeword = (ecc_mode == 1'b0) ? corr4 : corr6;
assign data_out           = (ecc_mode == 1'b0) ? data4 : data6;
assign syndrome           = (ecc_mode == 1'b0) ? syn4  : syn6;
assign burst_size         = (ecc_mode == 1'b0) ? burst4 : burst6;
assign uncorrectable      = (ecc_mode == 1'b0) ? unc4 : unc6;

endmodule

/* ============================================================
   BCH 4-BURST DECODER
============================================================ */

module BCH23_16_Decoder(

input [1:23] codeword_received,
input enable,
input display_enable,

output reg [1:23] corrected_codeword,
output reg [8:23] final_output,
output reg [1:7] syndrome,
output reg [2:0] burst_size,
output reg uncorrectable

);

integer i;
reg matched;

function [1:7] H4;
input integer idx;
begin
case(idx)
1:  H4 = 7'b1000000;
2:  H4 = 7'b0100000;
3:  H4 = 7'b0010000;
4:  H4 = 7'b0001000;
5:  H4 = 7'b0000100;
6:  H4 = 7'b0000010;
7:  H4 = 7'b0000001;
8:  H4 = 7'b1001000;
9:  H4 = 7'b0100110;
10: H4 = 7'b0010001;
11: H4 = 7'b1101000;
12: H4 = 7'b0100100;
13: H4 = 7'b1000111;
14: H4 = 7'b0110110;
15: H4 = 7'b1101100;
16: H4 = 7'b1000001;
17: H4 = 7'b1011000;
18: H4 = 7'b0110011;
19: H4 = 7'b0001001;
20: H4 = 7'b0001111;
21: H4 = 7'b1000100;
22: H4 = 7'b0100001;
23: H4 = 7'b0010011;
default: H4 = 7'b0000000;
endcase
end
endfunction

always @(*) begin

    uncorrectable      = 1'b0;
    burst_size         = 3'b0;
    matched            = 1'b0;
    syndrome           = 7'b0;
    corrected_codeword = codeword_received;
    final_output       = 16'b0;

    if(enable && (codeword_received != 0)) begin

        for(i=1;i<=23;i=i+1)
            if(codeword_received[i])
                syndrome = syndrome ^ H4(i);

        for(i=1;i<=23;i=i+1)
            if(!matched && (syndrome == H4(i))) begin
                corrected_codeword[i] = ~codeword_received[i];
                matched = 1'b1;
                burst_size = 3'd1;
            end

        for(i=1;i<=22;i=i+1)
            if(!matched && (syndrome == (H4(i)^H4(i+1)))) begin
                corrected_codeword[i]   = ~codeword_received[i];
                corrected_codeword[i+1] = ~codeword_received[i+1];
                matched = 1'b1;
                burst_size = 3'd2;
            end

        for(i=1;i<=21;i=i+1)
            if(!matched && (syndrome == (H4(i)^H4(i+1)^H4(i+2)))) begin
                corrected_codeword[i]   = ~codeword_received[i];
                corrected_codeword[i+1] = ~codeword_received[i+1];
                corrected_codeword[i+2] = ~codeword_received[i+2];
                matched = 1'b1;
                burst_size = 3'd3;
            end

        for(i=1;i<=20;i=i+1)
            if(!matched && (syndrome == (H4(i)^H4(i+1)^H4(i+2)^H4(i+3)))) begin
                corrected_codeword[i]   = ~codeword_received[i];
                corrected_codeword[i+1] = ~codeword_received[i+1];
                corrected_codeword[i+2] = ~codeword_received[i+2];
                corrected_codeword[i+3] = ~codeword_received[i+3];
                matched = 1'b1;
                burst_size = 3'd4;
            end

        if((syndrome != 0) && !matched)
            uncorrectable = 1'b1;

        final_output = corrected_codeword[8:23];

    end

end

endmodule

/* ============================================================
   BCH 6-BURST DECODER
============================================================ */

module BCH23_16_Decoder_6burst(

input [1:23] codeword_received,
input enable,
input display_enable,

output reg [1:23] corrected_codeword,
output reg [8:23] final_output,
output reg [1:7] syndrome,
output reg [2:0] burst_size,
output reg uncorrectable

);

integer i;
reg matched;

function [1:7] H6;
input integer idx;
begin
case(idx)
1:  H6 = 7'b1000000;
2:  H6 = 7'b0100000;
3:  H6 = 7'b0010000;
4:  H6 = 7'b0001000;
5:  H6 = 7'b0000100;
6:  H6 = 7'b0000010;
7:  H6 = 7'b0000001;
8:  H6 = 7'b0100010;
9:  H6 = 7'b1001000;
10: H6 = 7'b0000101;
11: H6 = 7'b1000100;
12: H6 = 7'b1010000;
13: H6 = 7'b1000010;
14: H6 = 7'b1100100;
15: H6 = 7'b1010001;
16: H6 = 7'b0101100;
17: H6 = 7'b1001110;
18: H6 = 7'b0100100;
19: H6 = 7'b0001010;
20: H6 = 7'b1001001;
21: H6 = 7'b0010110;
22: H6 = 7'b1001010;
23: H6 = 7'b1000111;
default: H6 = 7'b0000000;
endcase
end
endfunction

always @(*) begin

    uncorrectable      = 1'b0;
    burst_size         = 3'b0;
    matched            = 1'b0;
    syndrome           = 7'b0;
    corrected_codeword = codeword_received;
    final_output       = 16'b0;

    if(enable && (codeword_received != 0)) begin

        for(i=1;i<=23;i=i+1)
            if(codeword_received[i])
                syndrome = syndrome ^ H6(i);

        for(i=1;i<=23;i=i+1)
            if(!matched && (syndrome == H6(i))) begin
                corrected_codeword[i] = ~codeword_received[i];
                matched = 1'b1;
                burst_size = 3'd1;
            end

        for(i=1;i<=22;i=i+1)
            if(!matched && (syndrome == (H6(i)^H6(i+1)))) begin
                corrected_codeword[i]   = ~codeword_received[i];
                corrected_codeword[i+1] = ~codeword_received[i+1];
                matched = 1'b1;
                burst_size = 3'd2;
            end

        for(i=1;i<=21;i=i+1)
            if(!matched && (syndrome == (H6(i)^H6(i+1)^H6(i+2)))) begin
                corrected_codeword[i]   = ~codeword_received[i];
                corrected_codeword[i+1] = ~codeword_received[i+1];
                corrected_codeword[i+2] = ~codeword_received[i+2];
                matched = 1'b1;
                burst_size = 3'd3;
            end

        for(i=1;i<=20;i=i+1)
            if(!matched && (syndrome == (H6(i)^H6(i+1)^H6(i+2)^H6(i+3)))) begin
                corrected_codeword[i]   = ~codeword_received[i];
                corrected_codeword[i+1] = ~codeword_received[i+1];
                corrected_codeword[i+2] = ~codeword_received[i+2];
                corrected_codeword[i+3] = ~codeword_received[i+3];
                matched = 1'b1;
                burst_size = 3'd4;
            end

        for(i=1;i<=19;i=i+1)
            if(!matched && (syndrome == (H6(i)^H6(i+1)^H6(i+2)^H6(i+3)^H6(i+4)))) begin
                corrected_codeword[i]   = ~codeword_received[i];
                corrected_codeword[i+1] = ~codeword_received[i+1];
                corrected_codeword[i+2] = ~codeword_received[i+2];
                corrected_codeword[i+3] = ~codeword_received[i+3];
                corrected_codeword[i+4] = ~codeword_received[i+4];
                matched = 1'b1;
                burst_size = 3'd5;
            end

        for(i=1;i<=18;i=i+1)
            if(!matched && (syndrome == (H6(i)^H6(i+1)^H6(i+2)^H6(i+3)^H6(i+4)^H6(i+5)))) begin
                corrected_codeword[i]   = ~codeword_received[i];
                corrected_codeword[i+1] = ~codeword_received[i+1];
                corrected_codeword[i+2] = ~codeword_received[i+2];
                corrected_codeword[i+3] = ~codeword_received[i+3];
                corrected_codeword[i+4] = ~codeword_received[i+4];
                corrected_codeword[i+5] = ~codeword_received[i+5];
                matched = 1'b1;
                burst_size = 3'd6;
            end

        if((syndrome != 0) && !matched)
            uncorrectable = 1'b1;

        final_output = corrected_codeword[8:23];

    end

end

endmodule

/* ============================================================
   CACHE
============================================================ */

module Cache_2Way(

input clk,
input rst,
input write_en,
input read_en,

input [1:6] address,
input [1:23] codeword_in,
input ecc_mode,

output reg [1:23] codeword_out,
output reg mode_out,
output hit

);

reg hit_int;
reg hit_reg;

assign hit = hit_reg;

reg [1:23] data_way0 [1:4];
reg [1:23] data_way1 [1:4];

reg [1:4] tag_way0 [1:4];
reg [1:4] tag_way1 [1:4];

reg [1:6] addr_way0 [1:4];
reg [1:6] addr_way1 [1:4];

reg valid_way0 [1:4];
reg valid_way1 [1:4];

reg mode_way0 [1:4];
reg mode_way1 [1:4];

reg lru [1:4];

integer index;
integer i;
reg [1:4] tag;

always @(posedge clk or posedge rst) begin

    if(rst) begin

        for(i=1;i<=4;i=i+1) begin

            valid_way0[i] <= 1'b0;
            valid_way1[i] <= 1'b0;
            lru[i]        <= 1'b0;

            data_way0[i]  <= 23'b0;
            data_way1[i]  <= 23'b0;

            tag_way0[i]   <= 4'b0;
            tag_way1[i]   <= 4'b0;

            addr_way0[i]  <= 6'b0;
            addr_way1[i]  <= 6'b0;

            mode_way0[i]  <= 1'b0;
            mode_way1[i]  <= 1'b0;

        end

        hit_int      <= 1'b0;
        hit_reg      <= 1'b0;
        codeword_out <= 23'b0;
        mode_out     <= 1'b0;

    end
    else begin

        index = {address[5], address[6]} + 1;
        tag   = address[1:4];

        hit_int <= 1'b0;

        if(read_en) begin

            if(valid_way0[index] && (tag_way0[index] == tag) && (addr_way0[index] == address)) begin

                hit_int      <= 1'b1;
                codeword_out <= data_way0[index];
                mode_out     <= mode_way0[index];
                lru[index]   <= 1'b1;

            end
            else if(valid_way1[index] && (tag_way1[index] == tag) && (addr_way1[index] == address)) begin

                hit_int      <= 1'b1;
                codeword_out <= data_way1[index];
                mode_out     <= mode_way1[index];
                lru[index]   <= 1'b0;

            end

        end

        if(write_en) begin

            if(valid_way0[index] && (tag_way0[index] == tag)) begin

                data_way0[index] <= codeword_in;
                mode_way0[index] <= ecc_mode;
                addr_way0[index] <= address;
                lru[index]       <= 1'b1;

            end
            else if(valid_way1[index] && (tag_way1[index] == tag)) begin

                data_way1[index] <= codeword_in;
                mode_way1[index] <= ecc_mode;
                addr_way1[index] <= address;
                lru[index]       <= 1'b0;

            end
            else if(!valid_way0[index]) begin

                data_way0[index]  <= codeword_in;
                tag_way0[index]   <= tag;
                addr_way0[index]  <= address;
                valid_way0[index] <= 1'b1;
                mode_way0[index]  <= ecc_mode;
                lru[index]        <= 1'b1;

            end
            else if(!valid_way1[index]) begin

                data_way1[index]  <= codeword_in;
                tag_way1[index]   <= tag;
                addr_way1[index]  <= address;
                valid_way1[index] <= 1'b1;
                mode_way1[index]  <= ecc_mode;
                lru[index]        <= 1'b0;

            end
            else begin

                if(lru[index] == 1'b0) begin

                    data_way0[index] <= codeword_in;
                    tag_way0[index]  <= tag;
                    addr_way0[index] <= address;
                    mode_way0[index] <= ecc_mode;
                    lru[index]       <= 1'b1;

                end
                else begin

                    data_way1[index] <= codeword_in;
                    tag_way1[index]  <= tag;
                    addr_way1[index] <= address;
                    mode_way1[index] <= ecc_mode;
                    lru[index]       <= 1'b0;

                end

            end

        end

        hit_reg <= hit_int;

    end

end

endmodule

/* ============================================================
   CACHE STATS
============================================================ */

module Cache_Stats(

input clk,
input rst,
input hit,
input read_en,

output reg [7:0] hit_count,
output reg [7:0] miss_count

);

reg read_d1;
reg read_d2;
reg read_d3;

always @(posedge clk or posedge rst) begin

    if(rst) begin

        hit_count  <= 8'b0;
        miss_count <= 8'b0;

        read_d1 <= 1'b0;
        read_d2 <= 1'b0;
        read_d3 <= 1'b0;

    end
    else begin

        read_d1 <= read_en;
        read_d2 <= read_d1;
        read_d3 <= read_d2;

        if(read_d3 && !read_d2) begin

            if(hit)
                hit_count <= hit_count + 1'b1;
            else
                miss_count <= miss_count + 1'b1;

        end

    end

end

endmodule

/* ============================================================
   RELIABILITY MONITOR
============================================================ */

module Reliability_Monitor(

input clk,
input rst,
input uncorrectable,
input access_valid,

output reg [7:0] error_count

);

always @(posedge clk or posedge rst) begin

    if(rst)
        error_count <= 8'b0;
    else begin

        if(access_valid) begin
            if(uncorrectable)
                error_count <= error_count + 1'b1;
        end

    end

end

endmodule
