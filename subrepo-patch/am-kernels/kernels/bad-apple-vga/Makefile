NAME = bad-apple-vga
SRCS = bad-apple-vga.c

FPS ?= 30
VIDEO_FPS ?= 30
FRAMES ?= 6500
VIDEO_SRC = ../bad-apple/bad-apple.mp4
VIDEO = build/video-$(VIDEO_FPS)-$(FRAMES).frame
VIDEO_OFFSET = 1048576

CFLAGS += -DFPS=$(FPS) -DFRAMES=$(FRAMES)

$(VIDEO): $(VIDEO_SRC)
	@mkdir -p build
	ffmpeg -v error -i $(VIDEO_SRC) -vf fps=$(VIDEO_FPS) -frames:v $(FRAMES) \
	  -f image2pipe -s 160x120 -vcodec rawvideo -pix_fmt monow -y $@

include $(AM_HOME)/Makefile

.PHONY: append-video
append-video: image $(VIDEO)
	dd if=$(VIDEO) of=$(IMAGE).bin bs=1M seek=1 conv=notrunc
