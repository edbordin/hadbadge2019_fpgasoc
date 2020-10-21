module clk_8_250_125_25(input clki, 
    output clks1,
    output clks2,
    output locked,
    output clko
);
wire clkfb;
wire clkos;
wire clkop;
(* FREQUENCY_PIN_CLKI="25" *)
(* FREQUENCY_PIN_CLKOP="45.83" *)
(* FREQUENCY_PIN_CLKOS="252.083" *)
(* FREQUENCY_PIN_CLKOS2="126.042" *)
(* FREQUENCY_PIN_CLKOS3="25.21" *)
(* ICP_CURRENT="12" *)
(* LPF_RESISTOR="8" *)
(* MFG_ENABLE_FILTEROPAMP="1" *)
(* MFG_GMCREF_SEL="2" *)
EHXPLLL #(
        .PLLRST_ENA("DISABLED"),
        .INTFB_WAKE("DISABLED"),
        .STDBY_ENABLE("DISABLED"),
        .DPHASE_SOURCE("DISABLED"),
        .OUTDIVIDER_MUXA("DIVA"),
        .OUTDIVIDER_MUXB("DIVB"),
        .OUTDIVIDER_MUXC("DIVC"),
        .OUTDIVIDER_MUXD("DIVD"),
        .CLKI_DIV(6),
        .CLKOP_ENABLE("ENABLED"),
        .CLKOP_DIV(11),
        .CLKOP_CPHASE(9),
        .CLKOP_FPHASE(0),
        .CLKOS_ENABLE("ENABLED"),
        .CLKOS_DIV(2),
        .CLKOS_CPHASE(9),
        .CLKOS_FPHASE(0),
        .CLKOS2_ENABLE("ENABLED"),
        .CLKOS2_DIV(4),
        .CLKOS2_CPHASE(9),
        .CLKOS2_FPHASE(0),
        .CLKOS3_ENABLE("ENABLED"),
        .CLKOS3_DIV(20),
        .CLKOS3_CPHASE(9),
        .CLKOS3_FPHASE(0),
        .FEEDBK_PATH("INT_OP"),
        .CLKFB_DIV(11),        
    ) pll_i (
        .CLKI(clki),
        .CLKFB(clkfb),
        .CLKINTFB(clkfb),
        .CLKOP(),
        .CLKOS(clko),
        .CLKOS2(clks1),
        .CLKOS3(clks2),
        .RST(1'b0),
        .STDBY(1'b0),
        .PHASESEL0(1'b0),
        .PHASESEL1(1'b0),
        .PHASEDIR(1'b0),
        .PHASESTEP(1'b0),
        .PLLWAKESYNC(1'b0),
        .ENCLKOP(1'b0),
        .LOCK(locked)
	);
// assign clko = clkop;
endmodule
