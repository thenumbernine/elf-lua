#!/usr/bin/env luajit
-- port of
-- https://github.com/Zard-C/libelf_examples/blob/main/src/getting_started.c
-- https://github.com/Zard-C/libelf_examples/blob/main/src/print_elf_header.c
-- https://github.com/Zard-C/libelf_examples/blob/main/src/read_header_table.c
-- https://atakua.org/old-wp/wp-content/uploads/2015/03/libelf-by-example-20100112.pdf

local ffi = require 'ffi'
local assert = require 'ext.assert'
local path = require 'ext.path'
local elf = require 'ffi.req' 'elf'
local tolua = require 'ext.tolua'
require 'ffi.req' 'c.fcntl'

local nameForPType = {
	[elf.PT_NULL] = 'PT_NULL',
	[elf.PT_LOAD] = 'PT_LOAD',
	[elf.PT_DYNAMIC] = 'PT_DYNAMIC',
	[elf.PT_INTERP] = 'PT_INTERP',
	[elf.PT_NOTE] = 'PT_NOTE',
	[elf.PT_SHLIB] = 'PT_SHLIB',
	[elf.PT_PHDR] = 'PT_PHDR',
	[elf.PT_TLS] = 'PT_TLS',
	[elf.PT_NUM] = 'PT_NUM',
	[elf.PT_LOOS] = 'PT_LOOS',
	[elf.PT_GNU_EH_FRAME] = 'PT_GNU_EH_FRAME',
	[elf.PT_GNU_STACK] = 'PT_GNU_STACK',
	[elf.PT_GNU_RELRO] = 'PT_GNU_RELRO',
	[elf.PT_GNU_PROPERTY] = 'PT_GNU_PROPERTY',
	[elf.PT_GNU_SFRAME] = 'PT_GNU_SFRAME',
	[elf.PT_LOSUNW] = 'PT_LOSUNW',
	[elf.PT_SUNWBSS] = 'PT_SUNWBSS',
	[elf.PT_SUNWSTACK] = 'PT_SUNWSTACK',
	[elf.PT_HISUNW] = 'PT_HISUNW',
	[elf.PT_HIOS] = 'PT_HIOS',
	[elf.PT_LOPROC] = 'PT_LOPROC',
	[elf.PT_HIPROC] = 'PT_HIPROC',
	[elf.PT_MIPS_REGINFO] = 'PT_MIPS_REGINFO',
	[elf.PT_MIPS_RTPROC] = 'PT_MIPS_RTPROC',
	[elf.PT_MIPS_OPTIONS] = 'PT_MIPS_OPTIONS',
	[elf.PT_MIPS_ABIFLAGS] = 'PT_MIPS_ABIFLAGS',
	[elf.PT_HP_TLS] = 'PT_HP_TLS',
	[elf.PT_HP_CORE_NONE] = 'PT_HP_CORE_NONE',
	[elf.PT_HP_CORE_VERSION] = 'PT_HP_CORE_VERSION',
	[elf.PT_HP_CORE_KERNEL] = 'PT_HP_CORE_KERNEL',
	[elf.PT_HP_CORE_COMM] = 'PT_HP_CORE_COMM',
	[elf.PT_HP_CORE_PROC] = 'PT_HP_CORE_PROC',
	[elf.PT_HP_CORE_LOADABLE] = 'PT_HP_CORE_LOADABLE',
	[elf.PT_HP_CORE_STACK] = 'PT_HP_CORE_STACK',
	[elf.PT_HP_CORE_SHM] = 'PT_HP_CORE_SHM',
	[elf.PT_HP_CORE_MMF] = 'PT_HP_CORE_MMF',
	[elf.PT_HP_PARALLEL] = 'PT_HP_PARALLEL',
	[elf.PT_HP_FASTBIND] = 'PT_HP_FASTBIND',
	[elf.PT_HP_OPT_ANNOT] = 'PT_HP_OPT_ANNOT',
	[elf.PT_HP_HSL_ANNOT] = 'PT_HP_HSL_ANNOT',
	[elf.PT_HP_STACK] = 'PT_HP_STACK',
	[elf.PT_PARISC_ARCHEXT] = 'PT_PARISC_ARCHEXT',
	[elf.PT_PARISC_UNWIND] = 'PT_PARISC_UNWIND',
	[elf.PT_ARM_EXIDX] = 'PT_ARM_EXIDX',
	[elf.PT_AARCH64_MEMTAG_MTE] = 'PT_AARCH64_MEMTAG_MTE',
	[elf.PT_IA_64_ARCHEXT] = 'PT_IA_64_ARCHEXT',
	[elf.PT_IA_64_UNWIND] = 'PT_IA_64_UNWIND',
	[elf.PT_IA_64_HP_OPT_ANOT] = 'PT_IA_64_HP_OPT_ANOT',
	[elf.PT_IA_64_HP_HSL_ANOT] = 'PT_IA_64_HP_HSL_ANOT',
	[elf.PT_IA_64_HP_STACK] = 'PT_IA_64_HP_STACK',
	[elf.PT_RISCV_ATTRIBUTES] = 'PT_RISCV_ATTRIBUTES',
}

local filename = assert((...), "expected filename")

print('elf version', elf.elf_version(elf.EV_CURRENT))

local elfdatastr = assert(path(filename):read())	-- as str
local elfdataptr = ffi.cast('uint8_t*', elfdatastr)

