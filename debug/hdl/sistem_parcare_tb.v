`timescale 1ns/1ps

module sistem_parcare_tb;

    reg clk_i, rst_ni, psel_i, penable_i, pwrite_i, senzor_proxim_i;
    reg [1:0] paddr_i, btn_i;
    reg [7:0] pwdata_i;
    wire [7:0] prdata_o;
    wire pready_o, stare_bariera_o;
    wire [3:0] nr_locuri_libere_o;

    // Instantiere DUT cu parametri redusi pentru simulare rapida
    // 1 ora = 100 tacte. 100 tacte * 10ns = 1000ns per ora simulata.
    sistem_parcare #(.NR_TACTE_SENZOR(8'd10), .TACTE_PER_ORA(8'd100), .NR_TOTAL_LOCAURI(8'd15)) dut (
        .clk_i(clk_i), .rst_ni(rst_ni), .paddr_i(paddr_i), .psel_i(psel_i),
        .penable_i(penable_i), .pwrite_i(pwrite_i), .pwdata_i(pwdata_i),
        .prdata_o(prdata_o), .pready_o(pready_o), .btn_i(btn_i),
        .senzor_proxim_i(senzor_proxim_i), .stare_bariera_o(stare_bariera_o), .nr_locuri_libere_o(nr_locuri_libere_o)
    );

    // Ceas 100MHz
    always #5 clk_i = ~clk_i;

    // Task pentru citire APB
    task apb_read_check(input [1:0] addr, input [7:0] expected_data);
        begin
            @(posedge clk_i);
            paddr_i   <= addr; 
            pwrite_i  <= 0;      
            psel_i    <= 1;
            penable_i <= 0;      
            
            @(posedge clk_i);
            penable_i <= 1;      
            
            @(posedge clk_i);
            if (prdata_o === expected_data) begin
                $display("[%t] [PASS] Adresa %b | Citit: %h | Corect!", $time, addr, prdata_o);
            end else begin
                $display("[%t] [FAIL] Adresa %b | Citit: %h | Asteptat: %h !!!", $time, addr, prdata_o, expected_data);
            end
            
            psel_i    <= 0; 
            penable_i <= 0;
            paddr_i   <= 2'bxx; 
        end
    endtask

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

    // Task pentru trecere masina
    task trecere_masina(input [1:0] tip);
        begin
            btn_i = tip;
            wait(stare_bariera_o == 1);
            #20 btn_i = 2'b00;
            #50 senzor_proxim_i = 1;
            #150 senzor_proxim_i = 0;
            wait(stare_bariera_o == 0);
            #100; 
        end
    endtask

    integer i;

    initial begin
        // 1. Initializare si Reset
        clk_i = 0; rst_ni = 0; psel_i = 0; penable_i = 0; 
        pwrite_i = 0; btn_i = 0; senzor_proxim_i = 0;
        #33 rst_ni = 1;

        // 2. Configurare Interval Orar via APB (Start: 05, Stop: 20)
        apb_write(2'b10, 8'd5);
        apb_write(2'b11, 8'd20);
        $display("[%t] Configurat program: 05:00 - 20:00", $time);

        // 3. Asteptam sa treaca timpul pana la ora 5 (5 ore * 100 tacte * 10ns = 5000ns)
        wait(dut.ora_curenta == 5);
        $display("[%t] S-a facut ora 05:00. Parcarea se deschide.", $time);

        // 4. Intra 10 masini (Parcarea are 10 locuri libere la inceput)
        $display("[%t] Incep sa intre 10 masini...", $time);
        for (i = 0; i < 15; i = i + 1) begin
            trecere_masina(2'b01);
            $display("Masina %0d a intrat. Locuri: %0d", i+1, dut.nr_locuri_libere);
        end

        apb_read_check(2'b01, 8'd0); 
        
        apb_read_check(2'b10, 8'd5);

        // 5. Ies 3 masini
        $display("[%t] Ies 3 masini...", $time);
        repeat(3) trecere_masina(2'b10);
        $display("Dupa iesiri, locuri libere: %0d", dut.nr_locuri_libere);

        // 6. Mai intra 5 masini (Verificam umplerea si blocarea)
        $display("[%t] Mai intra 5 masini...", $time);
        for (i = 0; i < 5; i = i + 1) begin
            if (dut.nr_locuri_libere > 0) begin
                trecere_masina(2'b01);
                $display("Masina a intrat. Locuri ramase: %0d", dut.nr_locuri_libere);
            end else begin
                $display("Parcare PLINA! Masina nu mai poate intra.");
            end
        end

        // 7. Verificare ora de inchidere (Ora 20:00)
        // Fortam trecerea timpului pana la ora 20
        wait(dut.ora_curenta == 20);
        $display("[%t] S-a facut ora 20:00. Parcarea s-a inchis.", $time);
        
        btn_i = 2'b01; // Incercam sa intram dupa program
        #200;
        if (stare_bariera_o == 0)
            $display("[%t] OK: Bariera a ramas jos dupa ora de inchidere.", $time);
        else
            $display("[%t] EROARE: Bariera s-a deschis dupa program!", $time);
        
        btn_i = 2'b00;
        #500;
        $stop;
    end

endmodule