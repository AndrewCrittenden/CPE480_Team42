`define WORD    [15:0]
`define INST    [15:0]
`define OP      [5:0]
`define TYPE    [1:0]
`define REG     [3:0]
`define REGSIZE [15:0]
`define MEMSIZE [65535:0]
`define UPTR    [3:0]
`define USIZE   [255:0]

// instruction fields
`define IOPLEN  [15]
`define IL_OP   [15:10]
`define IL_TYPE [9:8]
`define IL_DEST [7:4]
`define IL_SRC  [3:0]
`define IL_SRCS [3]
`define IS_OP   [15:12]
`define IS_SRCH [11:8]
`define IS_DEST [7:4]
`define IS_SRCL [3:0]
`define IS_SRCS [11]

// op components
`define OP_PUSHES [2]
`define OP_LEN    [5]
`define OP_GROUP  [5:3]

// op codes
`define OPxhi  6'b000000 // First 4 only have the high 4 bits as real op code
`define OPlhi  6'b000100
`define OPxlo  6'b001000
`define OPllo  6'b001100 // The rest are the full op code
`define OPadd  6'b100000
`define OPsub  6'b100001
`define OPxor  6'b100010
`define OProl  6'b100011
`define OPshr  6'b100100
`define OPor   6'b100101
`define OPand  6'b100110
`define OPdup  6'b100111
`define OPbz   6'b101000 // same as... jz
`define OPbnz  6'b101001 //  jnz
`define OPbn   6'b101010 //  jn
`define OPbnn  6'b101011 //  jnn
`define OPjerr 6'b110000
`define OPfail 6'b110001
`define OPex   6'b110010
`define OPcom  6'b110011
`define OPland 6'b110100
`define OPsys  6'b111000
`define OPnop  6'b111010 // internal, not part of AXA

`define NOP {`OPnop, 10'b0}

`define ILTypeImm 2'b00
`define ILTypeReg 2'b01
`define ILTypeMem 2'b10
`define ILTypeUnd 2'b11

`define SIGILL 4'b0001;
`define SIGTMV 4'b0010;
`define SIGCHK 4'b0100;
`define SIGLEX 4'b1000;

module testbench;
reg reset = 0;
reg clk = 0;
wire halted;
processor PE(halted, reset, clk);
initial begin
	$dumpfile;
	$dumpvars(0, PE);
	#10 reset = 1;
	#10 clk = 1;
	#10 clk = 0;
	#10 reset = 0;
	while (!halted) begin
		#10 clk = 1;
		#10 clk = 0;
	end
	$finish;
end
endmodule

//Restore Register d from the undo buffer
`define DREST begin s4alu <= u[s2usp]; s2usp <= s2usp - 1; end

module processor (halt, reset, clk);
output reg halt;
input reset, clk;
reg `WORD  r  `REGSIZE;
reg `WORD  dm `MEMSIZE;
reg `WORD  im `MEMSIZE;
reg `WORD  u  `USIZE;

reg `WORD  s0pc;
reg `WORD  s0lastpc;
wire `WORD s0jmptarget;

reg `INST  s1ir;
reg `WORD  s1lastpc;
wire `OP   s1op;
wire `TYPE s1typ;
wire `WORD s1src;
wire `REG  s1dst;

reg `OP    s2op;
reg `TYPE  s2typ;
reg `WORD  s2src;
reg `WORD  s2dst;
reg `REG   s2dstreg;
reg `UPTR  s2usp;
wire `UPTR  s2undidx;

reg `OP    s3op;
reg `WORD  s3src;
reg `WORD  s3dst;
reg `REG   s3dstreg;

reg `OP    s4op;
reg `WORD  s4alu;
reg `REG   s4dstreg;

reg s4halt;
reg `REG check;
reg `REG errors;

reg s0fwd;
reg s1fwd;
reg s2fwd;
reg s3fwd;
reg s4fwd;

// Stage 0: Update PC
assign s0blocked = (opIsBranch(s1op) || opIsBranch(s2op));
assign s0waiting = s1blocked || s1waiting;
assign s0shouldjmp =
	   (s2op == `OPbz && s2dst == 0)
	|| (s2op == `OPbnz && s2dst != 0)
	|| (s2op == `OPbn && s2dst[15] == 1)
	|| (s2op == `OPbnn && s2dst[15] == 0);
