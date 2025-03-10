all: help.html

#%.html: PANDOC_FLAGS := --metadata title=""

%.html: %.md Makefile template.html *.css
	pandoc $(PANDOC_FLAGS) -s -c m-dark.css -f markdown --standalone --template="template.html" $< > $@
