//Based on Dietz Solution for assembler
`define WORD[15:0] //size of instruciton
`define DATA[15:0] //size of data
`define ADDR[15:0] //size of address

//Bits represented with instruciton
`define OP[15:10] //6 bits for Op code
`define INSSET[9:8] //2 bits for type of SRC
`define SRC[7:4] // 4 Bits for SRC
`define DEST[3:0] //4 Bits for DEST
`define PUSHBIT[14] //Bit 14 represents non-reversible instructions
`define IS_I8[15] //Bit 15 represents 8 bit immediate instruction
`define NEG_BIT[15] //Bit 15 of register represents if its negative

//Bits represnted for Immediate 8 bits
`define IMMEDIATE[11:4] //8 bits for Immediate value
`define IMMOP[15:12] //4 bits for  Op code

//Miscellaneous definitions
`define STATE[6:0]
`define REGSIZE [15:0] //According to AXA
`define MEMSIZE [65536:0]
`define USIZE [15:0] //Undo stack size
`define INDEX [3:0] //Undo stack index
`define RegType    2'b00
`define I4Type     2'b01
`define SrcRegType 2'b10
`define Buffi4Type 2'b11

//Define OPcodes
//Op values
`define OPsys  6'b000000
`define OPcom  6'b000001
`define OPadd  6'b000010
`define OPsub  6'b000011
`define OPxor  6'b000100
`define OPex   6'b000101
`define OProl  6'b000110
`define OPbz   6'b001000
`define OPbnz  6'b001001
`define OPbn   6'b001010
`define OPbnn  6'b001011
`define OPjz   `OPbz
`define OPjnz  `OPbnz
`define OPjn   `OPbn
`define OPjnn  `OPbnn
`define OPjerr 6'b001110
`define OPfail 6'b001111
`define OPland 6'b010000
`define OPshr  6'b010001
`define OPor   6'b010010
`define OPand  6'b010011
`define OPdup  6'b010100
`define OPxhi  6'b100000
`define OPxlo  6'b101000
`define OPlhi  6'b110000
`define OPllo  6'b111000

`define NOP    16'hffff

module processor(halt, reset, clk);
output reg halt;
input reset, clk;

reg `DATA regfile `REGSIZE; //Register file
reg `DATA datamem `MEMSIZE; //Data memory
reg `WORD instmem `MEMSIZE; //Instruction memory
reg `ADDR pc; //Program Counter
reg `ADDR targetpc, landpc, lc; //Target PC, Landing PC, Current PC
reg `DATA ustack `USIZE; //Undo stack
reg `INDEX usp; //Undo stack pointer
reg `WORD ir; //Instruction Register

reg `WORD pct, pc0, pc1, pc2; //Pipeline PC value
reg `WORD sext0, sext1; //Pipeline sign extended
reg `WORD ir0, ir1, ir2; //Pipeline IR
reg `WORD d1, d2; //Pipeline destination register
reg `WORD s1, s2; //Pipeline source

wire pendjb; //Check for jump/branch
wire zero, nzero, neg, nneg; //Checks jump/branch conditions
wire jbtaken; //Is the jump or branch taken?
wire pendpush; //Checks if instruction pushes to undo stack
wire datadep; //Checks if there's a data dependency

//reset
always @(reset) begin
  halt <= 0;
  pc <= 0;
  usp <= 0;
  targetpc <= 0; landpc <= 0; lc <= 0;
  pct <= 0; pc0 <= 0; pc1 <= 0; pc2 <= 0;
  sext0 <= 0; sext1 <= 0;
  ir0 <= `NOP; ir1 <= `NOP; ir2 <= `NOP;
  d1 <= 0; d2 <= 0;
  s1 <= 0; s2 <= 0;
  $readmemh0(regfile);
  $readmemh1(datamem);
  $readmemh2(instmem);
  $readmemh3(ustack);
end

