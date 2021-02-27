SRC	= c64_play.a65
PRG	= c64_play.prg
PRG65	= m65_play.prg
CL65	= cl65
#CL65OPT	= -t none --config ld.cfg
CL65OPT	= -t none
VICE	= x64
XEMU	= xemu-xmega65
M65	= m65
ALLDEP	= Makefile test.dro ld.cfg

all: $(PRG) $(PRG65)

$(PRG): $(SRC) $(ALLDEP)
	@echo "*** Compiling $< to $@ for C64/M65 with SFX cartridge/compatibility mode ..."
	$(CL65) $(CL65OPT) -o $@ $<
	cp $@ prg-files/

$(PRG65): $(SRC) $(ALLDEP)
	@echo "*** Compiling $< to $@ for M65 only for its native OPL access mode ..."
	$(CL65) --asm-define MEGA65 $(CL65OPT) -o $@ $<
	cp $@ prg-files/

vice: $(PRG)
	$(VICE) -sfxse -sfxsetype 3812 -autostartprgmode 1 -autostart $<

xemu: $(PRG65)
	$(XEMU) -prg $<

mega65: $(PRG65)
	$(M65) -F -4 -r $<

clean:
	rm -f *.o *.prg

.PHONY: vice xemu mega65 clean all
