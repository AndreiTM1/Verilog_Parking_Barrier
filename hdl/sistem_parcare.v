module sistem_parcare #(parameter NR_TACTE_SENZOR = 8'd20)(
    input                clk_i,
    input                rst_ni,
    input      [1:0]     paddr_i,
    input                psel_i,
    input                penable_i,
    input                pwrite_i,
    input      [7:0]     pwdata_i,
    output reg [7:0]     prdata_o,
    output               pready_o,

    input      [1:0]     btn_i,
    input                senzor_proxim_i,
    output reg           stare_bariera_o
);

assign pready_o = 1'b1;

reg  [2:0]   stare_curenta;
reg  [3:0]   nr_locuri_libere;
wire [7:0]   x_tacte_ceas = NR_TACTE_SENZOR;
reg  [7:0]   counter;
reg          intrare_iesire; // 1 == intrare, 0 == iesire

localparam IDLE        = 3'b000;
localparam RIDICARE    = 3'b001;
localparam ASTEAPTA    = 3'b010;
localparam COBORARE    = 3'b011;
localparam UPDATE      = 3'b100;

always @(posedge clk_i or negedge rst_ni) begin
  if(~rst_ni)
      stare_curenta <= IDLE;
  else begin
      case (stare_curenta)
          IDLE:
              if((btn_i == 2'b01 && nr_locuri_libere > 0) || (btn_i == 2'b10 && nr_locuri_libere < 15))
                  stare_curenta <= RIDICARE;
          
          RIDICARE:
              stare_curenta <= ASTEAPTA;

          ASTEAPTA:
              if(counter >= x_tacte_ceas && ~senzor_proxim_i)
                  stare_curenta <= COBORARE;
          
          COBORARE:
              stare_curenta <= UPDATE;

          UPDATE:
              stare_curenta <= IDLE;

          default: stare_curenta <= IDLE;
      endcase
      end
end

always @(posedge clk_i or negedge rst_ni) begin
  if(~rst_ni)
    stare_bariera_o <= 0;
  else if (stare_curenta == RIDICARE || stare_curenta == ASTEAPTA) 
           stare_bariera_o <= 1;
       else if (stare_curenta == COBORARE) 
                stare_bariera_o <= 0;
end

always @(posedge clk_i or negedge rst_ni) begin
  if(~rst_ni)
    counter <= 0;
  else if (stare_curenta == ASTEAPTA)
    counter <= counter + 1;
  else counter <= 0;
end

always @(posedge clk_i or negedge rst_ni) begin
  if(~rst_ni)
      nr_locuri_libere <= 4'd10;
  else begin
      if (psel_i && penable_i && pwrite_i && (paddr_i == 2'b01))
          nr_locuri_libere <= pwdata_i[3:0];
      else if (stare_curenta == UPDATE) begin
          if (intrare_iesire)
              nr_locuri_libere <= nr_locuri_libere - 1'b1;
          else 
              nr_locuri_libere <= nr_locuri_libere + 1'b1;
      end
  end
end

always @(posedge clk_i or negedge rst_ni) begin
  if(~rst_ni)
    intrare_iesire <= 0;
  else if (stare_curenta == IDLE)
          if (btn_i == 2'b01) 
             intrare_iesire <= 1;
          else if (btn_i == 2'b10)
                  intrare_iesire <= 0;
end

always @(posedge clk_i or negedge rst_ni) begin
  if (~rst_ni) 
      prdata_o <= 8'd0;
  else if (psel_i && !pwrite_i) begin
      case (paddr_i)
          2'b00: prdata_o <= {6'b0, btn_i};          
          2'b01: prdata_o <= {4'b0, nr_locuri_libere};       
          2'b10: prdata_o <= {6'b0, stare_bariera_o, senzor_proxim_i}; 
          2'b11: prdata_o <= x_tacte_ceas;              
      endcase
  end
end

endmodule