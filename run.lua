#!/usr/bin/env luajit
-- port of
-- https://github.com/Zard-C/libelf_examples/blob/main/src/getting_started.c
-- https://github.com/Zard-C/libelf_examples/blob/main/src/print_elf_header.c
-- https://github.com/Zard-C/libelf_examples/blob/main/src/read_header_table.c
local ffi = require 'ffi'
local assert = require 'ext.assert'
local path = require 'ext.path'
local elf = require 'ffi.req' 'elf'
local tolua = require 'ext.tolua'
require 'ffi.req' 'c.fcntl'

local filename = assert((...), "expected filename")

print('elf version', elf.elf_version(elf.EV_CURRENT))

local elfdatastr = assert(path(filename):read())	-- as str
local elfdataptr = ffi.cast('uint8_t*', elfdatastr)

--local fd = assert.ge(ffi.C.open(filename, ffi.C.O_RDONLY, 0), 0, "open("..filename..")")
--print('fd', fd)
--local e = assert.ne(elf.elf_begin(fd, elf.ELF_C_READ, ffi.null), ffi.null, "elf_begin")
--print('e', e)

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

local function printField(ptr, field)
	print('', field, inttohex(ptr[field]))	-- cast to ptr for quick hex intptr_t formatting
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
local shdrstrndx = n[0]
print(' (shstrndx) '..inttohex(n[0]))

elfasserteq(elf.elf_getphdrnum(e, n), 0, 'elf_getphdrnum')
local phdrnum = tonumber(n[0])
print(' (phnum) '..inttohex(n[0]))

for i=0,phdrnum-1 do
	local phdr = ffi.new'GElf_Phdr[1]'
	elfasserteq(elf.gelf_getphdr(e, i, phdr), phdr, 'gelf_getphdr')

	print('Program Header['..i..']:');

	print('', 'p_type', inttohex(phdr[0].p_type), ({
		[elf.PT_NULL] = 'PT_NULL',
		[elf.PT_LOAD] = 'PT_LOAD',
		[elf.PT_DYNAMIC] = 'PT_DYNAMIC',
		[elf.PT_INTERP] = 'PT_INTERP',
		[elf.PT_NOTE] = 'PT_NOTE',
		[elf.PT_SHLIB] = 'PT_SHLIB',
		[elf.PT_PHDR] = 'PT_PHDR',
		[elf.PT_TLS] = 'PT_TLS',
		[elf.PT_SUNWBSS] = 'PT_SUNWBSS',
		[elf.PT_SUNWSTACK] = 'PT_SUNWSTACK',
	})[phdr[0].p_type] or 'unknown')

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
		-- read dynamcis from phdr[0].p_offset
		-- local dyndata = ffi.cast('Elf_Data*', 
		-- wait how do we?  hwo do we seek with elf_begin/elf_end ?
	end
end

elf.elf_end(e)
--ffi.C.close(fd)
