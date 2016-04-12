# Files including this one should predefine: (* means required)
# * USERNAME := gestiweb / $$USERNAME$$
# * IMAGE_NAME := $$last_folder_name$$
# * IMAGE_TAG := latest/upgrade/...
# CONTAINER_BASENAME := $(IMAGE_NAME)
#
# IMAGENAME_LABEL_KEY   := com.gestiweb.docker.image-name
# * IMAGENAME_LABEL_VALUE := $$last_folder_name$$:dev/upgrade/...
#
# CONT_DEVEL_NAME := $(CONTAINER_BASENAME)-dev
# CONT_PROD_NAME := $(CONTAINER_BASENAME)-production
# -----------------------------

ifndef USERNAME
    $(error USERNAME must be defined to use this template.)
endif

ifndef IMAGE_NAME
    $(error IMAGE_NAME must be defined to use this template.)
endif

ifndef IMAGE_TAG
    $(error IMAGE_TAG must be defined to use this template.)
endif

ifndef CONTAINER_BASENAME
CONTAINER_BASENAME := $(IMAGE_NAME)
endif

ifndef IMAGENAME_LABEL_TAG
    $(error IMAGENAME_LABEL_TAG must be defined to use this template.)
endif

ifndef IMAGENAME_LABEL_KEY
IMAGENAME_LABEL_KEY := com.gestiweb.docker.image-name
endif

ifndef IMAGENAME_LABEL_VALUE
IMAGENAME_LABEL_VALUE := $(IMAGE_NAME):$(IMAGENAME_LABEL_TAG)
endif

ifndef CONT_DEVEL_NAME
CONT_DEVEL_NAME := $(CONTAINER_BASENAME)-dev
endif

ifndef CONT_PROD_NAME
CONT_PROD_NAME := $(CONTAINER_BASENAME)-production
endif

ifndef CONT_VOL_NAME
CONT_VOL_NAME := $(CONTAINER_BASENAME)-volume
endif

ifndef VOLUMES
VOLUMES :=
ifdef SHARE_FOLDER
VOLUMES := -v $(CONT_VOL_NAME):$(SHARE_FOLDER)
endif
endif

CONTAINER_STATUS := $(shell docker-status $(CONT_DEVEL_NAME) )
PRODUCTION_STATUS := $(shell docker-status $(CONT_PROD_NAME) )
VOLUME_STATUS := $(shell docker-status $(CONT_VOL_NAME) )

ifndef VOLUMES_FROM
ifneq (,$(findstring exists,$(VOLUME_STATUS)))
VOLUMES_FROM := $(CONT_VOL_NAME)
endif
endif

ts := $(shell /bin/date "+%Y%m%d")
IMAGE := $(USERNAME)/$(IMAGE_NAME)
LATEST_IMAGE := $(USERNAME)/$(IMAGE_NAME):$(IMAGE_TAG)
DATE_IMAGE := $(USERNAME)/$(IMAGE_NAME):$(IMAGE_TAG)-$(ts)

OLDIMAGES := $(shell docker-image-tags $(IMAGE) '$(IMAGE_TAG).*' -q 2>/dev/null)
OLDTAGS := $(shell docker-image-tags $(IMAGE) '$(IMAGE_TAG).*' -v 2>/dev/null)

OLDIMAGE := $(shell docker images -q $(LATEST_IMAGE))

GITROOT := $(shell git rev-parse --show-toplevel)

FOLDER_TAG := $(notdir $(patsubst %/,%,$(dir $(patsubst %/,%,$(CURDIR)))))
FOLDER_IMAGE := $(notdir $(patsubst %/,%,$(CURDIR)))

DOCKERFILE_FROM := $(shell head -n5 Dockerfile | grep "FROM" | cut -f2 -d' ')
DOCKERFILE_LABEL := $(shell head -n5 Dockerfile | grep "LABEL" | grep "$(IMAGENAME_LABEL_KEY)" | cut -f2 -d' ' | cut -f2 -d'=')

