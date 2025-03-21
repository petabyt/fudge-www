all: help.html doxy writeup.html index.html

#%.html: PANDOC_FLAGS := --metadata title=""

.PHONY: doxy
doxy:
	doxygen

%.html: %.md Makefile template.html *.css
	pandoc $(PANDOC_FLAGS) -s -c m-dark.css -f markdown --standalone --template="template.html" $< > $@
