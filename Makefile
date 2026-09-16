WIPPY ?= $(abspath ../app/bin/wippy-floppy)
.PHONY: test lint demo ski art
test:
	cd test && $(WIPPY) test --host wippy.terminal:host
lint:
	python3 ../shell/tools/late-locals.py src
	python3 ../shell/tools/late-locals.py test
	cd test && $(WIPPY) lint
demo:
	cd ../runtime && go run ../floppy/tools/demo.go ../floppy/disks/hello.wapp

ski:
	cd ../runtime && go run ../floppy/tools/ski.go ../floppy/disks/ski.wapp

art:
	python3 tools/setup_art.py