# TODO: Yes, i don't know how to do this on Makefile. Using bash instead...
DOCKERFILE_FROM_USERNAME := $(shell echo $(DOCKERFILE_FROM) | cut -f1 -d'/')
DOCKERFILE_FROM_IMAGETAG := $(shell echo $(DOCKERFILE_FROM) | cut -f2 -d'/')
DOCKERFILE_FROM_IMAGE := $(shell echo $(DOCKERFILE_FROM_IMAGETAG) | cut -f1 -d':')
DOCKERFILE_FROM_TAG := $(shell echo $(DOCKERFILE_FROM_IMAGETAG) | cut -f2 -d':')
# Analysis of correctness of parameters:

# Folders matches image:tag ?
ifneq ($(FOLDER_IMAGE), $(IMAGE_NAME))
    $(error IMAGE_NAME is <$(IMAGE_NAME)> and should be <$(FOLDER_IMAGE)>)
endif

ifeq ($(FOLDER_TAG), dev)
    ifneq ($(IMAGE_TAG), latest)
        $(error IMAGE_TAG is <$(IMAGE_TAG)> and should be <latest>)
    endif
    ifneq ($(IMAGENAME_LABEL_TAG), dev)
        $(error IMAGENAME_LABEL_TAG is <$(IMAGENAME_LABEL_TAG)> and should be <dev>)
    endif
else
    ifneq ($(IMAGE_TAG), $(FOLDER_TAG))
        $(error IMAGE_TAG is <$(IMAGE_TAG)> and should be <$(FOLDER_TAG)>)
    endif
    ifneq ($(IMAGENAME_LABEL_TAG), $(FOLDER_TAG))
        $(error IMAGENAME_LABEL_TAG is <$(IMAGENAME_LABEL_TAG)> and should be <$(FOLDER_TAG)>)
    endif
endif

# Labels match Dockerfile ?

ifneq ($(IMAGENAME_LABEL_VALUE), $(DOCKERFILE_LABEL))
    $(error Dockerfile's LABEL value <$(DOCKERFILE_LABEL)> doesn't match with <$(IMAGENAME_LABEL_VALUE)>)
endif

# From matches rules?
ifneq ($(DOCKERFILE_FROM_USERNAME),$(USERNAME))
    $(error Base Image is from a different user <$(DOCKERFILE_FROM_USERNAME)> than the final user <$(USERNAME)>)
endif

ifeq ($(IMAGE_TAG),upgrade) # upgrade images -> rules

ifneq ($(DOCKERFILE_FROM_IMAGE),auto)
    $(error Upgrade images should derive from "auto" images)
endif
ifneq ($(DOCKERFILE_FROM_TAG),$(IMAGE_NAME))
    $(error Upgrade image $(IMAGE_NAME) should derive from "auto:$(IMAGE_NAME)" images)
endif

endif

ifeq ($(IMAGE_TAG),latest) # devel images -> rules

ifneq ($(DOCKERFILE_FROM_IMAGE),$(IMAGE_NAME))
    $(error Devel images should derive from ":upgrade", got diferent image. )
endif
ifneq ($(DOCKERFILE_FROM_TAG),upgrade)
    $(error Devel images should derive from ":upgrade", got diferent tag. )
endif

endif

RUN_OPTS :=
ifdef VOLUMES_FROM
RUN_OPTS := $(RUN_OPTS) --volumes-from=$(VOLUMES_FROM)
endif
ifdef NETWORK_NAME
RUN_OPTS := $(RUN_OPTS) --net=$(NETWORK_NAME)
endif


help:
	@echo "An action is required. List of common actions:"
	@echo ""
	@echo "	make build: -> compile new image $(LATEST_IMAGE) and replace :$(IMAGE_TAG) tag"
	@echo "	make run: -> execute new container $(CONT_DEVEL_NAME) from image $(LATEST_IMAGE)"
	@echo "	... removing the previous devel container if exists."
	@echo "	make push: -> push image to docker hub. Implies build."
	@echo "	make list-containers: -> list of known containers using images from this folder"
	@echo "	make list-images: -> list of known images built from this folder"
	@echo "	make clean: -> stops, removes devel containers and removes known images "
	@echo "	make clean-container: -> stops & removes devel container"
	@echo "	make status: are devel or production container running?"
	@echo "	make production: create production container and run it (or start it if it was stopped)"
	@echo "	make (start|stop|restart)-production: like /etc/init.d/ commands for the production container."
	@echo "	make destroy-production: destroy/clean the production container and its data."
	@echo ""

