NAME := hello

TARGET := $(NAME).bin
LST := $(NAME).lst
SYM := $(NAME).sym

BUILD_DIR := ./build

SRC_DIRS = ./src

INC_DIRS = $(shell find $(SRC_DIRS) -type d)
INC_FLAGS := $(addprefix -I,$(INC_DIRS))

SRCS := $(shell find $(SRC_DIRS) -name '*.asm')
INC_SRCS = $(shell find $(INC_DIRS) -name '*.inc')

SRC_MAIN := src/main.asm

SJASM := sjasmplus
EEPROM_PROGRAMMER := eeprom-programmer
TIO := tio

SJASM_FLAGS := $(INC_FLAGS) -Wall

all: $(BUILD_DIR)/$(TARGET)

$(BUILD_DIR)/$(TARGET): $(SRCS) $(INC_SRCS)
	mkdir -p $(BUILD_DIR)
	$(SJASM) $(SJASM_FLAGS) --raw=$@ --lst=$(BUILD_DIR)/$(LST) --sym=$(BUILD_DIR)/$(SYM) $(SRC_MAIN)

upload: $(BUILD_DIR)/$(TARGET)
	$(EEPROM_PROGRAMMER) $(EPFLAGS) 'unlock' 'write $<' 'lock'

verify: $(BUILD_DIR)/$(TARGET)
	$(EEPROM_PROGRAMMER) $(EPFLAGS) 'verify $<'

monitor:
	$(TIO) $(TIO_FLAGS) -b 15625 $(TTY)

clean:
	rm -rf $(BUILD_DIR)

.PHONY: clean all upload verify monitor
