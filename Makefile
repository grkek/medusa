# Platform detection
UNAME_S := $(shell uname -s)
UNAME_M := $(shell uname -m)

# Compiler and base flags
CC = cc
CXXFLAGS = -std=c++20 -O2 -DNDEBUG
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

QUICKJS_DIR = ./src/ext/quickjs
QUICKJS_REPO = https://github.com/bellard/quickjs

fetch-quickjs:
	@if [ ! -f $(QUICKJS_DIR)/Makefile ]; then \
		echo "QuickJS not found, fetching..."; \
		if git submodule status $(QUICKJS_DIR) > /dev/null 2>&1; then \
			git submodule update --init --recursive; \
		else \
			git clone --depth 1 $(QUICKJS_REPO) $(QUICKJS_DIR); \
		fi \
	fi

build:
	mkdir -p $(BIN_DIR)
	$(CC) $(CXXFLAGS) -c $(SRC_DIR)/*.cpp
	mv *.o $(BIN_DIR)/
	ar rcs $(BIN_DIR)/medusa.a $(BIN_DIR)/*.o

quickjs: fetch-quickjs
	@# Ensure -DNDEBUG is in QuickJS CFLAGS to disable gc_obj_list assertion
	@cd $(QUICKJS_DIR) && \
		grep -q 'DNDEBUG' Makefile || \
		sed -i.bak 's/^CFLAGS_OPT=$$(CFLAGS) -O2/CFLAGS_OPT=$$(CFLAGS) -O2 -DNDEBUG/' Makefile
	cd $(QUICKJS_DIR) && make libquickjs.a

test:
	make quickjs
	make build
	crystal spec

clean:
	rm -rf $(BIN_DIR)/*
	@if [ -f $(QUICKJS_DIR)/Makefile ]; then cd $(QUICKJS_DIR) && make clean; fi

.PHONY: build quickjs test clean fetch-quickjs