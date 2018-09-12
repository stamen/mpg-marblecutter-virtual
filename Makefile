PATH := node_modules/.bin:$(PATH)

deploy-up: deps/deps.tgz
	up $(ENV)

deps/deps.tgz: deps/Dockerfile deps/required.txt
	docker run --rm --entrypoint tar $$(docker build --build-arg http_proxy=$(http_proxy) -t marblecutter-virtual-deps -q -f $< .) zc -C /var/task . > $@

clean:
	rm -f deps/deps.tgz

server:
	docker build --build-arg http_proxy=$(http_proxy) -t quay.io/mojodna/marblecutter-virtual .
