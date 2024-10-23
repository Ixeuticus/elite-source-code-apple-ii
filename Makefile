BEEBASM?=beebasm
PYTHON?=python

# A make command with no arguments will build the source disc variant with
# encrypted binaries, checksums enabled, the standard commander and crc32
# verification of the game binaries
#
# Optional arguments for the make command are:
#
#   variant=<release>   Build the specified variant:
#
#                         ib-disk (default)
#                         source-disk-build (the binaries we get from running a build)
#                         source-disk-code-files (the CODE* binaries already on the source disc)
#                         source-disk-elt-files (the ELT* binaries already on the source disc)
#
#   commander=max       Start with a maxed-out commander
#
#   encrypt=no          Disable encryption and checksum routines
#
#   match=no            Do not attempt to match the original game binaries
#                       (i.e. omit workspace noise)
#
#   verify=no           Disable crc32 verification of the game binaries
#
# So, for example:
#
#   make variant=source-disk-build commander=max encrypt=no match=no verify=no
#
# will build an unencrypted source disc variant with a maxed-out commander,
# no workspace noise and no crc32 verification
#
# The following variables are written into elite-build-options.asm depending on
# the above arguments, so they can be passed to BeebAsm:
#
# _VERSION
#   9 = Apple II
#
# _VARIANT
#   1 = Ian Bell's game disc (default)
#   2 = source disc build (the binaries from running a build of the source disc)
#   3 = source disc CODE files (the CODE* binaries already on the source disc)
#   4 = source disc ELT files (the ELT* binaries already on the source disc)
#
# _MAX_COMMANDER
#   TRUE  = Maxed-out commander
#   FALSE = Standard commander
#
# _REMOVE_CHECKSUMS
#   TRUE  = Disable checksum routines
#   FALSE = Enable checksum routines
#
# _MATCH_ORIGINAL_BINARIES
#   TRUE  = Match binaries to released version (i.e. fill workspaces with noise)
#   FALSE = Zero-fill workspaces
#
# The encrypt and verify arguments are passed to the elite-checksum.py and
# crc32.py scripts, rather than BeebAsm

ifeq ($(commander), max)
  max-commander=TRUE
else
  max-commander=FALSE
endif

ifeq ($(encrypt), no)
  unencrypt=-u
  remove-checksums=TRUE
else
  unencrypt=
  remove-checksums=FALSE
endif

ifeq ($(match), no)
  match-original-binaries=FALSE
else
  match-original-binaries=TRUE
endif

ifeq ($(variant), source-disk-build)
  variant-number=2
  folder=/source-disk-build
  suffix=-source-disk-build
else ifeq ($(variant), source-disk-code-files)
  variant-number=3
  folder=/source-disk-code-files
  suffix=-source-disk-code-files
else ifeq ($(variant), source-disk-elt-files)
  variant-number=4
  folder=/source-disk-elt-files
  suffix=-source-disk-elt-files
else
  variant-number=1
  folder=/ib-disk
  suffix=-ib-disk
endif

.PHONY:all
all: apple-build apple-disk

apple-build:
	echo _VERSION=9 > 1-source-files/main-sources/elite-build-options.asm
	echo _VARIANT=$(variant-number) >> 1-source-files/main-sources/elite-build-options.asm
	echo _REMOVE_CHECKSUMS=$(remove-checksums) >> 1-source-files/main-sources/elite-build-options.asm
	echo _MATCH_ORIGINAL_BINARIES=$(match-original-binaries) >> 1-source-files/main-sources/elite-build-options.asm
	echo _MAX_COMMANDER=$(max-commander) >> 1-source-files/main-sources/elite-build-options.asm
	$(BEEBASM) -i 1-source-files/main-sources/elite-data.asm -v > 3-assembled-output/compile.txt
	$(BEEBASM) -i 1-source-files/main-sources/elite-source.asm -v >> 3-assembled-output/compile.txt
	$(BEEBASM) -i 1-source-files/main-sources/elite-bcfs.asm -v >> 3-assembled-output/compile.txt
	$(BEEBASM) -i 1-source-files/main-sources/elite-mover.asm -v >> 3-assembled-output/compile.txt
	$(PYTHON) 2-build-files/elite-checksum.py $(unencrypt) -rel$(variant-number)
	$(BEEBASM) -i 1-source-files/main-sources/elite-transfer.asm -v >> 3-assembled-output/compile.txt
	$(BEEBASM) -i 1-source-files/main-sources/elite-readme.asm -v >> 3-assembled-output/compile.txt
	#$(BEEBASM) -i 1-source-files/main-sources/elite-disc.asm -do 5-compiled-game-discs/elite-apple$(suffix).ssd -title "E L I T E"
ifneq ($(verify), no)
	@$(PYTHON) 2-build-files/crc32.py 4-reference-binaries$(folder) 3-assembled-output
endif

apple-disk:
ifeq ($(variant-number), 1)
	rm -fr 5-compiled-game-discs/*.bin
	cp 1-source-files/other-files$(folder)/blank.dsk 5-compiled-game-discs/elite-apple$(suffix).dsk
	cp 1-source-files/images$(folder)/A.SCREEN.bin 5-compiled-game-discs/elitepic#0x2000.bin
	cp 3-assembled-output/DATA.bin 5-compiled-game-discs/bee#0x3b00.bin
	cp 3-assembled-output/CODE1.bin 5-compiled-game-discs/four#0x4000.bin
	cp 3-assembled-output/CODE2.bin 5-compiled-game-discs/nine#0x5000.bin
	cp 3-assembled-output/MOVER.bin 5-compiled-game-discs/mover#0x0300.bin
	#diskm8 -with-disk 5-compiled-game-discs/elite-apple$(suffix).dsk -file-put 1-source-files/other-files/hello#0x0801.bas
	diskm8 -with-disk 5-compiled-game-discs/elite-apple$(suffix).dsk -file-put 5-compiled-game-discs/elitepic#0x2000.bin
	diskm8 -with-disk 5-compiled-game-discs/elite-apple$(suffix).dsk -file-put 5-compiled-game-discs/nine#0x5000.bin
	diskm8 -with-disk 5-compiled-game-discs/elite-apple$(suffix).dsk -file-put 5-compiled-game-discs/bee#0x3b00.bin
	diskm8 -with-disk 5-compiled-game-discs/elite-apple$(suffix).dsk -file-put 5-compiled-game-discs/four#0x4000.bin
	diskm8 -with-disk 5-compiled-game-discs/elite-apple$(suffix).dsk -file-put 5-compiled-game-discs/mover#0x0300.bin
	diskm8 -with-disk 5-compiled-game-discs/elite-apple$(suffix).dsk -file-put 3-assembled-output/readme.txt
	rm -fr 5-compiled-game-discs/*.bin
endif
