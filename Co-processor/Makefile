twiddle:
	iverilog -Wall -I src/ -o build/twiddle_sim src/TwiddleMemory.v tb/TwiddleMemory_tb.v
	./build/twiddle_sim
	gtkwave waves/twiddle_tb.vcd

butterflymem:
	iverilog -Wall -I src/ -o build/butterflymemory_sim src/ButterflyMemory.v tb/ButterflyMemory_tb.v
	./build/butterflymemory_sim
	gtkwave waves/ButterflyMemory_test.vcd

butterflycompute:
	iverilog -Wall -I src/ -o build/butterflycompute_sim src/ButterflyCompute.v tb/ButterflyCompute_tb.v
	./build/butterflycompute_sim
	gtkwave waves/butterflycompute_tb.vcd

butterflyctr:
	iverilog -Wall -I src/ -o build/controller_sim src/Controller.v tb/Controller_tb.v
	./build/controller_sim
	gtkwave waves/Controller_tb.vcd

