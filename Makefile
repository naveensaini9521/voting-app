NAMESPACE := voting-app
RESULT_TAG := v1.0.0
WORKER_TAG := v1.0.0
TUNNEL_LOG := /tmp/minikube-tunnel.log
SHELL := /bin/bash

.PHONY: demo

demo:
	@echo "Starting Minikube..."
	@if ! minikube status >/dev/null 2>&1; then \
		minikube start --driver=docker --cpus=2 --memory=4096; \
	fi

	@echo "Enabling addons..."
	minikube addons enable ingress
	minikube addons enable metrics-server

	kubectl rollout status deployment/ingress-nginx-controller \
		-n ingress-nginx \
		--timeout=300s

	kubectl wait \
		--namespace ingress-nginx \
		--for=condition=Ready pod \
		-l app.kubernetes.io/component=controller \
		--timeout=300s

	@echo "Setting up Minikube tunnel..."
	@TUNNEL_PID=$$(ps aux | grep "[m]inikube tunnel" | awk '{print $$2}'); \
	if [ ! -z "$$TUNNEL_PID" ]; then \
		echo "Stopping existing Minikube tunnel (PID: $$TUNNEL_PID)..."; \
		sudo kill -9 $$TUNNEL_PID 2>/dev/null || true; \
		sleep 2; \
	fi

	@echo "Starting fresh Minikube tunnel..."
	@echo "Enter your password to allow minikube tunnel to create network routes:"
	@sudo -v

	@( \
		while true; do \
			sudo -n true; \
			sleep 60; \
			kill -0 $$$$ 2>/dev/null || exit; \
		done \
	) & echo $$! > /tmp/minikube-tunnel-keepalive.pid

	@echo "Launching tunnel (log: $(TUNNEL_LOG))..."
	@nohup sudo env \
		"HOME=$$HOME" \
		"KUBECONFIG=$$HOME/.kube/config" \
		"MINIKUBE_HOME=$$HOME/.minikube" \
		"PATH=$$PATH" \
		minikube tunnel > $(TUNNEL_LOG) 2>&1 & disown

	@echo "Waiting for tunnel to start..."
	@for i in $$(seq 1 20); do \
		if grep -qiE "Status:|Tunnel successfully started|NOTE: Please" $(TUNNEL_LOG) 2>/dev/null; then \
			echo "Tunnel is up."; \
			break; \
		fi; \
		if grep -qi "not found" $(TUNNEL_LOG) 2>/dev/null; then \
			echo "❌ Tunnel failed to start:"; \
			cat $(TUNNEL_LOG); \
			exit 1; \
		fi; \
		sleep 1; \
	done
	@sleep 3

	@if ! docker image inspect naveen9521/result-app:$(RESULT_TAG) >/dev/null 2>&1; then \
		docker build -t naveen9521/result-app:$(RESULT_TAG) ./result; \
	fi
	minikube image load naveen9521/result-app:$(RESULT_TAG)

	@if ! docker image inspect naveen9521/worker-app:$(WORKER_TAG) >/dev/null 2>&1; then \
		docker build -t naveen9521/worker-app:$(WORKER_TAG) ./worker; \
	fi
	minikube image load naveen9521/worker-app:$(WORKER_TAG)

	kubectl create namespace $(NAMESPACE) \
		--dry-run=client -o yaml | kubectl apply -f -

	kubectl apply -f k8s-specifications/ -n $(NAMESPACE)

	kubectl rollout restart deployment/result -n $(NAMESPACE)
	kubectl rollout restart deployment/vote -n $(NAMESPACE)
	kubectl rollout restart deployment/worker -n $(NAMESPACE)

	kubectl rollout status statefulset/db -n $(NAMESPACE)
	kubectl rollout status statefulset/redis -n $(NAMESPACE)

	kubectl rollout status deployment/vote -n $(NAMESPACE)
	kubectl rollout status deployment/worker -n $(NAMESPACE)
	kubectl rollout status deployment/result -n $(NAMESPACE)

	@echo "Updating /etc/hosts..."

	@if grep -q "votingapp.local" /etc/hosts; then \
		sudo sed -i.bak '/votingapp.local/d' /etc/hosts; \
	fi

	@echo "127.0.0.1 votingapp.local" | sudo tee -a /etc/hosts >/dev/null

	@echo ""
	@echo "Deployment completed successfully!"
	@echo "Vote App   : http://votingapp.local/"
	@echo "Result App : http://votingapp.local/result"
	@echo ""

	kubectl get pods -n $(NAMESPACE)
	kubectl get svc -n $(NAMESPACE)
	kubectl get ingress -n $(NAMESPACE)