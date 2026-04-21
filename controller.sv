module controller(
    input  logic       clk,
    input  logic       reset,
    input  logic [6:0] op,
    input  logic [2:0] funct3,
    input  logic       funct7b5,
    input  logic       zero,
    output logic [1:0] immsrc,
    output logic [1:0] alusrca,
    output logic [1:0] alusrcb,
    output logic [1:0] resultsrc,
    output logic       adrsrc,
    output logic [2:0] alucontrol,
    output logic       irwrite,
    output logic       pcwrite,
    output logic       regwrite,
    output logic       memwrite
);

    logic [1:0] ALUOp;
    logic       branch;
    logic       pcupdate;

    // Main FSM / decoder
    maindec md(
        .clk(clk),
        .reset(reset),
        .op(op),
        .ALUOp(ALUOp),
        .ALUSrcA(alusrca),
        .ALUSrcB(alusrcb),
        .ResultSrc(resultsrc),
        .AdrSrc(adrsrc),
        .IRWrite(irwrite),
        .RegWrite(regwrite),
        .MemWrite(memwrite),
        .Branch(branch),
        .PCUpdate(pcupdate)
    );

    // Instruction decoder
    instrdec id(
        .op(op),
        .ImmSrc(immsrc)
    );

    // ALU decoder
    aludec ad(
        .opb5(op[5]),
        .funct3(funct3),
        .funct7b5(funct7b5),
        .ALUOp(ALUOp),
        .ALUControl(alucontrol)
    );

    // PC write logic
    assign pcwrite = pcupdate | (branch & zero);

endmodule


