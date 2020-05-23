.PHONY: main test clean

main : out/main.o
	ld65 -C "ines.cfg" -o "out/main.nes" --dbgfile "out/main.dbg" "out/main.o"

out/main.o :
	ca65 -t nes "main.asm" -g -o "out/main.o"

test :
	for FILE in test/*.test; do \
	  FILE=$${FILE##*/}; \
	  NAME=$${FILE%.test}; \
	  ca65 -t nes "test/$${NAME}_test.asm" -g -o "out/test/$${NAME}.o"; \
	  ld65 -C "test.cfg" -o "out/test/$${NAME}.bin" "out/test/$${NAME}.o"; \
	done

clean :
	rm -f out/*.o \
	      out/*.nes \
	      out/*.dbg \
	      out/test/*.o \
	      out/test/*.bin \
	      out/test/*.run