test:
	@echo "it works!"

brl:
	make build
	make run
	make login

build:
	docker build --pull --tag $(LATEST_IMAGE) --tag $(DATE_IMAGE) $(CURDIR)
	@NEW_IMAGE=$$(docker images -q $(LATEST_IMAGE)); \
	for oldimage in $(OLDIMAGES); do \
	    if [ "$$NEW_IMAGE" != "$$oldimage" ]; then \
		 docker rmi $$oldimage 2>/dev/null echo "Removed old image $$oldimage" || /bin/true; \
	    fi; \
	done; \
	if [ "$$NEW_IMAGE" != "$(OLDIMAGE)" ]; then \
		echo "NEW IMAGE built -> marking every child project as pending_rebuild"; \
		for dockerfile in $$(git grep -l "FROM $(LATEST_IMAGE)" -- $(GITROOT)/"*Dockerfile"); do \
		    touch $$dockerfile.pending_rebuild; \
		    echo "Created file $$dockerfile.pending_rebuild"; \
		done;  \
	fi;
	@test -f $(CURDIR)/Dockerfile.pending_rebuild && unlink $(CURDIR)/Dockerfile.pending_rebuild || /bin/true;

push: build
	docker push $(DATE_IMAGE)
	docker push $(LATEST_IMAGE)

child-builds:
	 git grep -l "FROM $(LATEST_IMAGE)" -- $(GITROOT)/"*Dockerfile"



list-containers:
	docker ps -a --filter "label=$(IMAGENAME_LABEL_KEY)=$(IMAGENAME_LABEL_VALUE)"
list-images:
	# If we use "-a" here, we get also the internal layers for our image.
	docker images --filter "label=$(IMAGENAME_LABEL_KEY)=$(IMAGENAME_LABEL_VALUE)"

clean: clean-container
ifneq (,$(OLDTAGS))
	docker rmi $(OLDTAGS)
endif
	docker rmi $$(docker images --filter "label="$(IMAGENAME_LABEL_KEY)"="$(IMAGENAME_LABEL_VALUE) -q) 2>/dev/null || /bin/true

clean-container:
ifneq (,$(findstring exists,$(CONTAINER_STATUS)))
ifneq (,$(findstring running,$(CONTAINER_STATUS)))
		@echo "Stopping container $(CONT_DEVEL_NAME) . . ."
		docker stop $(CONT_DEVEL_NAME)
endif
	    @echo "Removing container $(CONT_DEVEL_NAME) . . ."
	    docker rm $(CONT_DEVEL_NAME)
endif

inspect:
	docker inspect $(CONT_DEVEL_NAME) > /tmp/.docker.inspect.$(CONT_DEVEL_NAME)
	@cat /tmp/.docker.inspect.$(CONT_DEVEL_NAME) | python ../../utils/filter-json.py StartedAt
	@cat /tmp/.docker.inspect.$(CONT_DEVEL_NAME) | python ../../utils/filter-json.py ExitCode
	@cat /tmp/.docker.inspect.$(CONT_DEVEL_NAME) | python ../../utils/filter-json.py IPAddress
	@unlink /tmp/.docker.inspect.$(CONT_DEVEL_NAME)

run: clean-container
	docker run -itd $(RUN_OPTS) --name $(CONT_DEVEL_NAME) --hostname $(CONT_DEVEL_NAME)  $(LATEST_IMAGE)

login:
ifeq (,$(findstring running,$(CONTAINER_STATUS)))
	@echo "Container $(CONT_DEVEL_NAME) is not running. 'make run' will be executed now . . .  "
	make run
