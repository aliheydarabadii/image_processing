module image_postprocess #(
    parameter [1:0] MODE = 2'd3,
    parameter [11:0] THRESHOLD = 12'd1536,
    parameter [11:0] EDGE_THRESHOLD = 12'd192
) (
    input             clk,
    input             rstn,
    input             vsync_in,
    input             hsync_in,
    input             de_in,
    input [11:0]      r_in,
    input [11:0]      g_in,
    input [11:0]      b_in,

    output reg        vsync_out,
    output reg        hsync_out,
    output reg        de_out,
    output reg [11:0] r_out,
    output reg [11:0] g_out,
    output reg [11:0] b_out
);

localparam [1:0] MODE_BYPASS   = 2'd0;
localparam [1:0] MODE_GRAYSCALE = 2'd1;
localparam [1:0] MODE_THRESHOLD = 2'd2;
localparam [1:0] MODE_SOBEL     = 2'd3;

reg        de_prev, vsync_prev;
reg        de_d1, vsync_d1, hsync_d1;
reg [11:0] r_d1, g_d1, b_d1, luma_d1;
reg [10:0] x_count;
reg [10:0] line_count;
reg [1:0]  line_mod3;
reg        new_frame_pending;

reg [11:0] top0, top1, top2;
reg [11:0] mid0, mid1, mid2;
reg [11:0] bot0, bot1, bot2;

wire [13:0] luma_sum;
wire [11:0] luma_in;
wire        de_rise;
wire        frame_restart;
wire        use_new_frame;
wire [10:0] x_addr_eff;
wire [10:0] line_count_eff;
wire [1:0]  line_mod3_eff;

wire        wr_buf0, wr_buf1, wr_buf2;
wire [11:0] lb0_q, lb1_q, lb2_q;

reg [11:0] prev1_pix, prev2_pix;
wire [11:0] top0_next, top1_next, top2_next;
wire [11:0] mid0_next, mid1_next, mid2_next;
wire [11:0] bot0_next, bot1_next, bot2_next;

wire [13:0] gx_pos, gx_neg, gy_pos, gy_neg;
wire signed [14:0] gx_next, gy_next;
wire [14:0] abs_gx, abs_gy, edge_sum;
wire [11:0] edge_luma;
wire        window_valid;

reg [11:0] r_proc_next, g_proc_next, b_proc_next;

function [1:0] next_mod3;
    input [1:0] value;
    begin
        case (value)
            2'd0: next_mod3 = 2'd1;
            2'd1: next_mod3 = 2'd2;
            default: next_mod3 = 2'd0;
        endcase
    end
endfunction

assign luma_sum = {2'b00, r_in} + {1'b0, g_in, 1'b0} + {2'b00, b_in};
assign luma_in = luma_sum[13:2];