function setsdest;
input `WORD inst;
setsdest = (((inst `OP >= `OPadd) && (inst `OP <= `OProl))
           || ((inst `OP >= `OPshr) && (inst `OP <= `OPllo)));
endfunction

function usesdest;
input `WORD inst;
usesdest = ((inst `OP == `OPadd) ||
          (inst `OP == `OPsub) ||
          (inst `OP == `OPxor) ||
          (inst `OP == `OPex) ||
          (inst `OP == `OProl) ||
          (inst `OP == `OPshr) ||
          (inst `OP == `OPor) ||
          (inst `OP == `OPand) ||
          (inst `OP == `OPdup) ||
          (inst `OP == `OPbz) ||
          (inst `OP == `OPjz) ||
          (inst `OP == `OPbnz) ||
          (inst `OP == `OPjnz) ||
          (inst `OP == `OPbn) ||
          (inst `OP == `OPjn) ||
          (inst `OP == `OPbnn) ||
          (inst `OP == `OPjnn) ||
          (inst `OP == `OPxhi) ||
          (inst `OP == `OPxlo) ||
          (inst `OP == `OPlhi) ||
          (inst `OP == `OPllo));
endfunction

function usessrc;
input `WORD inst;
usessrc = ((inst `INSSET == `RegType) || (inst `INSSET == `SrcRegType)) &&
          (((inst `OP >= `OPadd) && (inst `OP <= `OPjnn))
          || ((inst `OP >= `OPshr) && (inst `OP <= `OPllo)));
endfunction

assign pendjb = (ir0 `OP == `OPjz) || (ir0 `OP == `OPjnz)
|| (ir0 `OP == `OPjn) || (ir0 `OP == `OPjnn)
|| (ir1 `OP == `OPjz) || (ir1 `OP == `OPjnz)
|| (ir1 `OP == `OPjn) || (ir1 `OP == `OPjnn);
assign zero = (d2 == 0) && (ir2 `OP == `OPjz);
assign nzero = (d2 != 0) && (ir2 `OP == `OPjnz);
assign neg = (d2 `NEG_BIT == 1) && (ir2 `OP == `OPjn);
assign nneg = (d2 `NEG_BIT == 0) && (ir2 `OP == `OPjnn);
assign jbtaken = zero || nzero || neg || nneg;

// sign-extended i4
assign sexi4 = {{12{ir[7]}}, (ir `SRC)};

assign pendpush = (ir1 `PUSHBIT) && (ir1 `OP != `OPland) && (ir1 != `NOP);

