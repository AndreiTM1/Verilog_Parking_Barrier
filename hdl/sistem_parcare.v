module sistem_parcare #(parameter NR_TACTE_SENZOR = 8'd20,
                                  TACTE_PER_ORA   = 8'd200,
                                  NR_TOTAL_LOCURI = 15
)(
    //semnale generale
    input                clk_i,
    input                rst_ni,
//semnale APB
    input       [1:0]    paddr_i,              // adresa registrilor
    input                psel_i,               // indica selectia registrului
    input                penable_i,            // semnal enable
    input                pwrite_i,             // se scrie
    input       [7:0]    pwdata_i,             // data care se scrie
    output reg  [7:0]    prdata_o,             // data care se citeste
    output               pready_o,             // semnal ready
// interfata cu stimuli din exterior
    input       [1:0]    btn_i,                // semnal pe 2 biti aferent celor 2 butoane
    input                senzor_proxim_i,      // semnalul de la senzor de proxim
// interfata de iesire
    output               parcare_plina_o,
    output               parcare_goala_o,
    output reg           stare_bariera_o,
    output      [3:0]    nr_locuri_libere_o
);

assign pready_o = 1'b1;

reg  [2:0]   stare_curenta;     // starea din FSM a sistemului
reg  [3:0]   nr_locuri_libere;  // numarul de locuri libere
reg  [7:0]   counter_senzor;    // pragul de tacte pana la urmatoarea citire a senzorului
reg          intrare_iesire;    // daca se intra sau se iese; 1 == intrare, 0 == iesire
reg  [4:0]   ora_curenta;       // ora curenta
reg  [7:0]   counter_ora;       // pragul de tacte pana cand trece o ora simulata
reg  [4:0]   ora_start;         // ora de incepere a functionarii sistemului
reg  [4:0]   ora_stop;          // ora de stop a functionarii sistemului
wire         sistem_activ;      // daca sistemul este in functiune sau nu

assign sistem_activ       = (ora_curenta >= ora_start) && (ora_curenta < ora_stop); // activ doar in intervalul orar
assign nr_locuri_libere_o = nr_locuri_libere;                           // registru trimis la iesire pentru numarul de locuri
assign parcare_goala_o    = (nr_locuri_libere == NR_TOTAL_LOCURI);      // calcul parcare goala
assign parcare_plina_o    = (nr_locuri_libere == 4'd0);                 // calcul parcare plina


localparam IDLE        = 3'b000;        // bariera nu face nimic, asteapta intrare sau iesire
localparam RIDICARE    = 3'b001;        // se ridica
localparam ASTEAPTA    = 3'b010;        // asteapta ca masina sa intre sau sa iese in functie de senzor
localparam COBORARE    = 3'b011;        // coboara
localparam UPDATE      = 3'b100;        // abea la final se actualizeaza numarul de locuri libere

//Logica FSM-ului
always @(posedge clk_i or negedge rst_ni) begin
  if(~rst_ni)
      stare_curenta <= IDLE;    // default e in IDLE
  else begin
      case (stare_curenta)
          IDLE:          // se ridica daca sistemul e activ si daca se intra/iese dintr-o parcare ~plina/~goala  
              if(sistem_activ && ((btn_i == 2'b01 && nr_locuri_libere > 0) 
                    || (btn_i == 2'b10 && nr_locuri_libere < 15)))
                  stare_curenta <= RIDICARE;

          
          RIDICARE:     // trece direct in asteapta dupa un ceas
              stare_curenta <= ASTEAPTA;

          ASTEAPTA:     // se coboara cand senzorul nu mai detecteaza nimic
              if(counter_senzor >= NR_TACTE_SENZOR && ~senzor_proxim_i)
                  stare_curenta <= COBORARE;
          
          COBORARE:     // dupa ce coboara se face update
              stare_curenta <= UPDATE;

          UPDATE:       // dupa ce se face update se duce in idle
              stare_curenta <= IDLE;

          default: stare_curenta <= IDLE;
      endcase
      end
end

// counter_ora numara daca au trecut acele TACTE_PER_ORA pentru a se reseta dupa ce a trecut o ora
always @(posedge clk_i or negedge rst_ni) begin
    if (~rst_ni)
        counter_ora <= 8'd0;
    else if (counter_ora >= TACTE_PER_ORA - 1)
            counter_ora <= 8'd0;
         else counter_ora <= counter_ora + 1;
end

// ora_curenta creste cand au trecut acele TACTE_PER_ORA
always @(posedge clk_i or negedge rst_ni) begin
    if (~rst_ni)
        ora_curenta <= 5'd0;
    else if (counter_ora >= TACTE_PER_ORA - 1)
            if (ora_curenta >= 23)
               ora_curenta <= 5'd0;
            else ora_curenta <= ora_curenta + 1;
end

// se scrie prin APB ora de start si stop
always @(posedge clk_i or negedge rst_ni) begin
    if (~rst_ni)
        ora_start <= 5'd8;
    else if (psel_i && penable_i && pwrite_i && (paddr_i == 2'b10)) 
            ora_start <= pwdata_i[4:0];
end

always @(posedge clk_i or negedge rst_ni) begin
    if (~rst_ni)
        ora_stop <= 5'd22;
    else if (psel_i && penable_i && pwrite_i && (paddr_i == 2'b11)) 
            ora_stop <= pwdata_i[4:0];
end

// bariera este logic ridicata daca este in starea de ridicare sau daca asteapta dupa senzor
always @(posedge clk_i or negedge rst_ni) begin
  if(~rst_ni)
    stare_bariera_o <= 0;
  else if (stare_curenta == RIDICARE || stare_curenta == ASTEAPTA) 
           stare_bariera_o <= 1;
       else if (stare_curenta == COBORARE) 
                stare_bariera_o <= 0;
end

// counter_senzor numara tactele pana la urmatoarea verificare a senzorului de proximitate
always @(posedge clk_i or negedge rst_ni) begin
  if(~rst_ni)
    counter_senzor <= 0;
  else if (stare_curenta == ASTEAPTA)
    counter_senzor <= counter_senzor + 1;
  else counter_senzor <= 0;
end

// nr_locuri_libere creste sau scade in functie de intrarea sau iesirea unei masini
always @(posedge clk_i or negedge rst_ni) begin
  if(~rst_ni)
    nr_locuri_libere <= NR_TOTAL_LOCURI;
  else if (stare_curenta == UPDATE) 
          if (intrare_iesire)
             nr_locuri_libere <= nr_locuri_libere - 1'b1;
          else 
             nr_locuri_libere <= nr_locuri_libere + 1'b1;   
end

// cand bariera e in IDLE, butoanele scriu in btn_i daca se intra sau se iese
always @(posedge clk_i or negedge rst_ni) begin
  if(~rst_ni)
    intrare_iesire <= 0;
  else if (stare_curenta == IDLE)
          if (btn_i == 2'b01) 
             intrare_iesire <= 1;
          else if (btn_i == 2'b10)
                  intrare_iesire <= 0;
end

// se trece in prdata_o ce registrii se scriu in functie de adresa
always @(posedge clk_i or negedge rst_ni) begin
  if (~rst_ni) 
      prdata_o <= 8'd0;
  else if (psel_i && !pwrite_i) begin
      case (paddr_i)
          2'b00: prdata_o <= {3'b0, ora_curenta};          
          2'b01: prdata_o <= {4'b0, nr_locuri_libere};       
          2'b10: prdata_o <= {3'b0, ora_start}; 
          2'b11: prdata_o <= {3'b0, ora_stop}; 
          default: prdata_o <= 8'd0;             
      endcase
  end
end

endmodule