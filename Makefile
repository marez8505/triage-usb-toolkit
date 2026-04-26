.PHONY: help validate lint smoke test all

help:
	@echo "Targets:"
	@echo "  validate   - Validate manifests + run shell/pwsh syntax checks"
	@echo "  lint       - Run shellcheck/pwsh parse if available"
	@echo "  smoke      - Run the build_usb.sh smoke test against a temp dir"
	@echo "  test       - validate + smoke"

validate:
	@bash tests/validate_manifests.sh

lint:
	@bash tests/syntax_check.sh

smoke:
	@bash tests/smoke_build_usb.sh

test: validate lint smoke
	@echo "[ok] all checks passed"
