`default_nettype none
// OpCode
`define OpAUX  6'd0
`define OpJR   6'd42
`define OpADDI 6'd1
`define OpLUI  6'd3
`define OpANDI 6'd4
`define OpORI  6'd5
`define OpXORI 6'd6
`define OpLW   6'd16
`define OpSW   6'd24
`define OpBEQ  6'd32
`define OpBNE  6'd33
`define OpBLT  6'd34
`define OpBLE  6'd35
`define OpJ    6'd40
`define OpJAL  6'd41
`define OpHALT 6'd63

// AUX
`define AUXADD 6'd0
`define AUXSUB 6'd2
`define AUXAND 6'd8
`define AUXOR  6'd9
`define AUXXOR 6'd10
`define AUXNOR 6'd11
`define AUXSLL 6'd16
`define AUXSRL 6'd17
`define AUXSRA 6'd18

// Stage
`define StageIF  5'b00001
`define StageRR  5'b00010
`define StageEX  5'b00100
`define StageWB  5'b01000
`define StageHA  5'b11111

// INST_TYPE
`define INST_R 2'b00
`define INST_I 2'b01
`define INST_A 2'b10

module cpu(
  input clk,
  input rst
);

  reg [4:0] stage;

  reg [31:0] pc;

  // Pipeline Registers: IF to RR
  reg [31:0] IFRR_pc, IFRR_instruction;

  // Pipeline Registers: RR to EX
  reg [5:0] RREX_opcode;
  reg [31:0] RREX_pc, RREX_imm;
  reg [31:0] RREX_in1, RREX_in2;
  reg [4:0] RREX_regWriteAddr;
  reg RREX_regWriteFlag;
  reg RREX_haltFlag;

  // Pipeline Registers: EX to WB
  reg [4:0] EXWB_regWriteAddr;
  reg [31:0] EXWB_regWriteData;
  reg EXWB_regWriteFlag;
  reg [31:0] EXWB_npc;
  reg [31:0] EXWB_out;
  reg EXWB_haltFlag;

  // IF stage
  wire [31:0] IF_instruction;
  ICache iCache(
    .clk(clk),
    .r_addr(pc),
    .r_data(IF_instruction)
  ); 

  wire [31:0] ID_imm;
  wire [5:0] ID_opcode;
  wire [4:0] ID_regReadAddr1, ID_regReadAddr2, ID_regWriteAddr;
  wire ID_regReadFlag1, ID_regReadFlag2, ID_regWriteFlag;
  Decoder decoder(
    .clk(clk),
    .rst(rst),
    .instruction(IF_instruction),
    .reg1(ID_regReadAddr1),
    .reg2(ID_regReadAddr2),
    .reg3(ID_regWriteAddr),
    .reg1_flag(ID_regReadFlag1),
    .reg2_flag(ID_regReadFlag2),
    .reg3_flag(ID_regWriteFlag),
    .opcode(ID_opcode),
    .imm(ID_imm)
  );

  wire [31:0] RR_regReadData1, RR_regReadData2;
  Register register(
    .clk(clk),
    .we(EXWB_regWriteFlag),
    .r1_addr(ID_regReadAddr1),
    .r1_data(RR_regReadData1),
    .r2_addr(ID_regReadAddr2),
    .r2_data(RR_regReadData2),
    .w_addr(EXWB_regWriteAddr),
    .w_data(EXWB_regWriteData)
  );

  wire [31:0] EX_aluout, EX_npc;
  reg [31:0] out;
  Alu alu(
    .in1(RREX_in1),
    .in2(RREX_in2),
    .pc(RREX_pc),
    .opcode(RREX_opcode),
    .imm(RREX_imm),
    .out(EX_aluout),
    .npc(EX_npc)
  );

  always @(posedge clk or negedge rst) begin
    if (~rst) begin
      stage <= `StageIF;
      EXWB_regWriteFlag <= 1'b0;
      pc <= 32'd0;
      $display("RST!");
    end else begin
      case (stage)
        `StageIF: begin
          IFRR_pc <= pc;
          IFRR_instruction <= IF_instruction;
          stage <= `StageRR;
          $display("StageIF, pc = %d, ID_regReadAddr = (%d, %d), ID_opcode = %d, ID_imm = %d", pc, ID_regReadAddr1, ID_regReadAddr2, ID_opcode, ID_imm);
          $display("INST = %b", IF_instruction);
        end
        `StageRR: begin
          RREX_pc <= IFRR_pc;
          RREX_opcode <= ID_opcode;
          RREX_imm <= ID_imm;
          RREX_in1 <= RR_regReadData1;
          RREX_in2 <= RR_regReadData2;
          RREX_regWriteAddr <= ID_regWriteAddr;
          RREX_regWriteFlag <= ID_regWriteFlag;
          
          if (ID_opcode == `OpHALT) begin
            RREX_haltFlag = 1'b1;
          end else begin
            RREX_haltFlag = 1'b0;
          end
          stage <= `StageEX;          
          $display("StageRR, rRD1 = %d, rRD2 = %d", RR_regReadData1, RR_regReadData2);
          $display("\tIDRR_regReadAddr1 = %d(%d)", ID_regReadAddr1, ID_regReadFlag1);
          $display("\tIDRR_regReadAddr2 = %d(%d)", ID_regReadAddr2, ID_regReadFlag2);
          $display("\tRREX_regWriteAddr <= %d", ID_regWriteAddr);
        end
        `StageEX: begin
          EXWB_out <= EX_aluout;
          EXWB_regWriteData <= EX_aluout;
          EXWB_npc <= EX_npc;
          EXWB_regWriteAddr <= RREX_regWriteAddr;
          EXWB_regWriteFlag <= RREX_regWriteFlag;
          EXWB_haltFlag <= RREX_haltFlag;
          pc <= EX_npc;
          stage <= `StageWB;
          $display("StageEX, aluout = %d, npc = %d", EX_aluout, EX_npc);
          $display("\tALU opcode = %d, aux = %d, in1 = %d, in2 = %d", alu.opcode,alu.aux,alu.in1,alu.in2);
          $display("\tRREX_regWriteAddr = %d, Flag = %d, Data = %d", RREX_regWriteAddr, RREX_regWriteFlag, EXWB_regWriteData);
        end
        `StageWB: begin
          EXWB_regWriteFlag <= 1'b0;
          if (RREX_haltFlag) begin
            stage <= `StageHA;
          end else begin
            stage <= `StageIF;
          end
          $display("StageWB, NPC = %d", EXWB_npc);
        end
        `StageHA: begin
          $display("StageHA");
          $finish;
        end
      endcase
    end
  end

endmodule

module ICache(clk, r_addr, r_data); 
  input clk;
  input  [31:0] r_addr;
  output [31:0] r_data;
  reg [31:0] addr;
  reg [31:0] mem [0:1023];
  always @(posedge clk) begin
      addr <= {2'b0, r_addr[31:2]}; // ignore the lowest 2 bits
  end
  assign r_data = mem[addr];

  initial begin
    $readmemb("sample/count.bin", mem);
  end

endmodule


module Alu(
  input [31:0] in1, in2,
  input [5:0] opcode,
  input [31:0] imm,
  input [31:0] pc,
  output [31:0] npc,
  output [31:0] out
);

  reg [31:0] out, npc;

  wire [10:0] aux = imm[10:0];
  
  always @* begin
    case (opcode)
      `OpAUX: begin // Type R
        case (aux)
          `AUXADD: // ADD
            out <= in1 + in2;
          `AUXSUB: // SUB
            out <= in1 - in2;
          `AUXAND: // AND
            out <= in1 & in2;
          `AUXOR: // OR
            out <= in1 | in2;
          `AUXXOR: // XOR
            out <= in1 ^ in2;
          `AUXNOR: // NOR
            out <= ~(in1 | in2);
          `AUXSLL: // SLL
            out <= in1 << aux[10:6];
          `AUXSRL: // SRL
            out <= in1 >> aux[10:6];
          `AUXSRA: // SRA
            out <= in1 >>> aux[10:6];  // maybe incorrect
        endcase
        npc <= pc + 4;
      end

      `OpADDI: begin  // ADDI
        out <= in1 + imm;
        npc <= pc + 4;
      end
      `OpLUI: begin // LUI
        out <= imm << 16;
        npc <= pc + 4;
      end
      `OpANDI: begin // ANDI
        out <= in1 & imm;
        npc <= pc + 4;
      end
      `OpORI: begin // ORI
        out <= in1 | imm;
        npc <= pc + 4;
      end
      `OpXORI: begin // XORI
        out <= in1 ^ imm;
        npc <= pc + 4;
      end
      `OpLW: begin // LW
        out <= in1 + imm;
        npc <= pc + 4;
      end
      `OpSW: begin // SW
        out <= in1 + imm;
        npc <= pc + 4;
      end
      `OpBEQ: begin // BEQ
        if (in1 == in2) begin
          npc <= pc + 4 + imm;
        end else begin
          npc <= pc + 4;
        end
      end
      `OpBNE: begin // BNE
        if (in1 != in2) begin
          npc <= pc + 4 + imm;
        end else begin
          npc <= pc + 4;
        end
      end
      `OpBLT: begin // BLT
        if (in1 < in2) begin
          npc <= pc + 4 + imm;
        end else begin
          npc <= pc + 4;
        end
      end
      `OpBLE: begin // BLE
        if (in1 <= in2) begin
          npc <= pc + 4 + imm;
        end else begin
          npc <= pc + 4;
        end
      end
      `OpJ:  begin // J
        npc <= imm;
      end
      `OpJAL: begin // JAL
        out <= pc;
        npc <= imm;
      end
    endcase
  end

endmodule

module Register(clk, we, r1_addr, r1_data, r2_addr, r2_data, w_addr, w_data); 
  input clk, we;
  input  [4:0] r1_addr, r2_addr, w_addr;
  input  [31:0] w_data;
  output [31:0] r1_data, r2_data;
  reg [4:0] addr_reg1, addr_reg2;
  reg [31:0] mem [0:31];
  always @(posedge clk) begin
      if(we) mem[w_addr] <= w_data; //書き込みのタイミングを同期
      addr_reg1 <= r1_addr;         //読み出しアドレスを同期
      addr_reg2 <= r2_addr;
  end
  assign r1_data = addr_reg1 == 5'b0 ? 32'b0 : mem[addr_reg1];
  assign r2_data = addr_reg2 == 5'b0 ? 32'b0 : mem[addr_reg2];

  integer i;
  initial begin
    //for (i = 0; i < 32; i += 1) begin
    //  mem[i] <= i;
    //end
  end
  always @(posedge clk) begin
    //$display("!!!!addr_reg1 = %d, r1_addr = %d", addr_reg1, r1_addr);
    for (i = 0; i < 10; i += 1) begin
      $display("mem[%d] = %d", i, mem[i]);
    end
  end
endmodule

module Decoder(
  input clk, rst,
  input [31:0] instruction,
  output [4:0] reg1, reg2, reg3,
  output reg1_flag, reg2_flag, reg3_flag,
  output [5:0] opcode,
  output [31:0] imm
);

  reg [4:0] reg1, reg2, reg3;
  reg reg1_flag, reg2_flag, reg3_flag;
  reg [31:0] imm;
  wire [4:0] rs, rt, rd;

  assign opcode = instruction[31:26];
  assign rs = instruction[25:21];
  assign rt = instruction[20:16];
  assign rd = instruction[15:11];

  wire [1:0] inst_type;
  assign inst_type =
    (opcode == `OpAUX || opcode == `OpJR) ? `INST_R :
    (opcode == `OpJ || opcode == `OpJAL || opcode == `OpHALT) ? `INST_A :
    `INST_I;
  

  always @(*) begin
    case (inst_type)
      `INST_R: begin
        if (opcode != `OpJR) begin
          imm = {21'b0, instruction[10:0]};
          reg1 = rs;
          reg2 = rt;
          reg3 = rd;
          reg1_flag = 1;
          reg2_flag = 1;
          reg3_flag = 1;
        end else begin // OpJR
          reg1 = rs;
          reg1_flag = 1;
          reg2_flag = 0;
          reg3_flag = 0;
        end
      end
        
      `INST_I: begin
        imm = {16'b0, instruction[15:0]};
        reg1 = rs;
        reg3 = rt;
        reg1_flag = 1;
        reg2_flag = 0;
        reg3_flag = 1;
      end
      
      `INST_A: begin
        imm = {6'b0, instruction[25:0]};
        reg1_flag = 0;
        reg2_flag = 0;
        if (opcode == `OpJAL) begin
          reg3 = 5'd31;
          reg3_flag = 1;
        end else begin
          reg3_flag = 0;
        end
        
      end
    endcase
  end  
endmodule
