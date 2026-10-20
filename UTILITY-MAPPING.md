# PC DOS 1.10 utility assembly mapping

All three binaries are feasible to reconstruct. The prepared MASM sources assemble, link, convert to COM, and match the original `bin/` binaries byte for byte. These sources replace the initial generated disassemblies.

| Program | Total bytes | Instructions | Code bytes | Data bytes | SHA-256 of original and rebuilt COM |
|---|---:|---:|---:|---:|---|
| DISKCOPY | 2008 | 414 | 1142 | 866 | `b5249a29c97c55d09a8777a770749a07b38a734d3314ca594e889cf5b45306ab` |
| DISKCOMP | 1640 | 347 | 998 | 642 | `5a639dd19e97fdcaf91982d998a50f282a005d4a332fc1ba51807bb5976f76a0` |
| CHKDSK | 1720 | 422 | 1014 | 706 | `5da88fa93d2684876fc7322a07d2042d4ec33c6a946cda30728dfbda03bf4c1a` |

## Verification

Run `make -B check-utilities` from the project directory. This forces the three complete MASM 1.10 -> IBM LINK 1.10 -> EXE2BIN builds, then compares each result with its reference using `cmp`. All three comparisons passed on 2026-10-20; MASM reported zero warnings and zero errors. LINK reports its usual “No STACK segment” warning for these single-segment COM programs; EXE2BIN conversion and byte comparisons succeed.

Address and byte details now live in the mapping tables; the cleaned-up DISKCOPY/DISKCOMP source comments explain intent. The accompanying `*.mapping.tsv` files account for every byte, with file offset, COM address, length, code/data classification, source line, hex bytes, and assembly statement. A separate audit checked continuity and every mapping row against the reference binary; no gaps or overlaps remain. TSV source line numbers refer to this delivered revision and need regenerating after source edits.

## Findings and encoding constraints

- The first-pass sources decode copyright banners, message strings, variable storage, and tables as code. They also introduce spurious jumps and labels; they are not reliable byte-exact baselines.
- The original `.dis` files use file offsets. COM runtime addresses are those offsets plus `0100h`.
- Both disk utilities contain the 8086 opcode `82h` form of group-1 byte operations. This installed `ndisasm` fails to recognize it and loses instruction alignment. The corrected mapping uses the equivalent `80h` form only for decoding, restores the original bytes, and checks that no operand bytes changed. The source's `rawop` macro preserves each original `82h` encoding, with its decoded mnemonic beside it.
- The `jmpn` macro preserves `E9` near jumps that MASM might shorten. Other code assembles as instructions; data is expressed with `db`, including readable ASCII strings.
- Named routines, key state variables, PSP fields, and routine comments follow the structure of `edlin102.asm`. Unresolved meanings retain address-based `loc_XXXX` / `data_XXXX` names. The fixed data equates intentionally preserve this binary's exact layout; code size changes require updating addresses.

## Memory layout (COM addresses, inclusive)

| Program | Code | Initialized data |
|---|---|---|
| DISKCOPY | 0100–0102, 019D–0534, 07AC–0886 | 0103–019C, 0535–07AB, 0887–08D7 |
| DISKCOMP | 0100–0102, 01A6–048A, 0619–0716 | 0103–01A5, 048B–0618, 0717–0767 |
| CHKDSK | 0100–04F5 | 04F6–07B7 |

DISKCOPY and DISKCOMP allocate transfer buffers after their resident portions; initialization code is disposable. CHKDSK's runtime work area starts at `07B8h`, just beyond the image. Initialized padding and zero-filled storage remain in the file to preserve its full size.

## Scope

Byte identity and complete static byte coverage are verified. Routine names and comments are interpretations of the code, not recovered original source symbols. Comprehensive semantic documentation and emulator execution tests remain future work. The original binaries, `.dis` and `.xxd` reference files are unchanged. Distribution recipes still copy their original `bin/` utilities; the new standalone targets build reconstructions for checking.

Byte maps have moved to `mappings/<utility>.tsv` to avoid emu2 8.3 filename collisions with LINK output. See `MODE-FORMAT-COMP.md` for the extended build and checks.

See `ASM-READABILITY.md` for the source readability pass. Hex listings are kept in `mappings/`; source comments explain intent. In-image data has typed declarations beside its bytes.

See `FILCOM-EXE2BIN.md` for the FILCOM/EXE2BIN sources, complete MZ-container reconstruction, runtime comparisons, and canonical `ibmboot` naming.
