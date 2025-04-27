# Name
name		:= isotank
debug		:= 2

# C compiler for tools
CC = gcc

sourcedir := src
resdir := data
src := $(wildcard $(sourcedir)/%.s)
tools := tools
objs := obj

PY := python

# If you use Linux, replace this with the Linux executeable.
SNESMOD := $(tools)/smconv.exe

derived_files := $(sourcedir)/sinlut.i $(sourcedir)/idlut.i \
	$(resdir)/m7iso.png.tiles $(resdir)/m7iso.png.palette \
	$(resdir)/tankpale.png.palette \
	$(resdir)/game_music \
	$(sourcedir)/qubo.i

$(resdir)/tankpale.png.palette: palette_flags = -v --colors 16 -R
$(resdir)/m7iso.png.tiles: tiles_flags = -v -B 8 -M snes_mode7 -D -F

#$(resdir)/chunktest.png.pbm: map_flags = -v -M snes_mode7 -p $(resdir)/chunktestpalette.png.palette \
#	-t $(resdir)/chunktestpalette.png.tiles

# Include libSFX.make
libsfx_dir	:= ../libSFX
include $(libsfx_dir)/libSFX.make

run_args := $(rom)

itlisto := $(foreach dir,$(resdir),$(wildcard $(dir)/*.it))

# Alternate derived files filter
$(filter %.pbm,$(derived_files)) : %.pbm : %
	$(superfamiconv) map $(map_flags) --in-image $* --out-data $@
	
$(resdir)/game_music: $(itlisto)
	$(SNESMOD) -v -s $(itlisto) -o $@

# Replace .exe with whatever executable format your OS uses
$(sourcedir)/sinlut.i: $(tools)/sinlutgen.exe
	$< $@
	
$(tools)/sinlutgen.exe: $(tools)/sinlutgen.c
	$(CC) -o $@ $<

#$(sourcedir)/divlut.i: $(tools)/divlutgen.exe
#	$< $@
	
#$(tools)/divlutgen.exe: $(tools)/divlutgen.c
#	$(CC) -o $@ $<
	
$(sourcedir)/idlut.i: $(tools)/idlutgen.exe
	$< $@
	
$(tools)/idlutgen.exe: $(tools)/idlutgen.c
	$(CC) -o $@ $<
	
$(sourcedir)/tankmdl.i: $(objs)/tanke.obj
	$(PY) $(tools)/wavefront2isot.py $< $@ tanke 2
	
.PHONY: romused

romused: $(rom)
	$(PY) $(tools)/romusage.py $<