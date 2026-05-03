twiddle:
	iverilog -Wall -I src/ -o build/twiddle_sim src/TwiddleMemory.v tb/TwiddleMemory_tb.v
	./build/twiddle_sim
	gtkwave waves/twiddle_tb.vcd

butterflymem:
	iverilog -Wall -I src/ -o build/butterflymemory_sim src/ButterflyMemory.v tb/ButterflyMemory_tb.v
	./build/butterflymemory_sim
	gtkwave waves/ButterflyMemory_test.vcd

butterflyctr:
	iverilog -Wall -I src/ -o build/butterflycontroller_sim src/ButterflyController.v tb/ButterflyController_tb.v
	./build/butterflycontroller_sim
	gtkwave waves/ButterflyController_test.vcd

