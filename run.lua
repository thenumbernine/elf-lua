#!/usr/bin/env luajit
-- port of
-- https://github.com/Zard-C/libelf_examples/blob/main/src/getting_started.c
-- https://github.com/Zard-C/libelf_examples/blob/main/src/print_elf_header.c
-- https://github.com/Zard-C/libelf_examples/blob/main/src/read_header_table.c
-- https://atakua.org/old-wp/wp-content/uploads/2015/03/libelf-by-example-20100112.pdf

local ffi = require 'ffi'
local assert = require 'ext.assert'
local path = require 'ext.path'
local string = require 'ext.string'
local elf = require 'ffi.req' 'elf'
local tolua = require 'ext.tolua'
require 'ffi.req' 'c.fcntl'

local nameForClass = {
	[elf.ELFCLASSNONE] = 'ELFCLASSNONE',
	[elf.ELFCLASS32] = 'ELFCLASS32',
	[elf.ELFCLASS64] = 'ELFCLASS64',
	[elf.ELFCLASSNUM] = 'ELFCLASSNUM',
}

local nameForElfKind = {	-- libelf-specific
	[elf.ELF_K_NONE] = 'ELF_K_NONE',
	[elf.ELF_K_AR] = 'ELF_K_AR',
	[elf.ELF_K_COFF] = 'ELF_K_COFF',
	[elf.ELF_K_ELF] = 'ELF_K_ELF',
}

local nameForEType = {
	[elf.ET_NONE] = 'ET_NONE',
	[elf.ET_REL] = 'ET_REL',
	[elf.ET_EXEC] = 'ET_EXEC',
	[elf.ET_DYN] = 'ET_DYN',
	[elf.ET_CORE] = 'ET_CORE',
	[elf.ET_NUM] = 'ET_NUM',
	[elf.ET_LOOS] = 'ET_LOOS',
	[elf.ET_HIOS] = 'ET_HIOS',
	[elf.ET_LOPROC] = 'ET_LOPROC',
	[elf.ET_HIPROC] = 'ET_HIPROC',
}

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

