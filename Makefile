INSTALLDIR = ~/Desktop/Kerbal\\\ Space\\\ Program/Ships/Script
STAGEDIR = packed

files := $(wildcard *.ks)
packed := $(foreach file, $(files:.ks=.ksp), $(STAGEDIR)/$(file))
installed := $(foreach file, $(files), $(INSTALLDIR)/$(file))

all : $(packed)

install : $(installed)

clean :
	rm $(packed);

$(STAGEDIR)/%.ksp : %.ks
	./packer.sed < $< | /bin/sed -e 's|^\s*\(.*\)\s*$$|\1|g' -e '/^$$/d' | /bin/tr '\n' ' '  > $@;

$(INSTALLDIR)/%.ks : $(STAGEDIR)/%.ksp
	cp $< $@;
