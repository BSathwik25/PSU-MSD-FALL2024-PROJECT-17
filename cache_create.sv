module Cache_create;
	parameter ADDRESS_BITS = 32;
	parameter OFFSET_BITS = 6;
	parameter INDEX_BITS = 14;
	parameter NSETS = 2**14;

typedef struct{
	bit[1:0] mesi_bits;
	bit dirty;
	bit valid;
	bit[11:0] tag_bits; 
}cache_line; //one cache line

typedef struct{
	bit[14:0] plru_bits; //15 pseudo lru bits for each set
	cache_line cache_lines[15:0]; //for 16 way associativity
}cache_set; // one cache set

cache_set cache[NSETS-1:0]; // (2**14) sets of cache

endmodule

