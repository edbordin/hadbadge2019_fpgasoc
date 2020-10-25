qpimem_iface_testbench:
	iverilog -g2009 -o qpimem_iface_testbench.vvp ../sim/ecp5_io_sim.v qpimem_iface_testbench.v qpimem_iface.v ly68l6400_model.v \
		sim_mt48lc16m16a2.v qpi_sdram_adapter.v wbsdram.v
	vvp qpimem_iface_testbench.vvp

qpimem_interleave_testbench:
	iverilog -o qpimem_interleave_testbench.vvp qpimem_interleave_testbench.v \
			qpimem_iface_intl.v ly68l6400_model.v
	vvp qpimem_interleave_testbench.vvp

qpimem_cache_testbench:
	iverilog -o qpimem_cache_testbench.vvp qpimem_cache_testbench.v qpimem_cache.v simple_mem.v simple_mem_words.v
	vvp qpimem_cache_testbench.vvp

verilator: verilator-build/Vqpitest
	./verilator-build/Vqpitest

verilator-build/Vqpitest: qpimem_cache.v simple_mem.v simple_mem_words.v verilator_top.v verilator_main.cpp ../psram_emu.cpp
	verilator -CFLAGS "-ggdb" --timescale-override "1ns/1ps" --assert --trace --Mdir verilator-build -Wno-style -Wno-fatal -cc --top-module qpitest --exe $^
	make OPT_FAST="-O2 -fno-stack-protector" -C verilator-build -f Vqpitest.mk
