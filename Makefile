NAME := hello

TARGET := $(NAME).bin
LST := $(NAME).lst
SYM := $(NAME).sym

BUILD_DIR := ./build
SRC_DIRS := ./src

SRCS := src/main.asm

SJASM := sjasmplus
EEPROM_PROGRAMMER := eeprom-programmer
TIO := tio

SJASM_FLAGS := -Wall

all: $(BUILD_DIR)/$(TARGET)

$(BUILD_DIR)/$(TARGET): $(SRCS)
	mkdir -p $(BUILD_DIR)
	$(SJASM) $(SJASM_FLAGS) --raw=$@ --lst=$(BUILD_DIR)/$(LST) --sym=$(BUILD_DIR)/$(SYM) $^

upload: $(BUILD_DIR)/$(TARGET)
	$(EEPROM_PROGRAMMER) $(EPFLAGS) 'unlock' 'write $<' 'lock'

verify: $(BUILD_DIR)/$(TARGET)
	$(EEPROM_PROGRAMMER) $(EPFLAGS) 'verify $<'

monitor:
	$(TIO) $(TIO_FLAGS) -b 1200 $(TTY)

clean:
	rm -rf $(BUILD_DIR)

.PHONY: clean all upload verify monitor