local e = assert.ne(elf.elf_memory(elfdataptr, #elfdatastr), ffi.null, 'elf_memory')

local ek = elf.elf_kind(e)
print('ek', ek)

if ek == elf.ELF_K_AR then
	print'ar(1) archive'
elseif ek == elf.ELF_K_ELF then
	print'elf object'
elseif ek == elf.ELF_K_NONE then
	print'data'
else
	print'unrecognized'
end

local function elferror(msg)
	error((msg and (msg..' ') or '')..ffi.string(elf.elf_errmsg(-1)))
end

local function elfasserteq(a, b, msg)
	if a ~= b then elferror((msg and (msg..' ') or '')..': expected '..tolua(a)..' == '..tolua(b)) end
	return a, b, msg
end

local function elfassertne(a, b, msg)
	if a == b then elferror((msg and (msg..' ') or '')..': expected '..tolua(a)..' ~= '..tolua(b)) end
	return a, b, msg
end


assert.eq(ek, elf.ELF_K_ELF, 'must be an ELF object')
	
local ehdr = ffi.new'GElf_Ehdr[1]'
elfassertne(elf.gelf_getehdr(e, ehdr), ffi.null, 'gelf_getehdr')

local i = elfassertne(elf.gelf_getclass(e), elf.ELFCLASSNONE, 'gelf_getclass')

print((i == elf.ELFCLASS32 and '32' or '64')..'-bit ELF object')

local id = elfassertne(elf.elf_getident(e, ffi.null), ffi.null, 'elf_getident')

print('   e_ident[0..'..elf.EI_ABIVERSION..']')
for i=0,elf.EI_ABIVERSION-1 do
	print(' ['..tolua(string.char(id[i]))..' '..id[i]..']')
end

local function inttohex(x)
	return tostring(ffi.cast('void*', x)):match'^cdata<void %*>: (.*)'
end

local function writeField(ptr, field)
	io.write('\t', field, '\t', inttohex(ptr[field]))	-- cast to ptr for quick hex intptr_t formatting
end
local function printField(...)
	writeField(...)
	print()
end

print()
print'Elf header'
for _,field in ipairs{
	'e_type', 'e_machine', 'e_version', 'e_entry', 'e_phoff', 'e_shoff', 'e_flags',
	'e_ehsize', 'e_phentsize', 'e_phnum', 'e_shentsize', 'e_shnum', 'e_shstrndx'
} do
	printField(ehdr[0], field)
end

local n = ffi.new'size_t[1]'
elfasserteq(elf.elf_getshdrnum(e, n), 0, 'elf_getshdrnum')
local shdrnum = n[0]
print(' (shnum) '..inttohex(n[0]))

elfasserteq(elf.elf_getshdrstrndx(e, n), 0, 'elf_getshdrstrndx')
print(' (shstrndx) '..inttohex(n[0]))
local shstrndx = n[0]

do
	local scn = ffi.null
	local shdr = ffi.new'GElf_Shdr[1]'
	while true do
		scn = elf.elf_nextscn(e, scn)
		if scn == ffi.null then break end
		elfasserteq(elf.gelf_getshdr(scn, shdr), shdr, 'elf_getshdr')
		local name = elfassertne(elf.elf_strptr(e, shstrndx, shdr[0].sh_name), ffi.null, 'elf_strptr')
		print('', 'section', elf.elf_ndxscn(scn), ffi.string(name))
	end

	-- last section?
	local scn = elfassertne(elf.elf_getscn(e, shstrndx), ffi.null, 'elf_getscn')
	elfasserteq(elf.gelf_getshdr(scn, shdr), shdr, 'gelf_getshdr')
	print('', 'shstrab size', inttohex(shdr[0].sh_size))

	local data
	local n = 0
	while n < shdr[0].sh_size do
		local data = elf.elf_getdata(scn, data)
		if data == ffi.null then break end
		local p = ffi.cast('char*', data[0].d_buf)
		local pend = p + data[0].d_size
		print('', 'shstrab data', ffi.string(p, data[0].d_size))
		n = n + data[0].d_size
	end
end
elfasserteq(elf.elf_getphdrnum(e, n), 0, 'elf_getphdrnum')
local phdrnum = tonumber(n[0])
print(' (phnum) '..inttohex(n[0]))

for i=0,phdrnum-1 do
	local phdr = ffi.new'GElf_Phdr[1]'
	elfasserteq(elf.gelf_getphdr(e, i, phdr), phdr, 'gelf_getphdr')

	print('PHDR', i);

	print('', 'p_type', inttohex(phdr[0].p_type), nameForPType[phdr[0].p_type] or 'unknown')

	printField(phdr[0], 'p_offset')
	printField(phdr[0], 'p_vaddr')
	printField(phdr[0], 'p_paddr')
	printField(phdr[0], 'p_filesz')
	printField(phdr[0], 'p_memsz')
	printField(phdr[0], 'p_flags')
    io.write'\t['
	if bit.band(phdr[0].p_flags, elf.PF_X) ~= 0 then io.write(' execute') end
	if bit.band(phdr[0].p_flags, elf.PF_R) ~= 0 then io.write(' read') end
	if bit.band(phdr[0].p_flags, elf.PF_W) ~= 0 then io.write(' write') end
	print(' ]')
	printField(phdr[0], 'p_align')

	if phdr[0].p_type == elf.PT_DYNAMIC then
		print('\t\t', 'dynamic:')
		local dyndata = ffi.cast('Elf_Data*', elfdataptr + phdr[0].p_offset)
		local dyn = ffi.new'GElf_Dyn[1]'
		local j = 0
		repeat
			elf.gelf_getdyn(dyndata, j, dyn)
			io.write('\t\t', 'dyn #'..j, '\t')
			writeField(dyn[0], 'd_tag')	-- Elf64_Sxword
			-- then union of d_val or d_ptr
			io.write'\t'
			writeField(dyn[0].d_un, 'd_val')	-- Elf64_Xword, or d_ptr Elf64_Addr
			print()
			j=j+1
		until true
	end
end

elf.elf_end(e)
