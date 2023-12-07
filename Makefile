ONTOLOGY_IRI := http:\/\/example.org\/ontologies\/mno
ONTOLOGY_SHORT := mno
IRI_BASE := http:\/\/example.org\/ontologies\/mno#

MKDIR_P = mkdir -p
VERSION:= $(shell cat VERSION)
VERSIONDIR := build/$(ONTOLOGY_SHORT)/$(VERSION)
ONTOLOGY_SOURCE := src/ontology

subst_paths =	${subst $(ONTOLOGY_SOURCE),$(VERSIONDIR),${patsubst $(ONTOLOGY_SOURCE)/edits/%,$(ONTOLOGY_SOURCE)/modules/%,$(1)}}


OWL_FILES := $(call subst_paths,$(shell find $(ONTOLOGY_SOURCE)/* -type f -name "*.owl"))
TTL_FILES := $(call subst_paths,$(shell find $(ONTOLOGY_SOURCE)/* -type f -name "*.ttl"))



OWL_COPY := $(OWL_FILES)

TTL_COPY :=	$(TTL_FILES)

TTL_TRANSLATE := ${patsubst %.ttl,%.owl,$(TTL_FILES)}

RM=/bin/rm
ROBOT_PATH := build/robot.jar
ROBOT := java -jar $(ROBOT_PATH)



define replace_devs
	sed -i -E "s/$(IRI_BASE)\/dev\/([a-zA-Z/\.\-]+)/$(IRI_BASE)\/releases\/$(VERSION)\/\1/m" $1
endef

define replace_oms
	sed -i -E "s/($(IRI_BASE)\/dev\/([a-zA-Z/\-]+)\.)ttl/\1owl/m" $1
	sed -i -E "s/($(IRI_BASE)\/releases\/$(VERSION)\/([a-zA-Z/\-]+)\.)ttl/\1owl/m" $1
endef

define replace_owls
	sed -i -E "s/($(IRI_BASE)\/dev\/([a-zA-Z/\-]+)\.)owl/\1ttl/m" $1
	sed -i -E "s/($(IRI_BASE)\/releases\/$(VERSION)\/([a-zA-Z/\-]+)\.)owl/\1ttl/m" $1
endef

define translate_to_owl
	$(ROBOT) convert --catalog $(VERSIONDIR)/catalog-v001.xml --input $2 --output $1 --format owl
	$(call replace_ttls,$1)
	$(call replace_devs,$1)
endef

define translate_to_ttl
	$(ROBOT) convert --catalog $(VERSIONDIR)/catalog-v001.xml --input $2 --output $1 --format ttl
	$(call replace_owls,$1)
	$(call replace_devs,$1)
endef

.PHONY: all clean base merge directories

all: base merge

base: | directories $(VERSIONDIR)/catalog-v001.xml build/robot.jar $(OWL_COPY) $(TTL_COPY) $(TTL_TRANSLATE)

merge: | $(VERSIONDIR)/$(ONTOLOGY_SHORT)-full.ttl

closure: | $(VERSIONDIR)/$(ONTOLOGY_SHORT)-closure.owl

clean:
	- $(RM) -r $(VERSIONDIR) $(ROBOT_PATH)

directories: ${VERSIONDIR}/imports ${VERSIONDIR}/modules

${VERSIONDIR}/imports:
	${MKDIR_P} ${VERSIONDIR}/imports

${VERSIONDIR}/modules:
	${MKDIR_P} ${VERSIONDIR}/modules

$(VERSIONDIR)/catalog-v001.xml: src/ontology/catalog-v001.xml
	cp $< $@
	$(call replace_devs,$@)
	sed -i -E "s/edits\//modules\//m" $@

build/robot.jar: | build
	curl -L -o $@ https://github.com/ontodev/robot/releases/download/v1.9.2/robot.jar


$(VERSIONDIR)/%.owl: $(VERSIONDIR)/%.ttl
	$(call translate_to_owl,$@,$<)

$(VERSIONDIR)/modules/%.owl: $(VERSIONDIR)/edits/%.ttl
	$(call translate_to_owl,$@,$<)

$(VERSIONDIR)/%.owl: $(ONTOLOGY_SOURCE)/%.owl
	cp -a $< $@
	$(call replace_devs,$@)

$(VERSIONDIR)/modules/%.owl: $(ONTOLOGY_SOURCE)/edits/%.owl
	cp -a $< $@
	$(call replace_devs,$@)

$(VERSIONDIR)/modules/%.ttl: $(ONTOLOGY_SOURCE)/edits/%.ttl
	cp -a $< $@
	$(call replace_devs,$@)

$(VERSIONDIR)/%.ttl: $(ONTOLOGY_SOURCE)/%.ttl
	cp -a $< $@
	$(call replace_devs,$@)

$(VERSIONDIR)/$(ONTOLOGY_SHORT)-full.owl : | base
	$(ROBOT) merge --catalog $(VERSIONDIR)/catalog-v001.xml $(foreach f, $(VERSIONDIR)/$(ONTOLOGY_SHORT).owl $(TTL_COPY) $(OWL_COPY), --input $(f)) annotate --ontology-iri $(ONTOLOGY_IRI) --output $@
	$(call replace_oms,$@)

$(VERSIONDIR)/$(ONTOLOGY_SHORT)-full.ttl : $(VERSIONDIR)/$(ONTOLOGY_SHORT)-full.owl
	$(call translate_to_ttl,$@,$<)
	$(call replace_owls,$@)

$(VERSIONDIR)/$(ONTOLOGY_SHORT)-closure.owl : $(VERSIONDIR)/$(ONTOLOGY_SHORT)-full.owl
	$(ROBOT) reason --input $< --reasoner hermit --catalog $(VERSIONDIR)/catalog-v001.xml --axiom-generators "SubClass EquivalentClass DataPropertyCharacteristic EquivalentDataProperties SubDataProperty ClassAssertion EquivalentObjectProperty InverseObjectProperties ObjectPropertyCharacteristic SubObjectProperty ObjectPropertyRange ObjectPropertyDomain" --include-indirect true annotate --ontology-iri $(ONTOLOGY_IRI) --output $@
	$(ROBOT) merge --catalog $(VERSIONDIR)/catalog-v001.xml --input $< --input $@ annotate --ontology-iri $(ONTOLOGY_IRI) --output $@