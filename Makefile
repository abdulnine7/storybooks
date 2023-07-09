#The project id in google cloud for the current porject
PROJECT_ID=devops-storybooks-391700

#The environment in use (staging or prod)
# Commented this out as we are using the a function to check env everytime we run a function of make file.
# ENVIRONMENT=staging 

#The zone for the current project
ZONE=us-central1-c

run-local:
	docker-compose up

# Before you run any of the commands below, you need to set the GOOGLE APPLICATION CREDENTIALS
# GOOGLE_APPLICATION_CREDENTIALS is used for terraform to authenticate with google cloud
# By running the command below, it will set the GOOGLE_APPLICATION_CREDENTIALS environment variable
# export GOOGLE_APPLICATION_CREDENTIALS="$PWD/terraform/terraform-sa-key.json"
# echo $GOOGLE_APPLICATION_CREDENTIALS

# We use bucket here to store the terraform state
create-tf-backend-bucket:
	gsutil mb -p $(PROJECT_ID) gs://$(PROJECT_ID)-terraform


check-env:
ifndef ENVIRONMENT
	$(error ENVIRONMENT is undefined, Please set ENVIRONMENT to staging or prod)
endif

# Function to get Secrets from Google Secret Manager
define get-secret
$(shell gcloud secrets versions access latest --secret=$(1) --project=$(PROJECT_ID))
endef

# Create a new workspace for terraform
terraform-create-workspace:
	cd terraform && \
		terraform workspace new $(ENVIRONMENT)

# Select the workspace for terraform and init terraform
terraform-init: check-env
	cd terraform && \
		terraform workspace select $(ENVIRONMENT) && \
		terraform init

# Run terraform plan or apply
ACTION?=plan #default action is plan
terraform-action: check-env
	cd terraform && \
		terraform workspace select $(ENVIRONMENT) && \
		terraform $(ACTION) \
			-var-file="./environments/common.tfvars" \
			-var-file="./environments/$(ENVIRONMENT)/config.tfvars" \
			-var="mongodbatlas_private_key=$(call get-secret,atlas_private_key)" \
			-var="atlas_user_password=$(call get-secret,atlas_user_password)" \
			-var="cloudflare_api_token=$(call get-secret,cloudflare_api_token)"

# Debugger for terraform
print: check-env
	@echo $(call get-secret,atlas_private_key)
	@echo $(call get-secret,atlas_user_password)
	@echo $(call get-secret,cloudflare_api_token)
	@echo $(call get-secret,google_client_id_for_oauth)
	@echo $(call get-secret,google_client_secret_for_oauth)


# SSH_STRING is used to ssh into the VM instance
SSH_STRING=abdul@storybooks-vm-$(ENVIRONMENT)

# Tags and version fof the docker inage that is th be build and pushed to Google Container Registry
GITHUB_SHA?=latest
LOCAL_TAG=storybooks-app:$(GITHUB_SHA)
REMOTE_TAG=gcr.io/$(PROJECT_ID)/$(LOCAL_TAG)
CONTAINER_NAME=storybooks-api


# Interactive SSH into the VM instance
ssh: check-env
	gcloud compute ssh $(SSH_STRING) --project=$(PROJECT_ID) --zone=$(ZONE)

# Run specific command on the VM instance
ssh-cmd: check-env
	@gcloud compute ssh $(SSH_STRING) --project=$(PROJECT_ID) --zone=$(ZONE) --command="$(CMD)"


build: check-env
	docker build --platform=linux/amd64 -t $(LOCAL_TAG) .

push: check-env
	docker tag $(LOCAL_TAG) $(REMOTE_TAG)
	docker push $(REMOTE_TAG)

deploy: check-env
	$(MAKE) ssh-cmd CMD='docker-credential-gcr configure-docker'
	@echo "Pulling the latest image from GCR"
	$(MAKE) ssh-cmd CMD='docker pull $(REMOTE_TAG)'
	@echo "Stopping and removing the container if it exists"
	-$(MAKE) ssh-cmd CMD='docker container stop $(CONTAINER_NAME)'
	-$(MAKE) ssh-cmd CMD='docker container rm $(CONTAINER_NAME)'
	@echo "Running the container"
	@$(MAKE) ssh-cmd CMD='\
		docker run -d --name=$(CONTAINER_NAME) \
		--restart=unless-stopped \
		-p 80:3000 \
		-e PORT=3000 \
		-e \"MONGO_URI=mongodb+srv://storybooks-user-$(ENVIRONMENT):$(call get-secret,atlas_user_password)@storybooks-$(ENVIRONMENT).gkp5z.mongodb.net/storybooks-$(ENVIRONMENT)?retryWrites=true&w=majority\" \
		-e GOOGLE_CLIENT_ID=$(call get-secret,google_client_id_for_oauth) \
		-e GOOGLE_CLIENT_SECRET=$(call get-secret,google_client_secret_for_oauth) \
		$(REMOTE_TAG) \
		'