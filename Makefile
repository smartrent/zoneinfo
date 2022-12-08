# Makefile for building the test database
#
# Makefile targets:
#
# all           build and install the database
# clean         clean build products and intermediates
#
# Variables to override:
#
# MIX_APP_PATH  path to the build directory
# CC_FOR_BUILD  C compiler

# Since this is for test purposes, be sure this matches what the tz (or tzdata)
# libraries use or you'll get discrepancies that are ok.
TZDB_VERSION=2022f
TZDB_NAME=tzdb-$(TZDB_VERSION)
TZDB_FILENAME=$(TZDB_NAME).tar.lz
TZDB_URL=https://data.iana.org/time-zones/releases/$(TZDB_FILENAME)

# Specifying dates that resemble things for humans is hard
# in Makefiles aparently. The following go from 1940 to 2038.
# Sometimes `date -d 1940-01-01T00:00:00 "+%s"` works.
FROM_DATE_EPOCH=-946753200
TO_DATE_EPOCH=2147483648
ZIC_OPTIONS=-r @$(FROM_DATE_EPOCH)/@$(TO_DATE_EPOCH)
#ZIC_OPTIONS=-r @0/@2147483648

PREFIX = $(MIX_APP_PATH)/priv
BUILD  = $(MIX_APP_PATH)/obj
TZDB_DIR = $(BUILD)/tzdb-$(TZDB_VERSION)

CC_FOR_BUILD=cc

ifeq ($(shell uname -s),Darwin)
# MacOS doesn't have the getrandom syscall. This is used for temporary filename generation in zic.
CFLAGS+=-DHAVE_GETRANDOM=false
endif

calling_from_make:
	mix compile

all: $(PREFIX)/zoneinfo

### Copied from tzcode Makefile

# Package name for the code distribution.
PACKAGE=        tzcode

# Version number for the distribution, overridden in the 'tarballs' rule below.
VERSION=        unknown

# Email address for bug reports.
BUGEMAIL=       tz@iana.org

# Backwards compatibility
BACKWARD=       backward

# Everything that's normally installed
PRIMARY_YDATA=  africa antarctica asia australasia \
                europe northamerica southamerica
YDATA=          $(PRIMARY_YDATA) etcetera
NDATA=          factory
TDATA=          $(YDATA)

$(TZDB_DIR)/version.h: $(TZDB_DIR)/version
	VERSION=`cat $(TZDB_DIR)/version` && printf '%s\n' \
		'static char const PKGVERSION[]="($(PACKAGE)) ";' \
		"static char const TZVERSION[]=\"$$VERSION\";" \
		'static char const REPORT_BUGS_TO[]="$(BUGEMAIL)";' \
		>$@.out
	mv $@.out $@

### End copied definitions

$(TZDB_DIR)/zic: $(TZDB_DIR) $(TZDB_DIR)/zic.c $(TZDB_DIR)/version.h
	@echo " HOSTCC $(notdir $@)"
	$(CC_FOR_BUILD) $(CFLAGS) -o $@ $(TZDB_DIR)/zic.c

$(PREFIX)/zoneinfo: $(TZDB_DIR)/zic $(PREFIX) Makefile
	@echo "    ZIC $(notdir $@)"
	cd $(TZDB_DIR) && ./zic -d $@ $(ZIC_OPTIONS) $(TDATA)

$(TZDB_FILENAME):
	@echo "   WGET $(notdir $@)"
	wget $(TZDB_URL)

$(TZDB_DIR): $(TZDB_FILENAME) $(BUILD)
	@echo "  UNTAR $(TZDB_FILENAME)"
	$(RM) -r $@
	cd $(BUILD) && lzip -d -c $(PWD)/$(TZDB_FILENAME) | tar x

$(PREFIX) $(BUILD):
	mkdir -p $@

clean:
	$(RM) -r $(BUILD) $(PREFIX)

.PHONY: all clean calling_from_make

# Don't echo commands unless the caller exports "V=1"
${V}.SILENT:
