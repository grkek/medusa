# Platform detection
UNAME_S := $(shell uname -s)
UNAME_M := $(shell uname -m)

# Compiler and base flags
CC = cc
CXXFLAGS = -std=c++20
LDFLAGS = -lgc

# Platform-specific paths
ifeq ($(UNAME_S),Darwin)
	# macOS
	ifeq ($(UNAME_M),arm64)
		# Apple Silicon
		CXXFLAGS += -I/opt/homebrew/include
		LDFLAGS += -L/opt/homebrew/lib
	else
		# Intel
		CXXFLAGS += -I/usr/local/include
		LDFLAGS += -L/usr/local/lib
	endif
else
	# Linux (and others)
	CXXFLAGS += -I/usr/include -I/usr/local/include
	LDFLAGS += -L/usr/lib -L/usr/local/lib
endif

# Directories
SRC_DIR = ./src/ext
BIN_DIR = ./bin
OBJ_FILES = $(patsubst $(SRC_DIR)/%.cpp,$(BIN_DIR)/%.o,$(wildcard $(SRC_DIR)/*.cpp))

build:
	mkdir -p $(BIN_DIR)
	$(CC) $(CXXFLAGS) -c $(SRC_DIR)/*.cpp
	mv *.o $(BIN_DIR)/
	ar rcs $(BIN_DIR)/medusa.a $(BIN_DIR)/*.o

quickjs:
	cd ./src/ext/quickjs && make all

test:
	make quickjs
	make build
	crystal spec

clean:
	rm -rf $(BIN_DIR)/*
	cd ./src/ext/quickjs && make clean

.PHONY: build quickjs test clean