module maindec(
    input  logic       clk,
    input  logic       reset,
    input  logic [6:0] op,
    output logic [1:0] ALUOp,
    output logic [1:0] ALUSrcA,
    output logic [1:0] ALUSrcB,
    output logic [1:0] ResultSrc,
    output logic       AdrSrc,
    output logic       IRWrite,
    output logic       RegWrite,
    output logic       MemWrite,
    output logic       Branch,
    output logic       PCUpdate
);

    typedef enum logic [3:0] {
        S0_FETCH    = 4'd0,
        S1_DECODE   = 4'd1,
        S2_MEMADR   = 4'd2,
        S3_MEMREAD  = 4'd3,
        S4_MEMWB    = 4'd4,
        S5_MEMWRITE = 4'd5,
        S6_EXECUTER = 4'd6,
        S7_ALUWB    = 4'd7,
        S8_EXECUTEI = 4'd8,
        S9_JAL      = 4'd9,
        S10_BEQ     = 4'd10
    } state_t;

    state_t state, nextstate;

    // State register
    always_ff @(posedge clk or posedge reset) begin
        if (reset)
            state <= S0_FETCH;
        else
            state <= nextstate;
    end

    // Next-state logic
    always_comb begin
        nextstate = state;

        case (state)
            S0_FETCH: begin
                nextstate = S1_DECODE;
            end

            S1_DECODE: begin
                case (op)
                    7'b0000011: nextstate = S2_MEMADR;   // lw
                    7'b0100011: nextstate = S2_MEMADR;   // sw
                    7'b0110011: nextstate = S6_EXECUTER; // R-type
                    7'b0010011: nextstate = S8_EXECUTEI; // I-type ALU
                    7'b1101111: nextstate = S9_JAL;      // jal
                    7'b1100011: nextstate = S10_BEQ;     // beq
                    default:    nextstate = S0_FETCH;
                endcase
            end

            S2_MEMADR: begin
                case (op)
                    7'b0000011: nextstate = S3_MEMREAD;  // lw
                    7'b0100011: nextstate = S5_MEMWRITE; // sw
                    default:    nextstate = S0_FETCH;
                endcase
            end

            S3_MEMREAD:  nextstate = S4_MEMWB;
            S4_MEMWB:    nextstate = S0_FETCH;
            S5_MEMWRITE: nextstate = S0_FETCH;
            S6_EXECUTER: nextstate = S7_ALUWB;
            S7_ALUWB:    nextstate = S0_FETCH;
            S8_EXECUTEI: nextstate = S7_ALUWB;
            S9_JAL:      nextstate = S7_ALUWB;
            S10_BEQ:     nextstate = S0_FETCH;

            default:     nextstate = S0_FETCH;
        endcase
    end

    // Output logic
    always_comb begin
        // default deterministic zeros
        ALUOp    = 2'b00;
        ALUSrcA  = 2'b00;
        ALUSrcB  = 2'b00;
        ResultSrc= 2'b00;
        AdrSrc   = 1'b0;
        IRWrite  = 1'b0;
        RegWrite = 1'b0;
        MemWrite = 1'b0;
        Branch   = 1'b0;
        PCUpdate = 1'b0;

        case (state)
            S0_FETCH: begin
                AdrSrc    = 1'b0;
                IRWrite   = 1'b1;
                ALUSrcA   = 2'b00;
                ALUSrcB   = 2'b10;
                ALUOp     = 2'b00;
                ResultSrc = 2'b10;
                PCUpdate  = 1'b1;
            end

            S1_DECODE: begin
                ALUSrcA   = 2'b01;
                ALUSrcB   = 2'b01;
                ALUOp     = 2'b00;
            end

            S2_MEMADR: begin
                ALUSrcA   = 2'b10;
                ALUSrcB   = 2'b01;
                ALUOp     = 2'b00;
            end

            S3_MEMREAD: begin
                ResultSrc = 2'b00;
                AdrSrc    = 1'b1;
            end

            S4_MEMWB: begin
                ResultSrc = 2'b01;
                RegWrite  = 1'b1;
            end

            S5_MEMWRITE: begin
                ResultSrc = 2'b00;
                AdrSrc    = 1'b1;
                MemWrite  = 1'b1;
            end

            S6_EXECUTER: begin
                ALUSrcA   = 2'b10;
                ALUSrcB   = 2'b00;
                ALUOp     = 2'b10;
            end

            S7_ALUWB: begin
                ResultSrc = 2'b00;
                RegWrite  = 1'b1;
            end

            S8_EXECUTEI: begin
                ALUSrcA   = 2'b10;
                ALUSrcB   = 2'b01;
                ALUOp     = 2'b10;
            end

            S9_JAL: begin
                ALUSrcA   = 2'b01;
                ALUSrcB   = 2'b10;
                ALUOp     = 2'b00;
                ResultSrc = 2'b00;
                PCUpdate  = 1'b1;
            end

            S10_BEQ: begin
                ALUSrcA   = 2'b10;
                ALUSrcB   = 2'b00;
                ALUOp     = 2'b01;
                ResultSrc = 2'b00;
                Branch    = 1'b1;
            end

            default: begin
                // all zeros
            end
        endcase
    end

endmodule


module aludec(
    input  logic       opb5,
    input  logic [2:0] funct3,
    input  logic       funct7b5,
    input  logic [1:0] ALUOp,
    output logic [2:0] ALUControl
);

    logic RtypeSub;

    assign RtypeSub = funct7b5 & opb5;

    always_comb begin
        case (ALUOp)
            2'b00: ALUControl = 3'b010; // add
            2'b01: ALUControl = 3'b110; // sub
            default: begin
                case (funct3)
                    3'b000: begin
                        if (RtypeSub)
                            ALUControl = 3'b110; // sub
                        else
                            ALUControl = 3'b010; // add/addi
                    end
                    3'b010: ALUControl = 3'b111; // slt
                    3'b110: ALUControl = 3'b001; // or
                    3'b111: ALUControl = 3'b000; // and
                    default: ALUControl = 3'bxxx;
                endcase
            end
        endcase
    end
endmodule

module instrdec(
    input  logic [6:0] op,
    output logic [1:0] ImmSrc
);

    always_comb begin
        case (op)
            7'b0110011: ImmSrc = 2'bxx; // R-type
            7'b0010011: ImmSrc = 2'b00; // I-type ALU
            7'b0000011: ImmSrc = 2'b00; // lw
            7'b0100011: ImmSrc = 2'b01; // sw
            7'b1100011: ImmSrc = 2'b10; // beq
            7'b1101111: ImmSrc = 2'b11; // jal
            default:    ImmSrc = 2'bxx;
        endcase
    end
endmodule