assign s0jmptarget = (s2typ == `ILTypeImm) ? (s0pc + s2src - 1) : s2src;

always @(posedge clk) begin
	if (reset) begin
		s0pc <= 0;
		s0lastpc <= 0;
		$readmemh0(r);
		$readmemh1(im);
		$readmemh2(dm);
	end else begin 
		if (errors == 0) begin
			s0fwd <= 1;
		end else begin
			s0fwd <= 0;
		end
		if (s0shouldjmp) begin
			// save pc before jumping so land can push it to undo stack
			// -1 because stage 0 blocks one instruction after the branch
			s0lastpc <= s0pc - 1;
			s0pc <= s0jmptarget;
		end else if (!s0blocked && !s0waiting) begin
			s0lastpc <= s0pc;
			 s0pc <= s0pc + ((errors == 0) ? 1 : -1); //Increment or Decrement based on errors
		end
	end
	#1 $display($time, ": 0: s0pc: %d, should jump: %b, lastpc: %d", s0pc, s0shouldjmp, s0lastpc);
end

// Stage 1 (part 1): Fetch instruction
assign s1blocked = (opIsBlocking(s1op) || opIsBlocking(s2op)
                 || opIsBlocking(s3op) || opIsBlocking(s4op));
assign s1waiting = s2blocked || s2waiting;

always @(posedge clk) begin
	// s0blocked: Special case, s0 can't emit NOPs, so s1 needs to do that for it.
	if (reset || ((s0blocked || s1blocked) && !s1waiting)) begin
		s1ir <= `NOP;
		if (reset)
			s1lastpc <= 0;
	end else if (!s1waiting) begin
		s1fwd <= s0fwd;
		s1ir <= im[s0pc];
		s1lastpc <= s0lastpc;
	end
	#2 $display($time, ": 1: ir: %x, op: %s, typ: %b, src: %x, dst: %x, lastpc: %d", s1ir, opStr(s1op), s1typ, s1src, s1dst, s1lastpc);
end

// Stage 1 (part 2): Instruction decode
assign s1op  = (s1ir `IOPLEN == 0) ? {s1ir `IS_OP, 2'b00} : s1ir `IL_OP;
assign s1typ = (s1ir `IOPLEN == 0) ? `ILTypeImm : s1ir `IL_TYPE; // All short ops are Imm type
assign s1dst = (s1ir `IOPLEN == 0) ? s1ir `IS_DEST : s1ir `IL_DEST;
assign s1src = (s1ir `IOPLEN == 0)
		// sign extend short instructions (always immediate)
		? {{8{s1ir `IS_SRCS}}, s1ir `IS_SRCH, s1ir `IS_SRCL}
		// only sign extend long instructions if immediate
		: ((s1typ == `ILTypeImm) ? {{12{s1ir `IL_SRCS}}, s1ir `IL_SRC} : s1ir `IL_SRC);

// Stage 2: Read registers
assign s2blocked =
	// Block until dst register isn't being written to later in the pipeline
	   (opHasDst(s1op) && (
		   (s1dst == s2dstreg && opWritesToDst(s2op))
		|| (s1dst == s3dstreg && opWritesToDst(s3op))
		|| (s1dst == s4dstreg && opWritesToDst(s4op))))
	// If src requires a register read (TypeReg or TypeMem) block until it
	// isn't being written to later in the pipeline
	|| (opHasSrc(s1op) && (s1typ == `ILTypeReg || s1typ == `ILTypeMem) && (
		   (s1src == s2dstreg && opWritesToDst(s2op))
		|| (s1src == s3dstreg && opWritesToDst(s3op))
		|| (s1src == s4dstreg && opWritesToDst(s4op))));
assign s2waiting = 0;
assign s2undidx = s2usp - s1src - 1; // In own assign to clip value to `UPTR

