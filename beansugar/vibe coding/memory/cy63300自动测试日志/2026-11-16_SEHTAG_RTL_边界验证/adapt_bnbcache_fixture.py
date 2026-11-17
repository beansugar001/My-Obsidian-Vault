
from pathlib import Path
import sys
root=Path(sys.argv[1])
s=(root/'tb/bnbcache_tb.v').read_text()
s=s.replace("module bnbcache_tb;", "module bnbcache_compat_tb;\n    reg lookup_write_bound = 0;")
s=s.replace('.lookup_ptr_id_i(lookup_ptr_id_i),', '''.lookup_ptr_id_i(lookup_ptr_id_i),
        .bnb_lookup_wt(lookup_write_bound),
        .exec_index_addr_i(5'd0),
        .alloc_req_i(1'b0),
        .alloc_ptr_id_i(32'd0),
        .ptr_freed_i(1'b0),
        .ptr_gen_i(16'd0),
        .ptr_query_en_i(1'b0),''')
s=s.replace("        #10;\n        lookup_we_i = ",'        #10;\n        lookup_write_bound = 1;\n        #10;\n        lookup_we_i = ',1)
s=s.replace('bnbcache_tb.vcd', 'bnbcache_compat.vcd').replace('$dumpvars(0, bnbcache_tb)', '$dumpvars(0, bnbcache_compat_tb)')
Path("bnbcache_compat_tb.v").write_text(s)

