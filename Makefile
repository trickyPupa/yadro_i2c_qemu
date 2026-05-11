CC = gcc

PROGRAM_NAME = 
TARGET = $(PROGRAM_NAME)
SOURCES = $(shell find src -name '*.c')

.PHONY: build clean

build: 
	$(CC) $(SOURCES) -o $(TARGET)

clean:
	rm -f $(TARGET)