-- libelf mixes DT_* for d_tag names
-- *AND* DT_*NUM for number-of-subtypes of d_tag
-- *AND* some of the first have NUM suffix so they can be mistaken for the second.
local nameForDType = {
	[elf.DT_NULL] = 'DT_NULL',
	[elf.DT_NEEDED] = 'DT_NEEDED',
	[elf.DT_PLTRELSZ] = 'DT_PLTRELSZ',
	[elf.DT_PLTGOT] = 'DT_PLTGOT',
	[elf.DT_HASH] = 'DT_HASH',
	[elf.DT_STRTAB] = 'DT_STRTAB',
	[elf.DT_SYMTAB] = 'DT_SYMTAB',
	[elf.DT_RELA] = 'DT_RELA',
	[elf.DT_RELASZ] = 'DT_RELASZ',
	[elf.DT_RELAENT] = 'DT_RELAENT',
	[elf.DT_STRSZ] = 'DT_STRSZ',
	[elf.DT_SYMENT] = 'DT_SYMENT',
	[elf.DT_INIT] = 'DT_INIT',
	[elf.DT_FINI] = 'DT_FINI',
	[elf.DT_SONAME] = 'DT_SONAME',
	[elf.DT_RPATH] = 'DT_RPATH',
	[elf.DT_SYMBOLIC] = 'DT_SYMBOLIC',
	[elf.DT_REL] = 'DT_REL',
	[elf.DT_RELSZ] = 'DT_RELSZ',
	[elf.DT_RELENT] = 'DT_RELENT',
	[elf.DT_PLTREL] = 'DT_PLTREL',
	[elf.DT_DEBUG] = 'DT_DEBUG',
	[elf.DT_TEXTREL] = 'DT_TEXTREL',
	[elf.DT_JMPREL] = 'DT_JMPREL',
	[elf.DT_BIND_NOW] = 'DT_BIND_NOW',
	[elf.DT_INIT_ARRAY] = 'DT_INIT_ARRAY',
	[elf.DT_FINI_ARRAY] = 'DT_FINI_ARRAY',
	[elf.DT_INIT_ARRAYSZ] = 'DT_INIT_ARRAYSZ',
	[elf.DT_FINI_ARRAYSZ] = 'DT_FINI_ARRAYSZ',
	[elf.DT_RUNPATH] = 'DT_RUNPATH',
	[elf.DT_FLAGS] = 'DT_FLAGS',
	[elf.DT_ENCODING] = 'DT_ENCODING',
	[elf.DT_PREINIT_ARRAY] = 'DT_PREINIT_ARRAY',
	[elf.DT_PREINIT_ARRAYSZ] = 'DT_PREINIT_ARRAYSZ',
	[elf.DT_SYMTAB_SHNDX] = 'DT_SYMTAB_SHNDX',
	[elf.DT_RELRSZ] = 'DT_RELRSZ',
	[elf.DT_RELR] = 'DT_RELR',
	[elf.DT_RELRENT] = 'DT_RELRENT',
	[elf.DT_LOOS] = 'DT_LOOS',
	[elf.DT_HIOS] = 'DT_HIOS',
	[elf.DT_LOPROC] = 'DT_LOPROC',
	[elf.DT_HIPROC] = 'DT_HIPROC',
	[elf.DT_VALRNGLO] = 'DT_VALRNGLO',
	[elf.DT_GNU_PRELINKED] = 'DT_GNU_PRELINKED',
	[elf.DT_GNU_CONFLICTSZ] = 'DT_GNU_CONFLICTSZ',
	[elf.DT_GNU_LIBLISTSZ] = 'DT_GNU_LIBLISTSZ',
	[elf.DT_CHECKSUM] = 'DT_CHECKSUM',
	[elf.DT_PLTPADSZ] = 'DT_PLTPADSZ',
	[elf.DT_MOVEENT] = 'DT_MOVEENT',
	[elf.DT_MOVESZ] = 'DT_MOVESZ',
	[elf.DT_FEATURE_1] = 'DT_FEATURE_1',
	[elf.DT_POSFLAG_1] = 'DT_POSFLAG_1',
	[elf.DT_SYMINSZ] = 'DT_SYMINSZ',
	[elf.DT_SYMINENT] = 'DT_SYMINENT',
	[elf.DT_VALRNGHI] = 'DT_VALRNGHI',
	[elf.DT_ADDRRNGLO] = 'DT_ADDRRNGLO',
	[elf.DT_GNU_HASH] = 'DT_GNU_HASH',
	[elf.DT_TLSDESC_PLT] = 'DT_TLSDESC_PLT',
	[elf.DT_TLSDESC_GOT] = 'DT_TLSDESC_GOT',
	[elf.DT_GNU_CONFLICT] = 'DT_GNU_CONFLICT',
	[elf.DT_GNU_LIBLIST] = 'DT_GNU_LIBLIST',
	[elf.DT_CONFIG] = 'DT_CONFIG',
	[elf.DT_DEPAUDIT] = 'DT_DEPAUDIT',
	[elf.DT_AUDIT] = 'DT_AUDIT',
	[elf.DT_PLTPAD] = 'DT_PLTPAD',
	[elf.DT_MOVETAB] = 'DT_MOVETAB',
	[elf.DT_SYMINFO] = 'DT_SYMINFO',
	[elf.DT_ADDRRNGHI] = 'DT_ADDRRNGHI',
	[elf.DT_VERSYM] = 'DT_VERSYM',
	[elf.DT_RELACOUNT] = 'DT_RELACOUNT',
	[elf.DT_RELCOUNT] = 'DT_RELCOUNT',
	[elf.DT_FLAGS_1] = 'DT_FLAGS_1',
	[elf.DT_VERDEF] = 'DT_VERDEF',
	[elf.DT_VERDEFNUM] = 'DT_VERDEFNUM',
	[elf.DT_VERNEED] = 'DT_VERNEED',
	[elf.DT_VERNEEDNUM] = 'DT_VERNEEDNUM',
	[elf.DT_AUXILIARY] = 'DT_AUXILIARY',
	[elf.DT_FILTER] = 'DT_FILTER',
	[elf.DT_SPARC_REGISTER] = 'DT_SPARC_REGISTER',
	[elf.DT_MIPS_RLD_VERSION] = 'DT_MIPS_RLD_VERSION',
	[elf.DT_MIPS_TIME_STAMP] = 'DT_MIPS_TIME_STAMP',
	[elf.DT_MIPS_ICHECKSUM] = 'DT_MIPS_ICHECKSUM',
	[elf.DT_MIPS_IVERSION] = 'DT_MIPS_IVERSION',
	[elf.DT_MIPS_FLAGS] = 'DT_MIPS_FLAGS',
	[elf.DT_MIPS_BASE_ADDRESS] = 'DT_MIPS_BASE_ADDRESS',
	[elf.DT_MIPS_MSYM] = 'DT_MIPS_MSYM',
	[elf.DT_MIPS_CONFLICT] = 'DT_MIPS_CONFLICT',
	[elf.DT_MIPS_LIBLIST] = 'DT_MIPS_LIBLIST',
	[elf.DT_MIPS_LOCAL_GOTNO] = 'DT_MIPS_LOCAL_GOTNO',
	[elf.DT_MIPS_CONFLICTNO] = 'DT_MIPS_CONFLICTNO',
	[elf.DT_MIPS_LIBLISTNO] = 'DT_MIPS_LIBLISTNO',
	[elf.DT_MIPS_SYMTABNO] = 'DT_MIPS_SYMTABNO',
	[elf.DT_MIPS_UNREFEXTNO] = 'DT_MIPS_UNREFEXTNO',
	[elf.DT_MIPS_GOTSYM] = 'DT_MIPS_GOTSYM',
	[elf.DT_MIPS_HIPAGENO] = 'DT_MIPS_HIPAGENO',
	[elf.DT_MIPS_RLD_MAP] = 'DT_MIPS_RLD_MAP',
	[elf.DT_MIPS_DELTA_CLASS] = 'DT_MIPS_DELTA_CLASS',
	[elf.DT_MIPS_DELTA_CLASS_NO] = 'DT_MIPS_DELTA_CLASS_NO',
	[elf.DT_MIPS_DELTA_INSTANCE] = 'DT_MIPS_DELTA_INSTANCE',
	[elf.DT_MIPS_DELTA_INSTANCE_NO] = 'DT_MIPS_DELTA_INSTANCE_NO',
	[elf.DT_MIPS_DELTA_RELOC] = 'DT_MIPS_DELTA_RELOC',
	[elf.DT_MIPS_DELTA_RELOC_NO] = 'DT_MIPS_DELTA_RELOC_NO',
	[elf.DT_MIPS_DELTA_SYM] = 'DT_MIPS_DELTA_SYM',
	[elf.DT_MIPS_DELTA_SYM_NO] = 'DT_MIPS_DELTA_SYM_NO',
	[elf.DT_MIPS_DELTA_CLASSSYM] = 'DT_MIPS_DELTA_CLASSSYM',
	[elf.DT_MIPS_DELTA_CLASSSYM_NO] = 'DT_MIPS_DELTA_CLASSSYM_NO',
	[elf.DT_MIPS_CXX_FLAGS] = 'DT_MIPS_CXX_FLAGS',
	[elf.DT_MIPS_PIXIE_INIT] = 'DT_MIPS_PIXIE_INIT',
	[elf.DT_MIPS_SYMBOL_LIB] = 'DT_MIPS_SYMBOL_LIB',
	[elf.DT_MIPS_LOCALPAGE_GOTIDX] = 'DT_MIPS_LOCALPAGE_GOTIDX',
	[elf.DT_MIPS_LOCAL_GOTIDX] = 'DT_MIPS_LOCAL_GOTIDX',
	[elf.DT_MIPS_HIDDEN_GOTIDX] = 'DT_MIPS_HIDDEN_GOTIDX',
	[elf.DT_MIPS_PROTECTED_GOTIDX] = 'DT_MIPS_PROTECTED_GOTIDX',
	[elf.DT_MIPS_OPTIONS] = 'DT_MIPS_OPTIONS',
	[elf.DT_MIPS_INTERFACE] = 'DT_MIPS_INTERFACE',
	[elf.DT_MIPS_DYNSTR_ALIGN] = 'DT_MIPS_DYNSTR_ALIGN',
	[elf.DT_MIPS_INTERFACE_SIZE] = 'DT_MIPS_INTERFACE_SIZE',
	[elf.DT_MIPS_RLD_TEXT_RESOLVE_ADDR] = 'DT_MIPS_RLD_TEXT_RESOLVE_ADDR',
	[elf.DT_MIPS_PERF_SUFFIX] = 'DT_MIPS_PERF_SUFFIX',
	[elf.DT_MIPS_COMPACT_SIZE] = 'DT_MIPS_COMPACT_SIZE',
	[elf.DT_MIPS_GP_VALUE] = 'DT_MIPS_GP_VALUE',
	[elf.DT_MIPS_AUX_DYNAMIC] = 'DT_MIPS_AUX_DYNAMIC',
	[elf.DT_MIPS_PLTGOT] = 'DT_MIPS_PLTGOT',
	[elf.DT_MIPS_RWPLT] = 'DT_MIPS_RWPLT',
	[elf.DT_MIPS_RLD_MAP_REL] = 'DT_MIPS_RLD_MAP_REL',
	[elf.DT_MIPS_XHASH] = 'DT_MIPS_XHASH',
	[elf.DT_ALPHA_PLTRO] = 'DT_ALPHA_PLTRO',
	[elf.DT_PPC_GOT] = 'DT_PPC_GOT',
	[elf.DT_PPC_OPT] = 'DT_PPC_OPT',
	[elf.DT_PPC64_GLINK] = 'DT_PPC64_GLINK',
	[elf.DT_PPC64_OPD] = 'DT_PPC64_OPD',
	[elf.DT_PPC64_OPDSZ] = 'DT_PPC64_OPDSZ',
	[elf.DT_PPC64_OPT] = 'DT_PPC64_OPT',
	[elf.DT_AARCH64_BTI_PLT] = 'DT_AARCH64_BTI_PLT',
	[elf.DT_AARCH64_PAC_PLT] = 'DT_AARCH64_PAC_PLT',
	[elf.DT_AARCH64_VARIANT_PCS] = 'DT_AARCH64_VARIANT_PCS',
	[elf.DT_X86_64_PLT] = 'DT_X86_64_PLT',
	[elf.DT_X86_64_PLTSZ] = 'DT_X86_64_PLTSZ',
	[elf.DT_X86_64_PLTENT] = 'DT_X86_64_PLTENT',
	[elf.DT_NIOS2_GP] = 'DT_NIOS2_GP',
	[elf.DT_RISCV_VARIANT_CC] = 'DT_RISCV_VARIANT_CC',
}