assign de_rise = ~de_prev & de_in;
assign frame_restart = ~vsync_prev & vsync_in;
assign use_new_frame = de_rise & (frame_restart | new_frame_pending);
assign x_addr_eff = de_rise ? 11'd0 : (de_in ? (x_count + 11'd1) : x_count);
assign line_count_eff = de_rise ? (use_new_frame ? 11'd0 : (line_count + 11'd1)) : line_count;
assign line_mod3_eff = de_rise ? (use_new_frame ? 2'd0 : next_mod3(line_mod3)) : line_mod3;

assign wr_buf0 = de_in & (line_mod3_eff == 2'd0);
assign wr_buf1 = de_in & (line_mod3_eff == 2'd1);
assign wr_buf2 = de_in & (line_mod3_eff == 2'd2);

rb_ram line_buffer0 (
    .WrAddress (x_addr_eff),
    .RdAddress (x_addr_eff),
    .Data      (luma_in),
    .WE        (wr_buf0),
    .RdClock   (clk),
    .RdClockEn (1'b1),
    .Reset     (~rstn),
    .WrClock   (clk),
    .WrClockEn (1'b1),
    .Q         (lb0_q)
);

rb_ram line_buffer1 (
    .WrAddress (x_addr_eff),
    .RdAddress (x_addr_eff),
    .Data      (luma_in),
    .WE        (wr_buf1),
    .RdClock   (clk),
    .RdClockEn (1'b1),
    .Reset     (~rstn),
    .WrClock   (clk),
    .WrClockEn (1'b1),
    .Q         (lb1_q)
);

rb_ram line_buffer2 (
    .WrAddress (x_addr_eff),
    .RdAddress (x_addr_eff),
    .Data      (luma_in),
    .WE        (wr_buf2),
    .RdClock   (clk),
    .RdClockEn (1'b1),
    .Reset     (~rstn),
    .WrClock   (clk),
    .WrClockEn (1'b1),
    .Q         (lb2_q)
);

always @(*) begin
    prev1_pix = 12'd0;
    prev2_pix = 12'd0;

    case (line_mod3)
        2'd0: begin
            prev1_pix = lb2_q;
            prev2_pix = lb1_q;
        end
        2'd1: begin
            prev1_pix = lb0_q;
            prev2_pix = lb2_q;
        end
        default: begin
            prev1_pix = lb1_q;
            prev2_pix = lb0_q;
        end
    endcase
end

assign top0_next = top1;
assign top1_next = top2;
assign top2_next = prev2_pix;
assign mid0_next = mid1;
assign mid1_next = mid2;
assign mid2_next = prev1_pix;
assign bot0_next = bot1;
assign bot1_next = bot2;
assign bot2_next = luma_d1;

assign gx_pos = {2'b00, top2_next} + {1'b0, mid2_next, 1'b0} + {2'b00, bot2_next};
assign gx_neg = {2'b00, top0_next} + {1'b0, mid0_next, 1'b0} + {2'b00, bot0_next};
assign gy_pos = {2'b00, bot0_next} + {1'b0, bot1_next, 1'b0} + {2'b00, bot2_next};
assign gy_neg = {2'b00, top0_next} + {1'b0, top1_next, 1'b0} + {2'b00, top2_next};

assign gx_next = $signed({1'b0, gx_pos}) - $signed({1'b0, gx_neg});
assign gy_next = $signed({1'b0, gy_pos}) - $signed({1'b0, gy_neg});
assign abs_gx = gx_next[14] ? (~gx_next + 15'd1) : gx_next;
assign abs_gy = gy_next[14] ? (~gy_next + 15'd1) : gy_next;
assign edge_sum = abs_gx + abs_gy;
assign edge_luma = edge_sum[14:3];
assign window_valid = de_d1 & (line_count >= 11'd2) & (x_count >= 11'd2);

always @(*) begin
    r_proc_next = 12'd0;
    g_proc_next = 12'd0;
    b_proc_next = 12'd0;

    if (de_d1) begin
        case (MODE)
            MODE_BYPASS: begin
                r_proc_next = r_d1;
                g_proc_next = g_d1;
                b_proc_next = b_d1;
            end

            MODE_GRAYSCALE: begin
                r_proc_next = luma_d1;
                g_proc_next = luma_d1;
                b_proc_next = luma_d1;
            end

            MODE_THRESHOLD: begin
                if (luma_d1 >= THRESHOLD) begin
                    r_proc_next = 12'hFFF;
                    g_proc_next = 12'hFFF;
                    b_proc_next = 12'hFFF;
                end
            end

            default: begin
                if (window_valid && (edge_luma >= EDGE_THRESHOLD)) begin
                    r_proc_next = edge_luma;
                    g_proc_next = edge_luma;
                    b_proc_next = edge_luma;
                end
            end
        endcase
    end
end

always @(posedge clk or negedge rstn)
    if (!rstn) begin
        de_prev <= 1'b0;
        vsync_prev <= 1'b0;
        de_d1 <= 1'b0;
        vsync_d1 <= 1'b0;
        hsync_d1 <= 1'b0;
        r_d1 <= 12'd0;
        g_d1 <= 12'd0;
        b_d1 <= 12'd0;
        luma_d1 <= 12'd0;
        x_count <= 11'd0;
        line_count <= 11'd0;
        line_mod3 <= 2'd0;
        new_frame_pending <= 1'b1;
    end
    else begin
        de_prev <= de_in;
        vsync_prev <= vsync_in;
        de_d1 <= de_in;
        vsync_d1 <= vsync_in;
        hsync_d1 <= hsync_in;
        r_d1 <= r_in;
        g_d1 <= g_in;
        b_d1 <= b_in;
        luma_d1 <= luma_in;

        if (frame_restart)
            new_frame_pending <= 1'b1;

        if (de_in)
            x_count <= x_addr_eff;

        if (de_rise) begin
            line_count <= line_count_eff;
            line_mod3 <= line_mod3_eff;

            if (use_new_frame)
                new_frame_pending <= 1'b0;
        end
    end

always @(posedge clk or negedge rstn)
    if (!rstn) begin
        top0 <= 12'd0;
        top1 <= 12'd0;
        top2 <= 12'd0;
        mid0 <= 12'd0;
        mid1 <= 12'd0;
        mid2 <= 12'd0;
        bot0 <= 12'd0;
        bot1 <= 12'd0;
        bot2 <= 12'd0;
    end
    else if (!de_d1) begin
        top0 <= 12'd0;
        top1 <= 12'd0;
        top2 <= 12'd0;
        mid0 <= 12'd0;
        mid1 <= 12'd0;
        mid2 <= 12'd0;
        bot0 <= 12'd0;
        bot1 <= 12'd0;
        bot2 <= 12'd0;
    end
    else begin
        top0 <= top0_next;
        top1 <= top1_next;
        top2 <= top2_next;
        mid0 <= mid0_next;
        mid1 <= mid1_next;
        mid2 <= mid2_next;
        bot0 <= bot0_next;
        bot1 <= bot1_next;
        bot2 <= bot2_next;
    end

always @(posedge clk or negedge rstn)
    if (!rstn) begin
        vsync_out <= 1'b0;
        hsync_out <= 1'b0;
        de_out <= 1'b0;
        r_out <= 12'd0;
        g_out <= 12'd0;
        b_out <= 12'd0;
    end
    else begin
        vsync_out <= vsync_d1;
        hsync_out <= hsync_d1;
        de_out <= de_d1;
        r_out <= r_proc_next;
        g_out <= g_proc_next;
        b_out <= b_proc_next;
    end

endmodule
