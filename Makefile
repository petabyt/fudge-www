all: help/index.html doxy writeup.html index.html blog/index.html about/index.html blog/index.html

#%.html: PANDOC_FLAGS := --metadata title=""

copy-assets:
	cp fudge/fastlane/metadata/android/en-US/images/phoneScreenshots/*.png img/
	cp fudge/android/app/src/main/assets/img/* img/

.PHONY: doxy
doxy:
	doxygen

%.html: %.md Makefile template.html *.css
	pandoc $(PANDOC_FLAGS) -M top=. -s -c m-dark.css -f markdown --standalone --template="template.html" $< > $@

%/index.html: %.md Makefile template.html *.css
	pandoc $(PANDOC_FLAGS) -M top=.. --extract-media=../ -s -c ../m-dark.css -f markdown --standalone --template="template.html" $< > $@