always @(posedge clk) begin
	if (reset || (s2blocked && !s2waiting)) begin
		s2op  <= `OPnop;
		s2typ <= 0;
		s2src <= 0;
		s2dst <= 0;
		s2dstreg <= 0;
		if (reset)
			s2usp <= 0;
	end else if (!s2waiting) begin
		s2fwd <= s1fwd;
		s2op  <= s1op;
		s2typ <= s1typ;
		// Not all instructions have a valid src or dst to read, but
		// it doesn't hurt to always read them
		case (s1typ)
			`ILTypeImm: s2src <= s1src;
			// 4 bit wrapping offset for undo stack
			`ILTypeUnd: s2src <= u[s2undidx];
			`ILTypeReg, `ILTypeMem: s2src <= r[s1src];
		endcase
		s2dst <= r[s1dst];
		s2dstreg <= s1dst;
		// Push onto undo stack if this is a push instruction
		if (s1op `OP_PUSHES) begin
			if (s1fwd) begin
				// Most instructions push the value of the dst register
				// but land pushes the value of the pc before the most
				// recent jump. To avoid interlocks on the undo stack,
				// this value is pushed here, passed along by s1lastpc
				u[s2usp] <= (s1op == `OPland) ? s1lastpc : r[s1dst];
				s2usp <= s2usp + 1;
				$display($time, ": 2: PUSHING TO UNDO STACK: ", (s1op == `OPland) ? s1lastpc : r[s1dst], ", ", s1op, ", ", s1lastpc, ", ", r[s1dst]);
			end
			//else 'DREST TODO test if this works
		end
	end
	#3 $display($time, ": 2:           op: %s, typ: %b, src: %x, dst: %x, dstreg: %d, usp: %d", opStr(s2op), s2typ, s2src, s2dst, s2dstreg, s2usp);
end

