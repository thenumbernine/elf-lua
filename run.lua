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

local function inttohex(x)
	if ffi.cast('uintptr_t', x) == 0ULL then return '0x00000000' end	-- skip 'NULL'
	return tostring(ffi.cast('void*', x)):match'^cdata<void %*>: (.*)'
end

local function writeField(ptr, field)
	io.write(field, '=', inttohex(ptr[field]))	-- cast to ptr for quick hex intptr_t formatting
end


local filename = assert((...), "expected filename")

print('elf version', elf.elf_version(elf.EV_CURRENT))

local elfdatastr = assert(path(filename):read())	-- as str
local elfdataptr = ffi.cast('uint8_t*', elfdatastr)
print('file size', inttohex(#elfdatastr))

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

assert.eq(ek, elf.ELF_K_ELF, 'must be an ELF object')

local ehdr = ffi.new'GElf_Ehdr[1]'
elfassertne(elf.gelf_getehdr(e, ehdr), ffi.null, 'gelf_getehdr')

print((
	elfassertne(elf.gelf_getclass(e), elf.ELFCLASSNONE, 'gelf_getclass')
	== elf.ELFCLASS32 and '32' or '64')..'-bit ELF object')

local id = elfassertne(elf.elf_getident(e, ffi.null), ffi.null, 'elf_getident')

print('e_ident[0..'..elf.EI_ABIVERSION..']', string.hexdump(ffi.string(id, 8)))

print()
print'Elf header'
for _,field in ipairs{
	'e_type', 'e_machine', 'e_version', 'e_entry', 'e_phoff', 'e_shoff', 'e_flags',
	'e_ehsize', 'e_phentsize', 'e_phnum', 'e_shentsize', 'e_shnum', 'e_shstrndx'
} do
	io.write' '
	writeField(ehdr[0], field)
	print()
end

local n = ffi.new'size_t[1]'
elfasserteq(elf.elf_getshdrnum(e, n), 0, 'elf_getshdrnum')
local shdrnum = n[0]
print(' (shnum) '..inttohex(n[0]))

elfasserteq(elf.elf_getshdrstrndx(e, n), 0, 'elf_getshdrstrndx')
print(' (shstrndx) '..inttohex(n[0]))
local shstrndx = n[0]

elfasserteq(elf.elf_getphdrnum(e, n), 0, 'elf_getphdrnum')
local phdrnum = tonumber(n[0])
print(' (phnum) '..inttohex(n[0]))

-- all sections headers:
local shdrs = ffi.cast('Elf64_Shdr*', elfdataptr + ehdr[0].e_shoff)

local shdr_dynstr	-- sh_type == SHT_STRTAB and name == .dynstr
local shdr_dynsym 	-- sh_type == SHT_DYNSYM and name == .dynsym
local shdr_symta	-- sh_type == SHT_SYMTAB and name == .symtab
local shdr_strtab	-- sh_type == SHT_STRTAB and name == .strtab
local shdr_versym 	-- sh_type == SHT_GNU_versym
local shdr_verdef	-- sh_type == SHT_GNU_verdef
local shdr_verneed	-- sh_type == SHT_GNU_verneed
do
	print()
	print'Sections:'
	for i=1,tonumber(shstrndx)-1 do		-- is section #0 always empty?
		local scn = elfassertne(elf.elf_getscn(e, i), ffi.null, 'elf_getscn')
		local shdr = shdrs + i

		local nameptr = elfassertne(elf.elf_strptr(e, shstrndx, shdr.sh_name), ffi.null, 'elf_strptr')
		local name = ffi.string(nameptr)

		io.write('#', tostring(tonumber(elf.elf_ndxscn(scn))))
		for _,field in ipairs{'sh_flags', 'sh_addr', 'sh_offset', 'sh_size', 'sh_link', 'sh_info', 'sh_addralign', 'sh_entsize'} do
			io.write(' ', field, '=', inttohex(shdr[field]))
		end
		io.write(' sh_type='..inttohex(shdr.sh_type)..'/'..(nameForSHType[tonumber(shdr.sh_type)] or 'unknown'))
		io.write(' name="'..name..'"')
		print()

		if shdr.sh_type == elf.SHT_STRTAB
		and name == '.dynstr'
		then
			-- ... then this header is shdr_dynstr, holds the strings of SHT_DYNAMIC
			-- will this always go before SHT_DYNAMIC ?
			-- oh yeah there are multiple of these too, with names '.dynstr', '.strtab', '.shstrtab'
			assert(not shdr_dynstr)
			shdr_dynstr = shdr	-- is scn allocated?  will this pointer go bad? will its members?
		end

		-- dynamic linker symbol table
		-- "Currently, an object file may have either a section of SHT_SYMTAB type or a section of SHT_DYNSYM type, but not both"
		-- do if there's a SHT_SYMTAB then there's no SHT_DYMSYM ... is there no SHT_GNU_versym as well?  Where's the version info?
		if shdr.sh_type == elf.SHT_DYNSYM 
		and name == '.dynsym'
		then
			assert(not shdr_dynsym)
			shdr_dynsym = shdr
		end

		-- .symtab
		if shdr.sh_type == elf.SHT_SYMTAB 
		and name == '.symtab'
		then
			assert(not shdr_symtab)
			shdr_symtab = shdr
		end
		
		-- .strtab
		if shdr.sh_type == elf.SHT_STRTAB 
		and name == '.strtab'
		then
			assert(not shdr_strtab)
			shdr_strtab = shdr
		end

		-- https://refspecs.linuxfoundation.org/LSB_3.1.1/LSB-Core-generic/LSB-Core-generic/symversion.html
		-- "The special section .gnu.version which has a section type of SHT_GNU_versym shall contain the Symbol Version Table. 
		--  This section shall have the same number of entries as the Dynamic Symbol Table in the .dynsym section."
		-- but I don't see any in mine ...
		if shdr.sh_type == elf.SHT_GNU_versym then
			assert(not shdr_versym)
			shdr_versym = shdr
		end
		if shdr.sh_type == elf.SHT_GNU_verdef then
			assert(not shdr_verdef)
			shdr_verdef = shdr
		end
		if shdr.sh_type == elf.SHT_GNU_verneed then
			assert(not shdr_verneed)
			shdr_verneed = shdr
		end

		if shdr.sh_type == elf.SHT_DYNAMIC then
			local data = elfassertne(elf.elf_getdata(scn, ffi.null), ffi.null, 'elf_getdata')
			local sh_entsize = elf.gelf_fsize(e, elf.ELF_T_DYN, 1, elf.EV_CURRENT)
			for i=0,tonumber(shdr.sh_size/sh_entsize)-1 do
				local dyn = ffi.new'GElf_Dyn[1]'
				elfasserteq(elf.gelf_getdyn(data, i, dyn), dyn, 'gelf_getdyn')

				io.write('  dyn #'..i)
				io.write' '
				writeField(dyn[0].d_un, 'd_ptr')        -- Elf64_Xword, or d_ptr Elf64_Addr
				io.write(' d_tag='..inttohex(dyn[0].d_tag)..'/'..(nameForDType[tonumber(dyn[0].d_tag)] or 'unknown'))
				print()

				if dyn[0].d_tag == elf.DT_NEEDED then
					assert(shdr_dynstr, "read SHT_DYNAMIC without SHT_STRTAB")
					print("   DT_NEEDED: ", ffi.string(elfdataptr + shdr_dynstr.sh_offset + dyn[0].d_un.d_val));
				end
			end
		end
	end
	print()

	-- last section?
	local scn = elfassertne(elf.elf_getscn(e, shstrndx), ffi.null, 'elf_getscn')
	local shdr = shdrs + shstrndx
	print('shstrab size', inttohex(shdr.sh_size))
	local data
	local n = 0
	while n < shdr.sh_size do
		local data = elf.elf_getdata(scn, data)
		if data == ffi.null then break end
		print('shstrab data', ffi.string(ffi.cast('char*', data.d_buf), data.d_size))
		n = n + data.d_size
	end

	-- https://compilepeace.github.io/BINARY_DISSECTION_COURSE/ELF/SYMBOLS/SYMBOLS.html
	if shdr_dynstr and shdr_dynsym then
		
		local dynsym = ffi.cast('Elf64_Sym*', elfdataptr + shdr_dynsym.sh_offset)
		local dynsym_size = shdr_dynsym.sh_size
		local dynstr = elfdataptr + shdr_dynstr.sh_offset
		print()
		print'Dynamic Symbols:'
		for i=0,tonumber(dynsym_size/ffi.sizeof'Elf64_Sym')-1 do
			local p = dynsym[i]
			io.write('#'..i..' ')
			for _,field in ipairs{'st_name', 'st_info', 'st_other', 'st_shndx', 'st_value', 'st_size'} do
				io.write' '
				writeField(p, field)
			end
			io.write(' '..ffi.string(dynstr + p.st_name))
			print()
			
			if shdr_versym then
				local verdef = ffi.cast('GElf_Verdef*', elfdataptr + shdr_versym.sh_offset) + i
			
				io.write(' verdef: ')
				for _,field in ipairs{'vd_version', 'vd_flags', 'vd_ndx', 'vd_cnt', 'vd_hash', 'vd_aux', 'vd_next'} do
					io.write' '
					writeField(verdef[0], field)
				end
				print()
			end
		end
	end
	print()

-- this is crashing after #4, so why does it say there are 2000 or so entries?
	if shdr_strtab and shdr_symtab then
		local symtab = ffi.cast('Elf64_Sym*', elfdataptr + shdr_symtab.sh_offset)
		local symtab_size = shdr_symtab.sh_size
		local symtab_count = shdr_symtab.sh_size / shdr_symtab.sh_entsize
		print()
		print'Static Symbols:'
		local symbol_names = elfdataptr + shdrs[shdr_symtab.sh_link].sh_offset
		for i=0,tonumber(symtab_count)-1 do
			local p = symtab[i]
			io.write('#'..i..' ')
			for _,field in ipairs{'st_name', 'st_info', 'st_other', 'st_shndx', 'st_value', 'st_size'} do
				io.write' '
				writeField(p, field)
			end
			io.write(' '..ffi.string(symbol_names + p.st_name))
			print()
		end
	end
end

print()
print'Program Headers:'
for i=0,phdrnum-1 do
	local phdr = ffi.new'GElf_Phdr[1]'
	elfasserteq(elf.gelf_getphdr(e, i, phdr), phdr, 'gelf_getphdr')

	io.write('#'..i)
	io.write' ' writeField(phdr[0], 'p_offset')
	io.write' ' writeField(phdr[0], 'p_vaddr')
	io.write' ' writeField(phdr[0], 'p_paddr')
	io.write' ' writeField(phdr[0], 'p_filesz')
	io.write' ' writeField(phdr[0], 'p_memsz')
	io.write' ' writeField(phdr[0], 'p_flags')
    io.write'['
	if bit.band(phdr[0].p_flags, elf.PF_X) ~= 0 then io.write'x' end
	if bit.band(phdr[0].p_flags, elf.PF_R) ~= 0 then io.write'r' end
	if bit.band(phdr[0].p_flags, elf.PF_W) ~= 0 then io.write'w' end
	io.write']'
	io.write' ' writeField(phdr[0], 'p_align')
	io.write(' p_type='..inttohex(phdr[0].p_type)..' / '..(nameForPType[phdr[0].p_type] or 'unknown'))
	print()

	-- https://stackoverflow.com/a/78179985
	if phdr[0].p_type == elf.PT_DYNAMIC then
		local dyncount = tonumber(phdr[0].p_filesz / ffi.sizeof'Elf64_Dyn')
		local dyns = ffi.cast('Elf64_Dyn*', elfdataptr + phdr[0].p_offset)
		for i=0,dyncount-1 do

			local dyn = dyns + i
			io.write('  dyn #'..i)
			io.write' '
			writeField(dyn.d_un, 'd_ptr')        -- Elf64_Xword, or d_ptr Elf64_Addr
			io.write(' d_tag='..inttohex(dyn.d_tag)..'/'..(nameForDType[tonumber(dyn.d_tag)] or 'unknown'))
			print()

			if dyn.d_tag == elf.DT_NULL then break end
			if dyn.d_tag == elf.DT_NEEDED then
				assert(shdr_dynstr, 'read PT_DYNAMIC without SHT_STRTAB')
				local sofs = shdr_dynstr.sh_offset + dyn.d_un.d_val
				local sptr = elfdataptr + sofs
				print("  DT_NEEDED: "..inttohex(sofs)..' '..ffi.string(sptr))
			end
		end
	end
end

elf.elf_end(e)

print'DONE'
