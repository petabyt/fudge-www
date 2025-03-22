OUT := help/index.html doxy writeup.html index.html blog/index.html about/index.html blog/index.html 404.html
all: $(OUT)
clean:
	rm -rf $(OUT)

#%.html: PANDOC_FLAGS := --metadata title=""

copy-assets:
	cp fudge/fastlane/metadata/android/en-US/images/phoneScreenshots/*.png img/
	cp fudge/android/app/src/main/assets/img/* img/

docs:
	mkdir docs
.PHONY: doxy
doxy: docs
	doxygen

%.html: %.md Makefile template.html *.css
	pandoc $(PANDOC_FLAGS) -M top=. -s -c m-dark.css -f markdown --standalone --template="template.html" $< > $@

%/index.html: %.md Makefile template.html *.css
	pandoc $(PANDOC_FLAGS) -M top=.. --extract-media=../ -s -c ../m-dark.css -f markdown --standalone --template="template.html" $< > $@
