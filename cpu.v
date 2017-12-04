`default_nettype none

`define TRUE  1'b1
`define FALSE 1'b0

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
`define StageIF 5'b00001
`define StageRR 5'b00010
`define StageEX 5'b00100
`define StageMA 5'b01000
`define StageWB 5'b10000
`define StageHA 5'b11111

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
  reg RREX_loadFlag;
  reg RREX_storeFlag;

  // Pipeline Registers: EX to MA
  reg [4:0] EXMA_regWriteAddr;
  reg [31:0] EXMA_regWriteData;
  reg EXMA_regWriteFlag;
  reg [31:0] EXMA_npc;
  reg [31:0] EXMA_out;
  reg EXMA_haltFlag;
  reg EXMA_loadFlag;
  reg EXMA_storeFlag;
  reg [31:0] EXMA_storeData;

  // Pipeline Registers: MA to WB
  reg [4:0] MAWB_regWriteAddr;
  reg [31:0] MAWB_regWriteData;
  reg MAWB_regWriteFlag;
  reg [31:0] MAWB_npc;
  reg [31:0] MAWB_out;
  reg MAWB_haltFlag;

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
  wire ID_loadFlag, ID_storeFlag;
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
    .imm(ID_imm),
    .load_flag(ID_loadFlag),
    .store_flag(ID_storeFlag)
  );

  // RR stage
  wire [31:0] RR_regReadData1, RR_regReadData2;
  Register register(
    .clk(clk),
    .we(MAWB_regWriteFlag),
    .r1_addr(ID_regReadAddr1),
    .r1_data(RR_regReadData1),
    .r2_addr(ID_regReadAddr2),
    .r2_data(RR_regReadData2),
    .w_addr(MAWB_regWriteAddr),
    .w_data(MAWB_regWriteData)
  );

  // EX Stage
  wire [31:0] EX_aluout, EX_npc;
  reg [31:0] out;
  ALU alu(
    .in1(RREX_in1),
    .in2(RREX_in2),
    .pc(RREX_pc),
    .opcode(RREX_opcode),
    .imm(RREX_imm),
    .out(EX_aluout),
    .npc(EX_npc)
  );

  // MA Stage
  wire [31:0] MA_memReadData;
  DCache dCache(
    .clk(clk),
    .r_addr(EX_aluout),
    .r_data(MA_memReadData),
    .we(EXMA_storeFlag),
    .w_addr(EXMA_out),
    .w_data(EXMA_storeData)
  );

  always @(posedge clk or negedge rst) begin
    if (~rst) begin
      stage <= `StageIF;
      MAWB_regWriteFlag <= `FALSE;
      EXMA_storeFlag <= `FALSE;
      pc <= 32'd0;
      $display("RST!");
    end else begin
      case (stage)
        `StageIF: begin
          MAWB_regWriteFlag <= `FALSE;
          IFRR_pc <= pc;
          IFRR_instruction <= IF_instruction;
          stage <= `StageRR;
        end
        `StageRR: begin
          RREX_pc <= IFRR_pc;
          RREX_opcode <= ID_opcode;
          RREX_imm <= ID_imm;
          RREX_in1 <= RR_regReadData1;
          RREX_in2 <= RR_regReadData2;
          RREX_regWriteAddr <= ID_regWriteAddr;
          RREX_regWriteFlag <= ID_regWriteFlag;
          RREX_loadFlag <= ID_loadFlag;
          RREX_storeFlag <= ID_storeFlag;
          
          if (ID_opcode == `OpHALT) begin
            RREX_haltFlag = `TRUE;
          end else begin
            RREX_haltFlag = `FALSE;
          end
          stage <= `StageEX;          
        end
        `StageEX: begin
          EXMA_out <= EX_aluout;
          EXMA_regWriteData <= EX_aluout;
          EXMA_npc <= EX_npc;
          EXMA_regWriteAddr <= RREX_regWriteAddr;
          EXMA_regWriteFlag <= RREX_regWriteFlag;
          EXMA_haltFlag <= RREX_haltFlag;
          EXMA_storeData <= RREX_in2;
          EXMA_loadFlag <= RREX_loadFlag;
          EXMA_storeFlag <= RREX_storeFlag;
          stage <= `StageMA;
        end
        `StageMA: begin
          MAWB_regWriteAddr <= EXMA_regWriteAddr;
          if (EXMA_loadFlag) begin
            MAWB_regWriteData <= MA_memReadData;
          end else begin
            MAWB_regWriteData <= EXMA_regWriteData;
          end
          MAWB_regWriteFlag <= EXMA_regWriteFlag;
          MAWB_out <= EXMA_out;
          MAWB_haltFlag <= EXMA_haltFlag;
          pc <= EXMA_npc;
          stage <= `StageWB;
        end
        `StageWB: begin
          EXMA_storeFlag <= `FALSE;
          if (MAWB_haltFlag) begin
            stage <= `StageHA;
          end else begin
            stage <= `StageIF;
          end
        end
        `StageHA: begin
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
    //$readmemb("sample/all.bin", mem);
    $readmemb("sample/montecarlo.bin", mem);
  end

endmodule


module ALU(
  input [31:0] in1, in2,
  input [5:0] opcode,
  input [31:0] imm,
  input [31:0] pc,
  output [31:0] npc,
  output [31:0] out
);

  reg [31:0] out, npc;

  wire [10:0] aux;
  assign aux = imm[10:0];
  
  always @* begin
    case (opcode)
      `OpAUX: begin // Type R
        case (aux[5:0])
          `AUXADD: begin
            out = in1 + in2;
          end
          `AUXSUB: begin
            out = in1 - in2;
          end
          `AUXAND: begin
            out = in1 & in2;
          end
          `AUXOR: begin
            out = in1 | in2;
          end
          `AUXXOR: begin
            out = in1 ^ in2;
          end
          `AUXNOR: begin
            out = ~(in1 | in2);
          end
          `AUXSLL: begin
            out = in1 << aux[10:6];
          end
          `AUXSRL: begin
            out = in1 >> aux[10:6];
          end
          `AUXSRA: begin
            out = $signed({1'b0, in1}) >>> aux[10:6];
          end
          default: begin
            out = 32'd0;
          end

        endcase
        npc = pc + 4;
      end

      `OpADDI: begin  // ADDI
        out = in1 + imm;
        npc = pc + 4;
      end
      `OpLUI: begin // LUI
        out = imm << 16;
        npc = pc + 4;
      end
      `OpANDI: begin // ANDI
        out = in1 & imm;
        npc = pc + 4;
      end
      `OpORI: begin // ORI
        out = in1 | imm;
        npc = pc + 4;
      end
      `OpXORI: begin // XORI
        out = in1 ^ imm;
        npc = pc + 4;
      end
      `OpLW: begin // LW
        out = in1 + imm;
        npc = pc + 4;
      end
      `OpSW: begin // SW
        out = in1 + imm;
        npc = pc + 4;
      end
      `OpBEQ: begin // BEQ
        if (in1 == in2) begin
          npc = pc + 4 + imm;
        end else begin
          npc = pc + 4;
        end
      end
      `OpBNE: begin // BNE
        if (in1 != in2) begin
          npc = pc + 4 + imm;
        end else begin
          npc = pc + 4;
        end
      end
      `OpBLT: begin // BLT
        if (in1 < in2) begin
          npc = pc + 4 + imm;
        end else begin
          npc = pc + 4;
        end
      end
      `OpBLE: begin // BLE
        if (in1 <= in2) begin
          npc = pc + 4 + imm;
        end else begin
          npc = pc + 4;
        end
      end
      `OpJ:  begin // J
        npc = imm;
      end
      `OpJAL: begin // JAL
        out = pc + 4;
        npc = imm;
      end
      `OpJR: begin // JR
        npc = in1;
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
    if(we) begin
      mem[w_addr] <= w_data; //書き込みのタイミングを同期
    end
    addr_reg1 <= r1_addr;         //読み出しアドレスを同期
    addr_reg2 <= r2_addr;
  end
  assign r1_data = addr_reg1 == 5'b0 ? 32'b0 : mem[addr_reg1];
  assign r2_data = addr_reg2 == 5'b0 ? 32'b0 : mem[addr_reg2];
endmodule

module Decoder(
  input clk, rst,
  input [31:0] instruction,
  output [4:0] reg1, reg2, reg3,
  output reg1_flag, reg2_flag, reg3_flag,
  output [5:0] opcode,
  output [31:0] imm,
  output load_flag, store_flag
);

  reg [4:0] reg1, reg2, reg3;
  reg reg1_flag, reg2_flag, reg3_flag;
  reg [31:0] imm;
  wire [4:0] rs, rt, rd;
  wire [10:0] aux;

  assign opcode = instruction[31:26];
  assign aux = instruction[10:0];
  assign rs = instruction[25:21];
  assign rt = instruction[20:16];
  assign rd = instruction[15:11];

  wire [1:0] inst_type;
  assign inst_type =
    (opcode == `OpAUX || opcode == `OpJR) ? `INST_R :
    (opcode == `OpJ || opcode == `OpJAL || opcode == `OpHALT) ? `INST_A :
    `INST_I;

  assign load_flag = (opcode == `OpLW) ? `TRUE : `FALSE;
  assign store_flag = (opcode == `OpSW) ? `TRUE : `FALSE;

  always @(*) begin
    case (inst_type)
      `INST_R: begin
        if (opcode == `OpJR) begin
          reg1 = rs;
          reg1_flag = `TRUE;
          reg2_flag = `FALSE;
          reg3_flag = `FALSE;
        end else begin
          reg1 = rs;
          reg2 = rt;
          reg3 = rd;
          reg1_flag = `TRUE;
          reg2_flag = `TRUE;
          reg3_flag = `TRUE;
          imm = {21'b0, instruction[10:0]};
        end
      end
        
      `INST_I: begin
        case (opcode)
          `OpADDI, `OpLUI, `OpANDI, `OpORI, `OpXORI, `OpLW: begin
            reg1 = rs;
            reg3 = rt;
            reg1_flag = `TRUE;
            reg2_flag = `FALSE;
            reg3_flag = `TRUE;
          end
          `OpSW, `OpBEQ, `OpBNE, `OpBLT, `OpBLE: begin
            reg1 = rs;
            reg2 = rt;
            reg1_flag = `TRUE;
            reg2_flag = `TRUE;
            reg3_flag = `FALSE;
          end
        endcase

        case (opcode)
          `OpLUI, `OpANDI, `OpORI, `OpXORI: begin
            imm = {16'b0, instruction[15:0]};
          end
          default: begin
            imm = {{16{instruction[15]}}, instruction[15:0]};
          end
        endcase
      end
      
      `INST_A: begin
        imm = {{6{instruction[25]}}, instruction[25:0]};
        reg1_flag = `FALSE;
        reg2_flag = `FALSE;
        if (opcode == `OpJAL) begin
          reg3 = 5'd31;
          reg3_flag = `TRUE;
        end else begin
          reg3_flag = `FALSE;
        end
        
      end
    endcase
  end  
endmodule

module DCache(
  input clk,
  input  [31:0] r_addr,
  output [31:0] r_data,
  input         we,
  input  [31:0] w_addr,
  input  [31:0] w_data
);
  reg [31:0] rAddr;
  reg [31:0] mem [0:4095];
  always @(posedge clk) begin
      rAddr <= {2'b0, r_addr[31:2]}; // ignore the lowest 2 bits
      if (we) mem[{2'b0, w_addr[31:2]}] <= w_data;
  end
  assign r_data = mem[rAddr];
endmodule
