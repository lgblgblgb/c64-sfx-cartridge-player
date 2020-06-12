SRC	= c64_play.a65
PRG	= c64_play.prg
PRG65	= m65_play.prg
CL65	= cl65
VICE	= x64
XEMU	= /home/lgb/prog_here/xemu/build/bin/xmega65.native

all: $(PRG) $(PRG65)

$(PRG): $(SRC) Makefile
	$(CL65) -t none -o $@ $<

$(PRG65): $(SRC) Makefile
	$(CL65) --asm-define MEGA65 -t none -o $@ $<

vice: $(PRG)
	$(VICE) -sfxse -sfxsetype 3812 -autostartprgmode 1 -autostart $<

xemu: $(PRG65)
	$(XEMU) -go64 -8 $<

clean:
	rm -f *.o *.prg

.PHONY: vice xemu clean all
