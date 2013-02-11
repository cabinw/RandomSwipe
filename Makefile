CC=xcrun --sdk iphoneos clang -arch armv7
CFLAGS=-O3 -fobjc-arc
LDFLAGS=-framework UIKit

RandomSwipe: RandomSwipe.m
	$(CC) $(CFLAGS) -o $@ $< $(LDFLAGS)
	ldid -S $@

clean:
	rm -f RandomSwipe

.PHONY: clean

