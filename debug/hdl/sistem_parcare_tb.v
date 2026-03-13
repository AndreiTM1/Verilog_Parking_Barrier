`timescale 1ns/1ps

module sistem_parcare_tb;

    reg clk_i, rst_ni, psel_i, penable_i, pwrite_i, senzor_proxim_i;
    reg [1:0] paddr_i, btn_i;
    reg [7:0] pwdata_i;
    wire [7:0] prdata_o;
    wire pready_o, stare_bariera_o;

    // Instantierea DUT cu un parametru de 10 tacte pentru testare rapida
    sistem_parcare #(.NR_TACTE_SENZOR(8'd10)) dut (
        .clk_i(clk_i), .rst_ni(rst_ni), .paddr_i(paddr_i), .psel_i(psel_i),
        .penable_i(penable_i), .pwrite_i(pwrite_i), .pwdata_i(pwdata_i), .prdata_o(prdata_o),
        .pready_o(pready_o), .btn_i(btn_i), .senzor_proxim_i(senzor_proxim_i), .stare_bariera_o(stare_bariera_o)
    );

    always #5 clk_i = ~clk_i;

    // Task pentru scriere APB
    task apb_write(input [1:0] addr, input [7:0] data);
        begin
            @(posedge clk_i);
            paddr_i <= addr; pwdata_i <= data; pwrite_i <= 1; psel_i <= 1;
            @(posedge clk_i);
            penable_i <= 1;
            @(posedge clk_i);
            psel_i <= 0; penable_i <= 0; pwrite_i <= 0;
        end
    endtask

    // Task pentru citire APB si verificare rezultat
    task apb_read_check(input [1:0] addr, input [7:0] expected_val, input [127:0] msg);
        begin
            @(posedge clk_i);
            paddr_i <= addr; pwrite_i <= 0; psel_i <= 1;
            @(posedge clk_i);
            penable_i <= 1;
            @(posedge clk_i);
            if (prdata_o !== expected_val)
                $display("[ERROR] %0s | Citit: %h | Asteptat: %h la timp %t", msg, prdata_o, expected_val, $time);
            else
                $display("[OK] %0s | Valoare: %h", msg, prdata_o);
            @(posedge clk_i);
            psel_i <= 0; penable_i <= 0;
        end
    endtask

    task trecere_masina(input [1:0] tip);
        begin
            btn_i = tip;
            wait(stare_bariera_o == 1);
            #15 btn_i = 2'b00;
            #20 senzor_proxim_i = 1;
            #150 senzor_proxim_i = 0; // Trebuie sa fie mai mare decat NR_TACTE_SENZOR * clk
            wait(stare_bariera_o == 0);
            $display("Masina a trecut complet.");
        end
    endtask

    initial begin
        // --- 1. Reset si Initializare ---
        clk_i = 0; rst_ni = 0; psel_i = 0; penable_i = 0; 
        pwrite_i = 0; btn_i = 0; senzor_proxim_i = 0;
        #33 rst_ni = 1;
        $display("--- Start Teste Complexe ---");

        // --- 2. Test Citire Parametru X (Address 2'b11) ---
        apb_read_check(2'b11, 8'd10, "Verificare Parametru X");

        // --- 3. Test Umplere Parcare Manuala via APB ---
        // Fortam 1 loc liber prin APB pentru a testa limita
        apb_write(2'b01, 8'd1);
        apb_read_check(2'b01, 8'd1, "Verificare setare manuala locuri");

        // --- 4. Intrare masina (Parcarea devine plina) ---
        trecere_masina(2'b01);
        apb_read_check(2'b01, 8'd0, "Verificare parcare plina (0 locuri)");

        // --- 5. Test Incercare Intrare cand e PLIN (Ar trebui sa ignore) ---
        btn_i = 2'b01;
        #100;
        if (stare_bariera_o == 1) 
            $display("[ERROR] Bariera s-a ridicat desi parcarea e plina!");
        else 
            $display("[OK] Bariera a ramas jos la parcare plina.");
        btn_i = 2'b00;

        // --- 6. Test Iesire masina ---
        trecere_masina(2'b10);
        apb_read_check(2'b01, 8'd1, "Verificare loc eliberat");

        // --- 7. Test Butoane apasate simultan (Ignore) ---
        btn_i = 2'b11;
        #50;
        if (stare_bariera_o == 0) $display("[OK] 11 ignorat corect.");
        else $display("[ERROR] 11 a ridicat bariera!");
        btn_i = 2'b00;

        $display("--- Final Teste. Status final locuri: %d ---", dut.nr_locuri_libere);
        #100;
        $stop;
    end

endmodule