// Stage 3: Read / write memory
always @(posedge clk) begin
	if (reset) begin
		s3op <= `OPnop;
		s3src <= 0;
		s3dst <= 0;
		s3dstreg <= 0;
	end else begin
		s3fwd <= s2fwd;
		s3op  <= s2op;
		s3src <= (s2typ == `ILTypeMem) ? dm[s2src] : s2src;
		s3dst <= s2dst;
		s3dstreg <= s2dstreg;
		if (s2op == `OPex) begin
			$display($time, ": 3: WRITING %h to mem addr %d", s2dst, s2src);
			dm[s2src] <= s2dst;
		end
	end
	#4 $display($time, ": 3:           op: %s,          src: %x, dst: %x, dstreg: %d", opStr(s3op), s3src, s3dst, s3dstreg);
end

// Stage 4: ALU
always @(posedge clk) begin
	if (reset) begin
		s4op  <= `OPnop;
		s4alu <= 0;
		s4dstreg <= 0;
		errors <= 0;
		check <= 0;
		halt <= 0;
		$display($time, ": 5: reset");
	end else begin
		s4fwd <= s3fwd;
		s4op <= s3op;
		s4dstreg <= s3dstreg;

		case (s3op) //ALU supports reverse Execution Now
			`OPxhi: begin s4alu <= {s3dst[15:8] ^ s3src[7:0], s3dst[7:0]}; end
			`OPxlo: begin s4alu <= {s3dst[15:8], s3dst[7:0] ^ s3src[7:0]}; end
			`OPlhi: begin if(s3fwd) begin s4alu <= {s3src[7:0], 8'b0}; end else `DREST end
			`OPllo: begin if(s3fwd) begin s4alu <= s3src; end else `DREST end
			`OPadd: begin s4alu <= s3dst + (s3fwd ? s3src : -s3src); end
			`OPsub: begin s4alu <= s3dst + (s3fwd ? -s3src : s3src); end
			`OPxor: begin s4alu <= s3dst ^ s3src; end
			`OProl: begin if(s3fwd) begin 
				s4alu <= (s3dst << (s3src & 16'h000f)) | (s3dst >> ((16 - s3src) & 16'h000f)); end //rotate left
				else begin
				s4alu <= (s3dst << ((16 - s3src) & 16'h000f)) | (s3dst >> (s3src & 16'h000f)); //rotate right
				end
			end
			`OPshr: begin if(s3fwd) begin s4alu <= {{16{s3dst[15]}}, s3dst} >> (s3src & 16'h000f); end else `DREST end
			`OPor:  begin if(s3fwd) begin s4alu <= s3dst | s3src; end else `DREST end
			`OPand: begin if(s3fwd) begin s4alu <= s3dst & s3src; end else `DREST end
			`OPex: begin s4alu <= s3src; end
			`OPdup: begin if(s3fwd) begin s4alu <= s3src; end else `DREST end

			`OPsys: begin halt <= 1; $display($time, ": 5: halting"); end
			`OPjerr: begin 
				if(s3fwd) begin 
					check <= check | s3src; $display($time, ": 5: JERR-FWD");
				end else begin
					check <= check & ~s3src; 
					errors <= errors & ~s3src; $display($time, ": 5: JERR-REVERSE");
				end
			end
			`OPcom: begin
				if(s3fwd) begin
					check <= 0;
				end else begin
					errors <= 0;
				end
			end
			`OPfail: begin 
				if(s3fwd) begin
					if((s3src & ~check) != 0) begin
						halt <= 1; $display($time, ": 5: FAILED-HALT");
					end else begin
						halt <= 0; errors <= s3src & check; $display($time, ": 5: FAILED-REVERSE");
					end
				end else begin
					//NOP do nothing in reverse execution
				end		
			end
		endcase
		if (opWritesToDst(s4op)) begin
				r[s4dstreg] <= s4alu;
				$display($time, ": 5: WRITING ", s4alu, " to reg ", s4dstreg);
		end
	end
	#5 $display($time, ": 4:           op: %s,          alu: %x,            dstreg: %d", opStr(s4op), s4alu, s4dstreg);
	#9 $display(""); // Spacer
end

/*
// Stage 5: Write registers
// This stage also owns "halt"
always @(posedge clk) begin
	if (reset) begin
		halt <= 0;
		$display($time, ": 5: reset");
	end 
	case (s4op)
		`OPsys: begin halt <= 1; $display($time, ": 5: halting"); end
		`OPfail: begin 
			halt <= s4halt;	
		end
		`OPjerr: begin
			//TODO jump to address in $d s4dstreg
		end
		default: begin
			if (opWritesToDst(s4op)) begin
				r[s4dstreg] <= s4alu;
				$display($time, ": 5: WRITING ", s4alu, " to reg ", s4dstreg);
			end
		end
	endcase
	#9 $display(""); // Spacer
end
*/

function opHasDst (input `OP op);
	opHasDst = (op `OP_LEN == 1'b0)
		|| (op `OP_GROUP == 3'b100)
		|| (op `OP_GROUP == 3'b101)
		|| (op == `OPex);
endfunction

function opHasSrc (input `OP op);
	opHasSrc = (op `OP_LEN == 1'b0)
		|| (op `OP_GROUP == 3'b100)
		|| (op `OP_GROUP == 3'b101)
		|| (op == `OPjerr || op == `OPfail || op == `OPex);
endfunction

function opWritesToDst (input `OP op);
	opWritesToDst =
		   (op `OP_LEN == 1'b0)
		|| (op `OP_GROUP == 3'b100)
		|| (op == `OPex);
endfunction

function opIsBranch (input `OP op);
	opIsBranch = (op `OP_GROUP == 3'b101);
endfunction

// Don't fetch any instructions when one of these is already in the pipeline.
// Prevents reading instructions past the end of the program (not really
// harmful in simulation, but nice) and also prevents memory writes from
// instructions immediately following the sys or halt.
function opIsBlocking (input `OP op);
	opIsBlocking = (op == `OPsys || op == `OPfail);
endfunction

// Just for the debug prints because I'm tired of reading hex
function [31:0] opStr (input `OP op); // [31:0] -> 4 bytes (chars)
	case (op)
	`OPxhi: opStr = "xhi"; `OPlhi:  opStr = "lhi"; `OPxlo:  opStr = "xlo";
	`OPllo: opStr = "llo"; `OPadd:  opStr = "add"; `OPsub:  opStr = "sub";
	`OPxor: opStr = "xor"; `OProl:  opStr = "rol"; `OPshr:  opStr = "shr";
	`OPor:  opStr = "or";  `OPand:  opStr = "and"; `OPdup:  opStr = "dup";
	`OPbz : opStr = "bz";  `OPbnz:  opStr = "bnz"; `OPbn:   opStr = "bn";
	`OPbnn: opStr = "bnn"; `OPjerr: opStr = "jerr";`OPfail: opStr = "fail";
	`OPex:  opStr = "ex";  `OPcom:  opStr = "com"; `OPland: opStr = "land";
	`OPnop: opStr = "___"; `OPsys:  opStr = "sys";
	endcase
endfunction

endmodule