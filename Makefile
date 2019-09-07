CHART_REPO := http://jenkins-x-chartmuseum:8080
NAME := zeebe-k8s-full-helm
OS := $(shell uname)

CHARTMUSEUM_CREDS_USR := $(shell cat /builder/home/basic-auth-user.json)
CHARTMUSEUM_CREDS_PSW := $(shell cat /builder/home/basic-auth-pass.json)

init:
	helm init --client-only

setup: init
	helm repo add jenkins-x http://chartmuseum.jenkins-x.io
	helm repo add elastic http://helm.elastic.co
	helm repo add releases ${CHART_REPO}

build: clean setup
	helm dependency build zeebe-k8s-full-helm
	helm lint zeebe-k8s-full-helm
	helm template zeebe-k8s-full-helm

install: clean build
	helm upgrade ${NAME} zeebe-k8s-full-helm --install

upgrade: clean build
	helm upgrade ${NAME} zeebe-k8s-full-helm --install

delete:
	helm delete --purge ${NAME} zeebe-k8s-full-helm

clean:
	rm -rf zeebe-k8s-full-helm/charts
	rm -rf zeebe-k8s-full-helm/${NAME}*.tgz
	rm -rf zeebe-k8s-full-helm/requirements.lock

release: clean build
ifeq ($(OS),Darwin)
	sed -i "" -e "s/version:.*/version: $(VERSION)/" zeebe-k8s-full-helm/Chart.yaml

else ifeq ($(OS),Linux)
	sed -i -e "s/version:.*/version: $(VERSION)/" zeebe-k8s-full-helm/Chart.yaml
else
	exit -1
endif
	helm package zeebe-k8s-full-helm
	curl --fail -u $(CHARTMUSEUM_CREDS_USR):$(CHARTMUSEUM_CREDS_PSW) --data-binary "@$(NAME)-$(VERSION).tgz" $(CHART_REPO)/api/charts
	rm -rf ${NAME}*.tgz
	jx step changelog  --verbose --version $(VERSION) --rev $(PULL_BASE_SHA)
