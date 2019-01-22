PATH := node_modules/.bin:$(PATH)
STACK_NAME ?= "marblecutter-virtual"

deploy-up: deps/deps.tgz
	up $(ENV)

deps/deps.tgz: deps/Dockerfile deps/required.txt
	docker run --rm --entrypoint tar $$(docker build --build-arg http_proxy=$(http_proxy) -t marblecutter-virtual-deps -q -f $< .) zc -C /var/task . > $@

deploy: packaged.yaml
	sam deploy \
		--template-file $< \
		--stack-name $(STACK_NAME) \
		--capabilities CAPABILITY_IAM \
		--parameter-overrides DomainName=$(DOMAIN_NAME)

packaged.yaml: .aws-sam/build/template.yaml
	sam package --s3-bucket $(S3_BUCKET) --output-template-file $@

.aws-sam/build/template.yaml: template.yaml requirements.txt virtual/*.py
	sam build --use-container

clean:
	rm -rf .aws-sam/ packaged.yaml

server:
	docker build --build-arg http_proxy=$(http_proxy) -t quay.io/mojodna/marblecutter-virtual .
