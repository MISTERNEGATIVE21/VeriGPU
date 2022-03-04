module comp_driver(
);
    reg rst;
    reg clk;

    wire [15:0] out;
    wire [15:0] pc;
    wire [3:0] op;
    wire [3:0] reg_select;
    wire [7:0] p1;
    wire [7:0] x1;
    wire [4:0] state;
    wire outen;

    reg [15:0] oob_write_addr;
    reg [15:0] oob_write_data;
    reg oob_mem_wen;
    reg [15:0] mem_load [256];

    reg [7:0] outmem [32];
    reg [4:0] outpos;

    comp comp1(
        .clk(clk), .rst(rst),
        .pc(pc), .op(op), .reg_select(reg_select),
        .x1(x1), .p1(p1), .state(state),
        .out(out), .outen(outen),
        .oob_write_addr(oob_write_addr),
        .oob_write_data(oob_write_data),
        .oob_mem_wen(oob_mem_wen)
    );

    initial begin
        clk = 1;
        forever #5 clk = ~clk;
    end
    always @(posedge clk) begin
        if (outen) begin
            outmem[outpos] <= out;
            outpos <= outpos + 1;
        end
    end
    initial begin
        $readmemh("build/{PROG}.hex", mem_load);
        for(int i = 0; i < 255; i++) begin
            #10
            oob_mem_wen = 1;
            oob_write_addr = i;
            oob_write_data = mem_load[i];
        end
        #10
        oob_mem_wen = 0;
        outpos = 0;
        #10

        $monitor(
            "t=%d rst=%b pc=%h, out=%h op=%h p1=%h rs=%h x1=%h state=%d",
            $time(), rst, pc, out,  op,   p1,   reg_select, x1, state);
        rst = 1;
        #10 rst = 0;
        #400
        for(int i = 0; i < outpos; i++) begin
            $display("out %h %h", i, outmem[i]);
        end
        $finish();
    end
endmodule
