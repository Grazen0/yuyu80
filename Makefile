TARGET := hello.bin
LST := hello.lst

BUILD_DIR := ./build
SRC_DIRS := ./src

SRCS := src/main.asm

ZASM := zasm
EEPROM_PROGRAMMER := eeprom-programmer

all: $(BUILD_DIR)/$(TARGET)

$(BUILD_DIR)/$(TARGET): $(SRCS)
	mkdir -p $(BUILD_DIR)
	$(ZASM) -o $@ -l $(BUILD_DIR)/$(LST) -uwy $^

upload: $(BUILD_DIR)/$(TARGET)
	$(EEPROM_PROGRAMMER) $(EPFLAGS) 'unlock' 'write $<' 'lock'

verify: $(BUILD_DIR)/$(TARGET)
	$(EEPROM_PROGRAMMER) $(EPFLAGS) 'verify $<'

monitor:
	screen $(TTY) 1200 -parenb cs8 -cstob $(SCREENFLAGS)

clean:
	rm -rf $(BUILD_DIR)

.PHONY: clean all upload verify monitor