local nameForSHType = {
	[elf.SHT_NULL] = 'SHT_NULL',
	[elf.SHT_PROGBITS] = 'SHT_PROGBITS',
	[elf.SHT_SYMTAB] = 'SHT_SYMTAB',
	[elf.SHT_STRTAB] = 'SHT_STRTAB',
	[elf.SHT_RELA] = 'SHT_RELA',
	[elf.SHT_HASH] = 'SHT_HASH',
	[elf.SHT_DYNAMIC] = 'SHT_DYNAMIC',
	[elf.SHT_NOTE] = 'SHT_NOTE',
	[elf.SHT_NOBITS] = 'SHT_NOBITS',
	[elf.SHT_REL] = 'SHT_REL',
	[elf.SHT_SHLIB] = 'SHT_SHLIB',
	[elf.SHT_DYNSYM] = 'SHT_DYNSYM',
	[elf.SHT_INIT_ARRAY] = 'SHT_INIT_ARRAY',
	[elf.SHT_FINI_ARRAY] = 'SHT_FINI_ARRAY',
	[elf.SHT_PREINIT_ARRAY] = 'SHT_PREINIT_ARRAY',
	[elf.SHT_GROUP] = 'SHT_GROUP',
	[elf.SHT_SYMTAB_SHNDX] = 'SHT_SYMTAB_SHNDX',
	[elf.SHT_RELR] = 'SHT_RELR',
	[elf.SHT_NUM] = 'SHT_NUM',
	[elf.SHT_LOOS] = 'SHT_LOOS',
	[elf.SHT_GNU_ATTRIBUTES] = 'SHT_GNU_ATTRIBUTES',
	[elf.SHT_GNU_HASH] = 'SHT_GNU_HASH',
	[elf.SHT_GNU_LIBLIST] = 'SHT_GNU_LIBLIST',
	[elf.SHT_CHECKSUM] = 'SHT_CHECKSUM',
	[elf.SHT_LOSUNW] = 'SHT_LOSUNW',
	[elf.SHT_SUNW_move] = 'SHT_SUNW_move',
	[elf.SHT_SUNW_COMDAT] = 'SHT_SUNW_COMDAT',
	[elf.SHT_SUNW_syminfo] = 'SHT_SUNW_syminfo',
	[elf.SHT_GNU_verdef] = 'SHT_GNU_verdef',
	[elf.SHT_GNU_verneed] = 'SHT_GNU_verneed',
	[elf.SHT_GNU_versym] = 'SHT_GNU_versym',
	--[elf.SHT_HISUNW] = 'SHT_HISUNW',	-- sun-specific, clashes with SHT_GNU_verneed
	--[elf.SHT_HIOS] = 'SHT_HIOS',		-- sun-specific, clashes with SHT_GNU_verneed
	[elf.SHT_LOPROC] = 'SHT_LOPROC',
	[elf.SHT_HIPROC] = 'SHT_HIPROC',
	[elf.SHT_LOUSER] = 'SHT_LOUSER',
	[elf.SHT_HIUSER] = 'SHT_HIUSER',
	[elf.SHT_MIPS_LIBLIST] = 'SHT_MIPS_LIBLIST',
	[elf.SHT_MIPS_MSYM] = 'SHT_MIPS_MSYM',
	[elf.SHT_MIPS_CONFLICT] = 'SHT_MIPS_CONFLICT',
	[elf.SHT_MIPS_GPTAB] = 'SHT_MIPS_GPTAB',
	[elf.SHT_MIPS_UCODE] = 'SHT_MIPS_UCODE',
	[elf.SHT_MIPS_DEBUG] = 'SHT_MIPS_DEBUG',
	[elf.SHT_MIPS_REGINFO] = 'SHT_MIPS_REGINFO',
	[elf.SHT_MIPS_PACKAGE] = 'SHT_MIPS_PACKAGE',
	[elf.SHT_MIPS_PACKSYM] = 'SHT_MIPS_PACKSYM',
	[elf.SHT_MIPS_RELD] = 'SHT_MIPS_RELD',
	[elf.SHT_MIPS_IFACE] = 'SHT_MIPS_IFACE',
	[elf.SHT_MIPS_CONTENT] = 'SHT_MIPS_CONTENT',
	[elf.SHT_MIPS_OPTIONS] = 'SHT_MIPS_OPTIONS',
	[elf.SHT_MIPS_SHDR] = 'SHT_MIPS_SHDR',
	[elf.SHT_MIPS_FDESC] = 'SHT_MIPS_FDESC',
	[elf.SHT_MIPS_EXTSYM] = 'SHT_MIPS_EXTSYM',
	[elf.SHT_MIPS_DENSE] = 'SHT_MIPS_DENSE',
	[elf.SHT_MIPS_PDESC] = 'SHT_MIPS_PDESC',
	[elf.SHT_MIPS_LOCSYM] = 'SHT_MIPS_LOCSYM',
	[elf.SHT_MIPS_AUXSYM] = 'SHT_MIPS_AUXSYM',
	[elf.SHT_MIPS_OPTSYM] = 'SHT_MIPS_OPTSYM',
	[elf.SHT_MIPS_LOCSTR] = 'SHT_MIPS_LOCSTR',
	[elf.SHT_MIPS_LINE] = 'SHT_MIPS_LINE',
	[elf.SHT_MIPS_RFDESC] = 'SHT_MIPS_RFDESC',
	[elf.SHT_MIPS_DELTASYM] = 'SHT_MIPS_DELTASYM',
	[elf.SHT_MIPS_DELTAINST] = 'SHT_MIPS_DELTAINST',
	[elf.SHT_MIPS_DELTACLASS] = 'SHT_MIPS_DELTACLASS',
	[elf.SHT_MIPS_DWARF] = 'SHT_MIPS_DWARF',
	[elf.SHT_MIPS_DELTADECL] = 'SHT_MIPS_DELTADECL',
	[elf.SHT_MIPS_SYMBOL_LIB] = 'SHT_MIPS_SYMBOL_LIB',
	[elf.SHT_MIPS_EVENTS] = 'SHT_MIPS_EVENTS',
	[elf.SHT_MIPS_TRANSLATE] = 'SHT_MIPS_TRANSLATE',
	[elf.SHT_MIPS_PIXIE] = 'SHT_MIPS_PIXIE',
	[elf.SHT_MIPS_XLATE] = 'SHT_MIPS_XLATE',
	[elf.SHT_MIPS_XLATE_DEBUG] = 'SHT_MIPS_XLATE_DEBUG',
	[elf.SHT_MIPS_WHIRL] = 'SHT_MIPS_WHIRL',
	[elf.SHT_MIPS_EH_REGION] = 'SHT_MIPS_EH_REGION',
	[elf.SHT_MIPS_XLATE_OLD] = 'SHT_MIPS_XLATE_OLD',
	[elf.SHT_MIPS_PDR_EXCEPTION] = 'SHT_MIPS_PDR_EXCEPTION',
	[elf.SHT_MIPS_ABIFLAGS] = 'SHT_MIPS_ABIFLAGS',
	[elf.SHT_MIPS_XHASH] = 'SHT_MIPS_XHASH',
	[elf.SHT_PARISC_EXT] = 'SHT_PARISC_EXT',
	[elf.SHT_PARISC_UNWIND] = 'SHT_PARISC_UNWIND',
	[elf.SHT_PARISC_DOC] = 'SHT_PARISC_DOC',
	[elf.SHT_ALPHA_DEBUG] = 'SHT_ALPHA_DEBUG',
	[elf.SHT_ALPHA_REGINFO] = 'SHT_ALPHA_REGINFO',
	[elf.SHT_ARM_EXIDX] = 'SHT_ARM_EXIDX',
	[elf.SHT_ARM_PREEMPTMAP] = 'SHT_ARM_PREEMPTMAP',
	[elf.SHT_ARM_ATTRIBUTES] = 'SHT_ARM_ATTRIBUTES',
	[elf.SHT_CSKY_ATTRIBUTES] = 'SHT_CSKY_ATTRIBUTES',
	[elf.SHT_IA_64_EXT] = 'SHT_IA_64_EXT',			-- = SHT_LOPROC
	[elf.SHT_IA_64_UNWIND] = 'SHT_IA_64_UNWIND',	-- = SHT_LOPROC + 1
	[elf.SHT_X86_64_UNWIND] = 'SHT_X86_64_UNWIND',
	[elf.SHT_RISCV_ATTRIBUTES] = 'SHT_RISCV_ATTRIBUTES',
	[elf.SHT_ARC_ATTRIBUTES] = 'SHT_ARC_ATTRIBUTES',
}

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

