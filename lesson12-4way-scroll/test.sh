FILE=$1
FILE_TEST=test/"$FILE".test
FILE_ASM=test/"$FILE"_test.asm
ca65 -t nes "$FILE_ASM" -g -o "out/test.o" && \
echo -ne "  TEST: assembler ok!\n" && \
ld65 -C "test.cfg" -o "out/test.bin" "out/test.o" && \
echo -ne "  TEST: linker ok!\n" && \
cat $FILE_TEST | soft65c02 -s | rg "Registers|#5|#6"
