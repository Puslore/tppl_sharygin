FILE = data.txt

all: average

average: average.o
	ld average.o -o average

average.o: main.asm
	nasm -felf64 main.asm -o average.o

run: average data.txt
# 	@./average "$(FILE)"
	@./average data.txt

# data.txt:
# 	@echo "5, 3, 2, 6, 1, 7, 4" > $@
# 	@echo "0, 10, 1, 9, 2, 8, 5" >> $@

clean:
	rm -f average average.o

.PHONY: all run clean