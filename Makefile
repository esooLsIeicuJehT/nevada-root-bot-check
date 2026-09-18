.PHONY: verify inspect probe

verify:
	./tools/verify_nevada.sh

inspect: verify
	./tools/inspect_stock.sh

probe: inspect
	./tools/kernel_probe.sh