endif
	docker exec -it  $(CONT_DEVEL_NAME) /bin/bash

create-volume:
ifneq (,$(findstring exists,$(VOLUME_STATUS)))
	$(error Volume already exists. Run drop-volume or recreate-volume)
endif
	docker volume create --name $(CONT_VOL_NAME)
	docker create $(VOLUMES) --name $(CONT_VOL_NAME) $(LATEST_IMAGE) /bin/true

recreate-volume:
ifneq (,$(findstring exists,$(VOLUME_STATUS)))
	docker rm $(CONT_VOL_NAME)
endif
	docker volume create --name $(CONT_VOL_NAME)
	docker create $(VOLUMES) --name $(CONT_VOL_NAME) $(LATEST_IMAGE) /bin/true

drop-volume:
ifeq (,$(findstring exists,$(VOLUME_STATUS)))
	$(error Volume does not exist. Run create-volume)
endif
	docker rm $(CONT_VOL_NAME)
	docker volume rm $(CONT_VOL_NAME)



status:
	@echo "Devel Status: $(CONTAINER_STATUS)"
	@echo "Production Status: $(PRODUCTION_STATUS)"

production:
ifneq (,$(findstring exists,$(PRODUCTION_STATUS)))
ifneq (,$(findstring running,$(PRODUCTION_STATUS)))
	@echo "Container $(CONT_PROD_NAME) is already running. Nothing done. "
else
	@echo "Starting stopped container $(CONT_PROD_NAME) . . . "
	docker start $(CONT_PROD_NAME)
endif
else
	@echo "Creating a new container from $(LATEST_IMAGE)"
	docker run -itd --name $(CONT_PROD_NAME) $(LATEST_IMAGE)
endif

start-production:
ifneq (,$(findstring exists,$(PRODUCTION_STATUS)))
ifneq (,$(findstring running,$(PRODUCTION_STATUS)))
	$(error Container $(CONT_PROD_NAME) is already running.)
else
	@echo "Starting stopped container $(CONT_PROD_NAME) . . . "
	docker start $(CONT_PROD_NAME)
endif
else
	@echo "Creating a new container from $(LATEST_IMAGE)"
	docker run -d --name $(CONT_PROD_NAME) $(LATEST_IMAGE)
endif

stop-production:
ifneq (,$(findstring exists,$(PRODUCTION_STATUS)))
ifneq (,$(findstring running,$(PRODUCTION_STATUS)))
	@echo "Stopping container $(CONT_PROD_NAME) . . . "
	docker stop $(CONT_PROD_NAME)
else
	$(error Container $(CONT_PROD_NAME) was not running.)
endif
else
	$(error Container $(CONT_PROD_NAME) does not exist.)
endif


restart-production:
ifneq (,$(findstring exists,$(PRODUCTION_STATUS)))
ifneq (,$(findstring running,$(PRODUCTION_STATUS)))
	@echo "Re-starting running container $(CONT_PROD_NAME) . . . "
	docker restart $(CONT_PROD_NAME)
else
	@echo "Container status was stopped. Starting container $(CONT_PROD_NAME) anyways . . . "
	docker start $(CONT_PROD_NAME)
endif
else
	$(error Container $(CONT_PROD_NAME) does not exist.)
endif

destroy-production:
ifneq (,$(findstring exists,$(PRODUCTION_STATUS)))
ifneq (,$(findstring running,$(PRODUCTION_STATUS)))
	$(error Container $(CONT_PROD_NAME) was running. Cowardly refusing to stop it and destroy your data.)
else
	@echo "Container status was stopped. Destroying container $(CONT_PROD_NAME) and its data . . . "
	docker rm $(CONT_PROD_NAME)
endif
else
	$(error Container $(CONT_PROD_NAME) does not exist.)
endif

ifdef NETWORK_NNAME
network-create:
	docker network create --driver bridge $(NETWORK_NAME)


network-remove:
	docker network rm $(NETWORK_NAME)

network-inspect:
	docker network inspect $(NETWORK_NAME)
endif