local function inttohex(x, numbytes)
	--[[ easier to do when i use my struct lib ...
	numbytes = numbytes or 8
	local s = ''
	for i=0,numbytes-1 do
		s = ('%02x'):format(bit.band(x, 0xff)) .. s
		x = bit.rshift(x, 2)
	end
	return '0x'..s
	--]]
	-- [[
	if ffi.cast('uintptr_t', x) == 0ULL then return '0x00000000' end        -- skip 'NULL'
	return tostring(ffi.cast('void*', x)):match'^cdata<void %*>: (.*)'
	--]]
end

local function writeField(ptr, field)
	local x = ptr[field]
	io.write(field, '=', inttohex(x))
end


local filename = assert((...), "expected filename")

print('elf lib version', elf.elf_version(elf.EV_CURRENT))	-- does EV_CURRENT go here?

local elfdatastr = assert(path(filename):read())	-- as str
local elfdataptr = ffi.cast('uint8_t*', elfdatastr)
print('file size', inttohex(#elfdatastr))

local ehdr = ffi.cast('GElf_Ehdr*', elfdataptr)

-- do I need this test?
local elfHandle = elf.elf_memory(elfdataptr, #elfdatastr)
local ekind = tonumber(elf.elf_kind(elfHandle))
print('elf kind = '..inttohex(ekind)..'/'..(nameForElfKind[ekind] or 'unknown'))
assert.eq(ekind, elf.ELF_K_ELF, 'must be an ELF object')

print('elf class = '..ehdr.e_ident[elf.EI_CLASS]..'/'..(nameForClass[ehdr.e_ident[elf.EI_CLASS]] or 'unknown'))
print('e_ident[0..'..elf.EI_ABIVERSION..'] = '..tolua(ffi.string(ffi.cast('char*', ehdr.e_ident), elf.EI_ABIVERSION)))

print()
print'elf header:'
print(' e_type = '..inttohex(ehdr.e_type)..'/'..(nameForEType[ehdr.e_type] or 'unknown'))
for _,field in ipairs{
	'e_machine', 'e_version', 'e_entry', 'e_phoff', 'e_shoff', 'e_flags',
	'e_ehsize', 'e_phentsize', 'e_phnum', 'e_shentsize', 'e_shnum', 'e_shstrndx'
} do
	io.write' '
	writeField(ehdr, field)
	print()
end

-- all sections headers:
local shdrs = ffi.cast('GElf_Shdr*', elfdataptr + ehdr.e_shoff)

local shdr_dynamic 	-- sh_type == SHT_DYNAMIC
local shdr_dynstr	-- sh_type == SHT_STRTAB and name == .dynstr
local shdr_dynsym 	-- sh_type == SHT_DYNSYM and name == .dynsym
local shdr_symtab	-- sh_type == SHT_SYMTAB and name == .symtab
local shdr_versym 	-- sh_type == SHT_GNU_versym
local shdr_verdef	-- sh_type == SHT_GNU_verdef
local shdr_verneed	-- sh_type == SHT_GNU_verneed

local shdr_shstr = shdrs + ehdr.e_shstrndx
local shstrs = ffi.cast('char*', elfdataptr + shdr_shstr.sh_offset)
local function getSectionHeaderName(i)
	return ffi.string(shstrs + shdrs[i].sh_name)
end

print()
print'Sections:'
for i=1,ehdr.e_shstrndx-1 do		-- is section #0 always empty?
	local shdr = shdrs + i
	local name = getSectionHeaderName(i)
	io.write(' #'..i..' shdr=@'..inttohex(ffi.cast('uint8_t*', shdr) - elfdataptr))
	for _,field in ipairs{'sh_flags', 'sh_addr', 'sh_offset', 'sh_size', 'sh_link', 'sh_info', 'sh_addralign', 'sh_entsize',
		'sh_type', 'sh_name'	-- redundant ... if i print sh_type next to unknowns
	} do
		io.write' '
		writeField(shdr, field)
	end
	io.write(' '..name)
	io.write(' / '..(nameForSHType[tonumber(shdr.sh_type)] or 'unknown'))
	print()

	if shdr.sh_type == elf.SHT_STRTAB and name == '.dynstr' then
		assert(not shdr_dynstr)
		shdr_dynstr = shdr
	end

	-- dynamic linker symbol table
	-- "Currently, an object file may have either a section of SHT_SYMTAB type or a section of SHT_DYNSYM type, but not both"
	-- do if there's a SHT_SYMTAB then there's no SHT_DYMSYM ... is there no SHT_GNU_versym as well?  Where's the version info?
	if shdr.sh_type == elf.SHT_DYNSYM and name == '.dynsym' then
		assert(not shdr_dynsym)
		shdr_dynsym = shdr
	end

	-- .symtab
	if shdr.sh_type == elf.SHT_SYMTAB and name == '.symtab' then
		assert(not shdr_symtab)
		shdr_symtab = shdr
	end

	-- https://refspecs.linuxfoundation.org/LSB_3.1.1/LSB-Core-generic/LSB-Core-generic/symversion.html
	-- "The special section .gnu.version which has a section type of SHT_GNU_versym shall contain the Symbol Version Table.
	--  This section shall have the same number of entries as the Dynamic Symbol Table in the .dynsym section."
	-- but I don't see any in mine ...
	if shdr.sh_type == elf.SHT_GNU_versym and name == '.gnu.version' then
		assert(not shdr_versym)
		shdr_versym = shdr
	end
	if shdr.sh_type == elf.SHT_GNU_verneed and name == '.gnu.version_r' then
		assert(not shdr_verneed)
		shdr_verneed = shdr
	end
	if shdr.sh_type == elf.SHT_GNU_verdef then
		assert(not shdr_verdef)
		shdr_verdef = shdr
		-- hmm, mine doesn't have one ...
	end

	if shdr.sh_type == elf.SHT_DYNAMIC then
		assert(not shdr_dynamic)
		shdr_dynamic = shdr
	end
end

local dyn_verneed
local dyn_verneednum
local dyn_versym
if shdr_dynamic then
	-- matches PT_DYNAMIC, but why is it a wholly dif section SHT_DYNAMIC?
	local dyns = ffi.cast('GElf_Dyn*', elfdataptr + shdr_dynamic.sh_offset)
	local count = tonumber(shdr_dynamic.sh_size/shdr_dynamic.sh_entsize)
	-- same in static and dynamic names as here?
	-- if it is a coincidence and ever fails, go back to using shdr_dynstr
	local shdr_strs = shdrs + shdr_dynamic.sh_link
	local strs = elfdataptr + shdr_strs.sh_offset
	print()
	print'SHT_DYNAMIC:'
	for i=0,count-1 do
		local dyn = dyns + i

		io.write(' dyn #'..i..' @'..inttohex(ffi.cast('uint8_t*', dyn) - elfdataptr))
		io.write' '
		writeField(dyn.d_un, 'd_val')
		io.write(' d_tag='..inttohex(dyn.d_tag)..'/'..(nameForDType[tonumber(dyn.d_tag)] or 'unknown'))

		if dyn.d_tag == elf.DT_NEEDED then
			io.write(' ', ffi.string(strs + dyn.d_un.d_val))
		elseif dyn.d_tag == elf.DT_VERNEED then
			-- dyn.d_val == shdr[SHT_GNU_verneed / .gnu.version_r]'s sh_addr & sh_offset
			dyn_verneed = dyn
		elseif dyn.d_tag == elf.DT_VERNEEDNUM then
			-- only 3 in my example
			dyn_verneednum = dyn
		elseif dyn.d_tag == elf.DT_VERSYM then
			-- dyn.d_val == shdr[SHT_GNU_versym / .gnu.version]'s sh_addr & sh_offset
			dyn_versym = dyn
		end

		print()
	end
end

if dyn_verneed and shdr_verneed then
	assert.eq(dyn_verneed.d_un.d_val, shdr_verneed.sh_offset, 'dyn verneed.d_un.d_val vs shdr verneed.sh_offset')
end

-- is this true or just coincidence?  "sh_info" is a funny name for a field length...
if dyn_verneednum and shdr_verneed then
	assert.eq(dyn_verneednum.d_un.d_val, shdr_verneed.sh_info, 'dyn verneednum.d_un.d_val vs shdr verneed.sh_info')
end
if dyn_versym and shdr_versym then
	assert.eq(dyn_versym.d_un.d_val, shdr_versym.sh_offset, 'dyn versym.d_un.d_val vs shdr versym.sh_offset')
end

--[=[ very last section - holds the null-term section names above ... print it?  or nah cuz it's already in the section names
local scn = elfassertne(elf.elf_getscn(elfHandle, ehdr.e_shstrndx), ffi.null, 'elf_getscn')
local shdr = shdrs + ehdr.e_shstrndx
print()
print('shstrab size', inttohex(shdr.sh_size))
local data
local n = 0
while n < shdr.sh_size do
	local data = elf.elf_getdata(scn, data)
	if data == ffi.null then break end
	print('shstrab data', ffi.string(ffi.cast('char*', data.d_buf), data.d_size))
	n = n + data.d_size
end
--]=]

-- https://compilepeace.github.io/BINARY_DISSECTION_COURSE/ELF/SYMBOLS/SYMBOLS.html
-- SHT_DYNSYM/.dynsym + SHT_STRTAB/.dynstr
if shdr_dynsym 		-- = list of symbols
--and shdr_dynstr 	-- = where to find their name strings, or use shdr_dynsym.sh_link
then
	local dynsym = ffi.cast('GElf_Sym*', elfdataptr + shdr_dynsym.sh_offset)
	local dynsym_size = shdr_dynsym.sh_size
	local count = tonumber(dynsym_size/ffi.sizeof'GElf_Sym')

	local versyms
	if shdr_versym then
		versyms = ffi.cast('Elf64_Versym*', elfdataptr + shdr_versym.sh_offset)
		local versym_count = tonumber(shdr_versym.sh_size / shdr_versym.sh_entsize)
		assert.eq(versym_count, count, "shdr_versym count dosen't match shdr_dynsym count")
	end

	-- this is true in static header.  is it true here too?  yup.  coincidence?
	-- if it is a coincidence and ever fails, go back to using shdr_dynstr
	local shdr_strs = shdrs + shdr_dynsym.sh_link
	local strs = elfdataptr + shdr_strs.sh_offset

	print()
	print'SHT_DYNSYM/.dynsym:'
	for i=0,count-1 do
		local p = dynsym[i]
		io.write(' #'..i)
		for _,field in ipairs{'st_name', 'st_info', 'st_other', 'st_value', 'st_size'} do
			io.write' '
			writeField(p, field)
		end
		-- in objdump -T:
		-- st_shndx is flags:
		-- overall .st_shndx == 0 <-> *UND*
		-- otherwise 'g' is set and the value is the shdr #
		-- st_info is flags:
		-- 0x20 = 'w'
		-- 0x10 = 'D'
		-- 0x03 == 2 = 'F'
		-- 0x03 == 1 = 'O'

		io.write(' '..ffi.string(strs + p.st_name))

		local shndx = p.st_shndx
		io.write' '
		writeField(p, 'st_shndx')
		if shndx > 0 then
			io.write('/'..getSectionHeaderName(shndx))
		end

		if versyms then
			local versym = versyms[i]
			-- versym == 0 shows up as none
			-- versym == 1 shows up as base
			-- versym > 1 is dif names
			if versym == 0 then
			elseif versym == 1 then
				io.write(' versym=base')
			else
				io.write(' versym='..versym)
			end

			--[[ TESTING: downgrade the 2.38 to 2.34
			if versym == 9 then
				--versyms[i] = 4	-- fmod not in 2.34
				--versyms[i] = 6	-- fmod not in 2.29
				--versyms[i] = 10	-- fmod not in 2.14
				--versyms[i] = 7	-- fmod not in 2.7
				versyms[i] = 2
			end
			--]]
		end

		--[[
		the max versym is 10.  even if #0 and #1 are resreved, that's still a lot more than verneednum=3 ...
		it corresponds to this info in ldd -v:
		-- ldd output order:
		#8	libgcc_s.so.1 (GCC_3.3) => /lib/x86_64-linux-gnu/libgcc_s.so.1
		#5	libgcc_s.so.1 (GCC_3.0) => /lib/x86_64-linux-gnu/libgcc_s.so.1
		#10	libc.so.6 (GLIBC_2.14) => /lib/x86_64-linux-gnu/libc.so.6
		#7	libc.so.6 (GLIBC_2.7) => /lib/x86_64-linux-gnu/libc.so.6
		#4	libc.so.6 (GLIBC_2.34) => /lib/x86_64-linux-gnu/libc.so.6
		#3	libc.so.6 (GLIBC_2.2.5) => /lib/x86_64-linux-gnu/libc.so.6
		#9	libm.so.6 (GLIBC_2.38) => /lib/x86_64-linux-gnu/libm.so.6
		#6	libm.so.6 (GLIBC_2.29) => /lib/x86_64-linux-gnu/libm.so.6
		#2	libm.so.6 (GLIBC_2.2.5) => /lib/x86_64-linux-gnu/libm.so.6

		-- in version order:
		#3	libc.so.6 (GLIBC_2.2.5) => /lib/x86_64-linux-gnu/libc.so.6
		#2	libm.so.6 (GLIBC_2.2.5) => /lib/x86_64-linux-gnu/libm.so.6
		#7	libc.so.6 (GLIBC_2.7) => /lib/x86_64-linux-gnu/libc.so.6
		#10	libc.so.6 (GLIBC_2.14) => /lib/x86_64-linux-gnu/libc.so.6
		#6	libm.so.6 (GLIBC_2.29) => /lib/x86_64-linux-gnu/libm.so.6
		#4	libc.so.6 (GLIBC_2.34) => /lib/x86_64-linux-gnu/libc.so.6
		#9	libm.so.6 (GLIBC_2.38) => /lib/x86_64-linux-gnu/libm.so.6
		#5	libgcc_s.so.1 (GCC_3.0) => /lib/x86_64-linux-gnu/libgcc_s.so.1
		#8	libgcc_s.so.1 (GCC_3.3) => /lib/x86_64-linux-gnu/libgcc_s.so.1
		--]]
		print()
	end
end

if shdr_verneed then
	local count = shdr_verneed.sh_info
	local shdr_strs = shdrs + shdr_verneed.sh_link
	local strs = elfdataptr + shdr_strs.sh_offset
	print()
	print'SHT_GNU_verneed:'
	--local verneeds = ffi.cast('GElf_Verneed*', elfdataptr + shdr_verneed.sh_offset)
	--local verneed = verneeds + i
	local p = elfdataptr + shdr_verneed.sh_offset
	for i=0,count-1 do
		--local verneed = verneeds + i
		local verneed = ffi.cast('GElf_Verneed*', p)
		io.write(' #'..i)
		for _,field in ipairs{
			'vn_version', 	-- always 1?
			--'vn_cnt', 'vn_aux', 'vn_next'	-- redundant?
		} do
			io.write' '
			writeField(verneed, field)
		end
		io.write' '
		writeField(verneed, 'vn_file')
		io.write(' '..ffi.string(strs + verneed.vn_file))
		print()

		local p2 = p + verneed.vn_aux
		for j=0,verneed.vn_cnt-1 do
			local vernaux = ffi.cast('GElf_Vernaux*', p2)
			io.write('  #'..j)
			for _,field in ipairs{'vna_hash', 'vna_flags', 'vna_other',
				-- 'vna_name', 'vna_next'	-- redundant
			} do
				io.write' '
				writeField(vernaux, field)
			end
			io.write(' '..ffi.string(strs + vernaux.vna_name))
			print()

			p2 = p2 + vernaux.vna_next
		end

		p = p + verneed.vn_next
	end
end

-- SHT_STRTAB/.strtab + SHT_SYMTAB/.symtab
if shdr_symtab then	-- = list of symbols
	local symtab = ffi.cast('GElf_Sym*', elfdataptr + shdr_symtab.sh_offset)
	local symtab_size = shdr_symtab.sh_size
	local symtab_count = shdr_symtab.sh_size / shdr_symtab.sh_entsize
	local shdr_strs = shdrs + shdr_symtab.sh_link
	local strs = elfdataptr + shdr_strs.sh_offset
	print()
	print'SHT_SYMTAB/.symtab:'
	for i=0,tonumber(symtab_count)-1 do
		local p = symtab[i]
		io.write(' #'..i..' ')
		for _,field in ipairs{'st_name', 'st_info', 'st_other', 'st_shndx', 'st_value', 'st_size'} do
			io.write' '
			writeField(p, field)
		end
		-- should be within shdr_strs.sh_size of shdr_strs.offset right?
		io.write(' '..ffi.string(strs + p.st_name))
		print()
	end
end

local phdrs = ffi.cast('GElf_Phdr*', elfdataptr + ehdr.e_phoff)
local phdr_dynamic
print()
print'Program Headers:'
for i=0,ehdr.e_phnum-1 do
	local phdr = phdrs + i

	io.write(' #'..i)
	for _,field in ipairs{'p_offset', 'p_vaddr', 'p_paddr', 'p_filesz', 'p_memsz', 'p_flags'} do
		io.write' '
		writeField(phdr, field)
	end
	io.write'['
	if bit.band(phdr.p_flags, elf.PF_X) ~= 0 then io.write'x' end
	if bit.band(phdr.p_flags, elf.PF_R) ~= 0 then io.write'r' end
	if bit.band(phdr.p_flags, elf.PF_W) ~= 0 then io.write'w' end
	io.write']'
	io.write' ' writeField(phdr, 'p_align')
	io.write(' p_type='..inttohex(phdr.p_type)..' / '..(nameForPType[phdr.p_type] or 'unknown'))
	print()

	if phdr.p_type == elf.PT_DYNAMIC then
		assert(not phdr_dynamic)
		phdr_dynamic = phdr
	end
end

-- if not shdr_dynamic then assert no phdr_dynamic as well
assert.eq(not not shdr_dynamic, not not phdr_dynamic, "found DYNAMIC in section headers vs program headers")
if shdr_dynamic then
	local shdr_dyns = elfdataptr + shdr_dynamic.sh_offset
	local phdr_dyns = ffi.cast('GElf_Dyn*', elfdataptr + phdr_dynamic.p_offset)
	assert.eq(shdr_dyns, phdr_dyns, "dynamic pointers don't match")
end

elf.elf_end(elfHandle)

print()
print'DONE'

path'luajit-hacked':write(elfdatastr)
