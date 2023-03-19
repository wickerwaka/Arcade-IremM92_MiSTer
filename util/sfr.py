from typing import List

lines = open('docs/v35_sfr.csv', 'rt').readlines()[1:]

class SFR:
    def __init__(self, name, address, reset, word, byte, bit, read, write):
        self.name = name
        self.address = address
        self.reset = reset
        self.word = word
        self.byte = byte
        self.bit = bit
        self.read = read
        self.write = write
    
    def __str__(self) -> str:
        return f"{self.name} @ {self.address:x}"

sfrs : List[SFR] = []
for line in lines:
    p = line.strip().split(',')
    address = int(p[1], 16)
    name = p[3]
    read = False
    write = False
    if p[4] == 'RW':
        read = True
        write = True
    elif p[4] == 'R':
        read = True
    elif p[4] == 'W':
        write = True
    else:
        print( "Unknown access mode" )
    
    word = False
    bit = False
    byte = False
    if p[5] == '16/8':
        word = True
        byte = True
    elif p[5] == '8/1':
        byte = True
        bit = True
    elif p[5] == '8':
        byte = True
    elif p[5] == '16':
        word = True
    else:
        print( "Unknown access unit: ", p[5] )
    reset = None
    if p[6] != 'Undefined':
        reset = int(p[6], 16)
    
    
    s = SFR(name, address, reset, word, byte, bit, read, write)
    sfrs.append(s)
    

print( "// BEGIN Registers")
for sfr in sfrs:
    if sfr.word:
        print( f"reg [15:0] {sfr.name};")
    if sfr.byte:
        print( f"reg [7:0]  {sfr.name};")
print( "// END Registers")

print( "// BEGIN Reset values")
for sfr in sfrs:
    if sfr.reset is None:
        continue

    if sfr.word:
        print( f"{sfr.name} <= 16'h{sfr.reset:04x};" )
    else:
        print( f"{sfr.name} <= 8'h{sfr.reset:02x};" )
print( "// END Reset values")


print( "// BEGIN Reading case")
print( "case(cpu_addr[7:0])")
for sfr in sfrs:
    if not sfr.read:
        continue
    if sfr.word:
        print(f"8'h{sfr.address:02x}: sfr_data <= {sfr.name};")
        print(f"8'h{sfr.address + 1:02x}: sfr_data <= {{ 8'd0, {sfr.name}[15:8] }};")
    elif sfr.byte:
        print(f"8'h{sfr.address:02x}: sfr_data <= {{ 8'd0, {sfr.name} }};")
print( "endcase" )
print( "// End Reading case")

print( "// BEGIN Writing case")
print( "case(cpu_addr[7:0])")
for sfr in sfrs:
    if not sfr.write:
        continue
    if sfr.word:
        print(f"8'h{sfr.address:02x}: begin\n\tif (cpu_be[0]) {sfr.name}[7:0] <= cpu_dout[7:0];\n\tif (cpu_be[1]) {sfr.name}[15:8] <= cpu_dout[15:8];\nend")
        print(f"8'h{sfr.address + 1:02x}: {sfr.name}[15:8] <= cpu_dout[7:0];")
    elif sfr.byte:
        print(f"8'h{sfr.address:02x}: {sfr.name} <= cpu_dout[7:0];")
print( "endcase" )
print( "// End Writing case")