assign datadep = ((ir0 != `NOP) && ((setsdest(ir1) && ((usesdest(ir0)
&& (ir0 `DEST == ir1 `DEST)) || (usessrc(ir0) && (ir0 `SRC == ir1 `DEST))))
|| (setsdest(ir2) && ((usesdest(ir0) && (ir0 `DEST == ir2 `DEST))
|| (usessrc(ir0) && (ir0 `SRC == ir2 `DEST))))));

//stage 0: instruction fetch
always @(posedge clk) begin
  pct = (jbtaken ? targetpc : pc);
  if(datadep) begin
    // blocked by stage 1: should not have a jump
    pc <= pct;
  end else if (pendjb) begin
    pc <= pct;
    ir0 <= `NOP;
  end else begin
    //not blocked by stage 1:
    ir = instmem[pct];
    landpc <= lc;
    lc <= pct;
    if ((ir `OP == `OPjerr) || (ir `OP == `OPcom))
    begin
        ir0 <= `NOP;
    end else begin
        ir0 <= ir;
    end
    if (ir `OP == `OPland)
    begin
        ustack[usp + 1] <= landpc;
        usp <= usp + 1;
    end
    if (ir `IS_I8) begin
      sext0 <= {8'b0, ir `IMMEDIATE};
    end else begin
      sext0 <= {{12{ir[7]}}, ir `SRC};
    end
    pc <= pct + 1;
    pc0 <= pct;
  end
end

//stage 1: register read
always @(posedge clk) begin
  if(ir0 == `NOP) begin
    ir1 <= `NOP;
  end else begin
    if(datadep) begin
      // stall waiting for register value
      ir1 <= `NOP;
    end else begin
      // all good, get operands (even if not needed)
      d1 <=  regfile[ir0 `DEST];
      s1 <=  regfile[ir0 `SRC];
      sext1 <= sext0;
      ir1 <= ir0;
      pc1 <= pc0;
    end
  end
end

//stage 2: data memory access
always @(posedge clk) begin
  if(ir1 `OP == `NOP) begin
    ir2 <= `NOP;
  end else begin
    if(ir1 `OP == `OPex) begin
      d2 <= datamem[s1];
      datamem[s1] <= d1;
    end else begin
      d2 <= d1;
    end
    if(ir1 `IS_I8) begin
       s2 <= sext1;
    end else begin
      case (ir1 `INSSET)
        `RegType: begin s2 <= s1; targetpc <= s1; end
        `I4Type: begin s2 <= sext1; targetpc <= pc1 + sext1; end
        `SrcRegType: begin s2 <= datamem[s1]; targetpc <= datamem[s1]; end
        `Buffi4Type: begin s2 <= ustack[usp - sext1[3:0]]; targetpc <= ustack[usp - sext1[3:0]]; end
      endcase
    end

    if(pendpush) begin
      ustack[usp + 1] <= d1;
      usp <= usp + 1;
    end
    pc2 <= pc1;
    ir2 <= ir1;
  end
end

//stage 3: ALU op and register write
always @(posedge clk) begin
  if(ir2 != `NOP) begin
    if(ir2 `IS_I8) begin
      case ({ir2 `IMMOP, 2'b0})
        `OPxhi: regfile[ir2 `DEST] <= d2 ^ (s2<<8);
        `OPxlo: regfile[ir2 `DEST] <= d2 ^ s2;
        `OPlhi: regfile[ir2 `DEST] <= {8'b0, d2[7:0]}|(s2<<8);
        `OPllo: regfile[ir2 `DEST] <= {d2[15:8], 8'b0}|s2;
      endcase
    end else begin
      case (ir2 `OP)
        `OPadd: regfile[ir2 `DEST] <= d2 + s2;
        `OPsub: regfile[ir2 `DEST] <= d2 - s2;
        `OPxor: regfile[ir2 `DEST] <= d2 ^ s2;
        `OPex: regfile[ir2 `DEST] <= d2;
        `OProl: regfile[ir2 `DEST] <= (d2<<s2)|(d2>>(16-s2));
        `OPor: regfile[ir2 `DEST] <= d2|s2;
        `OPand: regfile[ir2 `DEST] <= d2&s2;
        `OPshr: regfile[ir2 `DEST] <= d2 >> s2;
        `OPdup: regfile[ir2 `DEST] <= s2;
        `OPbz: begin end
        `OPbnz: begin end
        `OPbn: begin end
        `OPbnn: begin end
        `OPland: begin end
        `OPsys: begin $display("Finished"); halt <= 1; end
        `OPfail: halt <= 1;
        default: halt <= 1;
      endcase
    end
  end
end

endmodule

module testbench;
reg reset = 0;
reg clk = 0;
wire halted;
processor PE(halted, reset, clk);
initial begin
  $dumpfile;
  $dumpvars(0, PE.pc, PE.datadep, PE.ir, PE.ir0, PE.ir1, PE.ir2, PE.d1, PE.d2, PE.s1, PE.s2, PE.datadep, PE.pendpush, PE.pendjb, PE.jbtaken, PE.targetpc, PE.sext0, PE.sext1);
  #10 reset = 1;
  #10 reset = 0;
  while (!halted) begin
    #10 clk = 1;
    #10 clk = 0;
  end
  $finish;
end
endmodule
